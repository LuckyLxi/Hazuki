package com.lxi.hazuki

import android.annotation.SuppressLint
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.net.http.SslError
import android.os.Message
import android.view.View
import android.webkit.*
import android.widget.FrameLayout
import org.json.JSONTokener
import androidx.webkit.ProfileStore
import androidx.webkit.CookieManagerCompat
import androidx.webkit.WebViewCompat
import androidx.webkit.WebViewFeature
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

/** Isolated profiles; QQ handoffs stay bound to their live browser session. */
class PluginAuthorizationBrowser(private val activity: Activity, private val engine: FlutterEngine) {
    private val sessions = mutableMapOf<String, BrowserView>()
    private val prefix = "hazuki_auth_"

    fun register() {
        engine.platformViewsController.registry.registerViewFactory(
            "hazuki/authorization_browser", object : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
                override fun create(context: Context, viewId: Int, args: Any?): PlatformView {
                    val options = args as Map<*, *>
                    val id = options["id"] as String
                    check(id.matches(Regex("[a-f0-9]{32}")))
                    check(WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE))
                    return BrowserView(context, id, options).also { sessions[id] = it }
                }
            }
        )
        MethodChannel(engine.dartExecutor.binaryMessenger, "hazuki/browser_authorization")
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "prepare" -> {
                            val needsCookies = (call.arguments as? Map<*, *>)?.get("cookies") == true
                            val supported = WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE) &&
                                (!needsCookies || WebViewFeature.isFeatureSupported(WebViewFeature.GET_COOKIE_INFO))
                            if (supported) cleanUnusedProfiles()
                            result.success(supported)
                        }
                        "close" -> {
                            sessions.remove(call.arguments as String)?.close()
                            result.success(null)
                        }
                        "cookies" -> {
                            check(WebViewFeature.isFeatureSupported(WebViewFeature.GET_COOKIE_INFO))
                            val args = call.arguments as Map<*, *>
                            val browser = sessions[args["id"] as String] ?: error("session")
                            result.success(browser.cookies(args["scopes"] as List<*>))
                        }
                        else -> result.notImplemented()
                    }
                } catch (_: Exception) {
                    result.error("login_browser_unavailable", null, null)
                }
            }
        // Never load a profile while deciding which abandoned profiles to delete.
        try {
            if (WebViewFeature.isFeatureSupported(WebViewFeature.MULTI_PROFILE)) cleanUnusedProfiles()
        } catch (_: Exception) { /* Retried on the next foreground attempt. */ }
    }

    private fun cleanUnusedProfiles() {
        val store = ProfileStore.getInstance()
        for (name in store.allProfileNames) {
            if (name.startsWith(prefix) && !sessions.containsKey(name.removePrefix(prefix))) {
                try { store.deleteProfile(name) } catch (_: IllegalStateException) {
                    // Loaded profiles are retried after process restart; never reused.
                }
            }
        }
    }

    private inner class BrowserView(context: Context, val id: String, options: Map<*, *>) : PlatformView {
        private val container = FrameLayout(context)
        private val windows = mutableListOf<WebView>()
        private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hazuki/browser_authorization/$id")
        private val callbacks = options["callbacks"] as List<*>
        private var active = true
        private var qqRequest = 0
        private var qqLaunchedRequest = -1

        private fun dispatchQq(url: String, request: Int) {
            if (!active || request != qqRequest || qqLaunchedRequest == request) return
            qqLaunchedRequest = request
            try {
                activity.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))
                    .addCategory(Intent.CATEGORY_BROWSABLE)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK).setPackage("com.tencent.mobileqq"))
            } catch (_: Exception) {
                emit("externalFailure")
            }
        }

        private fun awaitQqTicket(view: WebView, request: Int, index: Int, attempt: Int = 0) {
            if (!active || request != qqRequest || qqLaunchedRequest == request || !windows.contains(view)) return
            view.evaluateJavascript("window.pt?.qrcode?.history?.[$index] ?? null") { result ->
                if (!active || request != qqRequest || qqLaunchedRequest == request) return@evaluateJavascript
                val ticket = try { JSONTokener(result).nextValue() as? String } catch (_: Exception) { null }
                val launch = ticket?.let {
                    PluginAuthorizationQqHandoff.prepareQr(view.url,
                        "wtloginmqq://ptlogin/qlogin?qrcode=${Uri.encode(it)}", activity.packageName, id)
                }
                if (launch != null) {
                    dispatchQq(launch, request)
                } else if (attempt < 30) {
                    view.postDelayed({ awaitQqTicket(view, request, index, attempt + 1) }, 500)
                } else {
                    emit("failure")
                }
            }
        }

        private fun launchQq(view: WebView, url: String): Boolean {
            if (!active) return false
            if (PluginAuthorizationQqHandoff.isWebLogin(view.url, url)) {
                val request = ++qqRequest
                // Use the provider's QR confirmation mode. Its existing polling stays in
                // this isolated profile, so QQ never hands an HTTPS result to Chrome.
                view.evaluateJavascript("""
                    (function() {
                        if (typeof window.pt?.qrcode?.get !== 'function') return null;
                        const index = window.pt.qrcode.history.length;
                        window.pt.qrcode.get(1);
                        return index;
                    })()
                """.trimIndent()) { result ->
                    if (!active || request != qqRequest) return@evaluateJavascript
                    val index = result.toIntOrNull()
                    if (index == null || index < 0) emit("externalFailure")
                    else awaitQqTicket(view, request, index)
                }
                return true
            }
            val launchUrl = PluginAuthorizationQqHandoff.prepareQr(view.url, url, activity.packageName, id)
                ?: return false
            dispatchQq(launchUrl, qqRequest)
            return true
        }

        fun cookies(scopes: List<*>): List<Map<String, String>> {
            val manager = WebViewCompat.getProfile(windows.first()).cookieManager
            return scopes.flatMap { raw ->
                val scope = raw as Map<*, *>
                val url = scope["url"] as String
                check(Uri.parse(url).scheme == "https")
                val names = scope["names"] as List<*>
                CookieManagerCompat.getCookieInfo(manager, url).filter {
                    names.contains(it.substringBefore('=').trim())
                }.map { mapOf("url" to url, "cookie" to it) }
            }
        }

        init {
            val root = createWindow(context)
            root.loadUrl(options["url"] as String)
        }

        private fun emit(type: String, extra: Map<String, Any?> = emptyMap()) {
            if (active) channel.invokeMethod("event", mapOf("type" to type) + extra)
        }

        private fun matches(uri: Uri): Boolean {
            val port = if (uri.port == -1) 443 else uri.port
            return callbacks.any { raw ->
                val rule = raw as Map<*, *>
                val origin = Uri.parse(rule["origin"] as String)
                val originPort = if (origin.port == -1) 443 else origin.port
                uri.host.equals(origin.host, ignoreCase = true) && port == originPort &&
                    uri.encodedPath == rule["path"] &&
                    (rule["requiredQueryKeys"] as List<*>).all { key ->
                        uri.getQueryParameters(key as String).any { it.isNotEmpty() }
                    }
            }
        }

        private fun allow(url: String, mainFrame: Boolean): Boolean {
            if (!active) return false
            val uri = Uri.parse(url)
            if (uri.scheme != "https" || uri.host.isNullOrEmpty() || uri.userInfo != null) return false
            if (mainFrame) {
                if (matches(uri)) {
                    emit("callback", mapOf("url" to url))
                    windows.forEach { it.stopLoading() }
                    return false
                }
                emit("navigation", mapOf("url" to url))
            }
            return true
        }

        @SuppressLint("SetJavaScriptEnabled")
        private fun createWindow(context: Context): WebView {
            val webView = WebView(context)
            // Must precede settings, clients, JS evaluation and first navigation.
            WebViewCompat.setProfile(webView, prefix + id)
            webView.settings.apply {
                javaScriptEnabled = true
                domStorageEnabled = true
                allowFileAccess = false
                allowContentAccess = false
                mixedContentMode = WebSettings.MIXED_CONTENT_NEVER_ALLOW
                setSupportMultipleWindows(true)
                javaScriptCanOpenWindowsAutomatically = false
                mediaPlaybackRequiresUserGesture = true
                setGeolocationEnabled(false)
            }
            webView.webViewClient = object : WebViewClient() {
                override fun shouldOverrideUrlLoading(view: WebView, request: WebResourceRequest): Boolean =
                    launchQq(view, request.url.toString()) || !allow(request.url.toString(), request.isForMainFrame)

                override fun onPageStarted(view: WebView, url: String, favicon: Bitmap?) {
                    if (url != "about:blank" && !allow(url, true)) view.stopLoading()
                    emit("loading", mapOf("loading" to true))
                }

                override fun onPageFinished(view: WebView, url: String) { emit("loading", mapOf("loading" to false)) }

                override fun onReceivedSslError(view: WebView, handler: SslErrorHandler, error: SslError) {
                    handler.cancel()
                    emit("failure")
                }

                override fun onReceivedError(view: WebView, request: WebResourceRequest, error: WebResourceError) {
                    if (request.isForMainFrame) emit("failure")
                }
            }
            webView.webChromeClient = object : WebChromeClient() {
                override fun onCreateWindow(view: WebView, isDialog: Boolean, isUserGesture: Boolean, resultMsg: Message): Boolean {
                    if (!active || !isUserGesture || windows.size >= 8) return false
                    val child = createWindow(context)
                    (resultMsg.obj as WebView.WebViewTransport).webView = child
                    resultMsg.sendToTarget()
                    return true
                }

                override fun onCloseWindow(window: WebView) {
                    if (window == windows.firstOrNull()) { emit("cancel"); return }
                    windows.remove(window)
                    container.removeView(window)
                    window.destroy()
                }

                override fun onPermissionRequest(request: PermissionRequest) { request.deny() }
                override fun onGeolocationPermissionsShowPrompt(origin: String?, callback: GeolocationPermissions.Callback?) {
                    callback?.invoke(origin, false, false)
                }
                override fun onConsoleMessage(message: ConsoleMessage): Boolean = true
            }
            windows.add(webView)
            container.addView(webView, FrameLayout.LayoutParams(-1, -1))
            return webView
        }

        override fun getView(): View = container

        fun close() {
            active = false
            for (window in windows.toList().asReversed()) {
                window.stopLoading()
                container.removeView(window)
                window.destroy()
            }
            windows.clear()
            try { ProfileStore.getInstance().deleteProfile(prefix + id) } catch (_: IllegalStateException) {
                // The loaded profile cannot be reused and is removed at next startup.
            }
        }

        override fun dispose() {
            sessions.remove(id)
            close()
        }
    }
}
