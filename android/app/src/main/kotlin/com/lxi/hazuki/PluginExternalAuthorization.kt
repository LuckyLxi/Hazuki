package com.lxi.hazuki

import android.app.Activity
import android.content.Intent
import android.net.Uri
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/** All URLs are transient. Cold callbacks without a live session are discarded. */
class PluginExternalAuthorization(private val activity: Activity, engine: FlutterEngine) {
    private val channel = MethodChannel(engine.dartExecutor.binaryMessenger, "hazuki/external_authorization")
    private val sessions = mutableSetOf<String>()
    private val scheme = when {
        activity.packageName.endsWith(".debug") -> "hazuki-auth-debug"
        activity.packageName.endsWith(".profile") -> "hazuki-auth-profile"
        else -> "hazuki-auth"
    }

    init {
        channel.setMethodCallHandler { call, result ->
            try {
                val args = call.arguments as Map<*, *>
                val id = args["id"] as String
                check(id.matches(Regex("[a-f0-9]{32}")))
                when (call.method) {
                    "prepare" -> { sessions.add(id); result.success("$scheme://authorize/$id") }
                    "close" -> { sessions.remove(id); result.success(null) }
                    "launch" -> {
                        check(sessions.contains(id))
                        val url = args["url"] as String
                        val uri = Uri.parse(url)
                        val allowed = args["allowedSchemes"] as List<*>
                        check(url.length <= 32768 && !url.contains(Regex("[\\s\\\\]")) && allowed.contains(uri.scheme))
                        check(uri.scheme !in setOf("file", "javascript", "data", "vbscript", "shell", "powershell", "cmd", "intent", "about", "blob", "ms-msdt", "search-ms", "ms-settings"))
                        val intent = Intent(Intent.ACTION_VIEW, uri).addCategory(Intent.CATEGORY_BROWSABLE)
                        (args["androidPackage"] as? String)?.let { intent.setPackage(it) }
                        activity.startActivity(intent)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            } catch (_: Exception) { result.error("login_external_app_unavailable", null, null) }
        }
    }

    fun consume(intent: Intent?): Boolean {
        val uri = intent?.data ?: return false
        if (uri.scheme !in setOf("hazuki-auth", "hazuki-auth-debug", "hazuki-auth-profile")) return false
        // Remove before dispatching; neither getInitialIntent nor search sees it.
        intent.data = null
        val id = uri.encodedPath?.removePrefix("/") ?: return true
        if (uri.scheme != scheme || uri.encodedAuthority != "authorize" || !id.matches(Regex("[a-f0-9]{32}")) || !sessions.remove(id)) return true
        channel.invokeMethod("callback", uri.toString())
        return true
    }
}
