package com.lxi.hazuki

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder

/** Keep QQ's authorization polling in the owned WebView rather than an external browser. */
internal object PluginAuthorizationQqHandoff {
    private val loginHosts = setOf("xui.ptlogin2.qq.com", "ui.ptlogin2.qq.com", "graph.qq.com")

    fun isWebLogin(pageUrl: String?, url: String): Boolean = try {
        val link = loginLink(pageUrl, url)
        val jump = URI(query(link)["p"]?.singleOrNull() ?: "")
        https(jump) && jump.host == "ssl.ptlogin2.qq.com" &&
            jump.rawPath == "/jump" && jump.rawFragment == null &&
            !query(jump)["u1"]?.singleOrNull().isNullOrEmpty()
    } catch (_: Exception) { false }

    fun prepareQr(pageUrl: String?, url: String, packageName: String, sessionId: String): String? = try {
        val link = loginLink(pageUrl, url)
        val fields = query(link)
        val qrCode = fields["qrcode"]?.singleOrNull() ?: ""
        val qr = URI(qrCode)
        // This HTTP-shaped QR ticket is consumed by QQ, never navigated or fetched.
        val validQrScheme = https(qr) || (qr.scheme == "http" &&
            qr.rawUserInfo == null && qr.port in setOf(-1, 80))
        if (!validQrScheme || qr.host != "txz.qq.com" || qr.rawPath != "/p" ||
            qr.rawFragment != null || query(qr)["k"]?.singleOrNull().isNullOrEmpty() ||
            fields.containsKey("p") || !sessionId.matches(Regex("[a-f0-9]{32}"))) {
            null
        } else {
            val scheme = when {
                packageName.endsWith(".debug") -> "hazuki-auth-debug"
                packageName.endsWith(".profile") -> "hazuki-auth-profile"
                else -> "hazuki-auth"
            }
            // The page may supply both WeChat and Chrome callbacks. Replace both.
            val callback = "$scheme://authorize/qq/$sessionId"
            "wtloginmqq://ptlogin/qlogin?qrcode=${encode(qrCode)}&schemacallback=${encode(callback)}"
        }
    } catch (_: Exception) { null }

    private fun loginLink(pageUrl: String?, url: String): URI {
        val page = URI(pageUrl ?: "")
        val link = URI(url)
        require(https(page) && page.host in loginHosts && url.length <= 32768 &&
            link.scheme == "wtloginmqq" && link.rawAuthority == "ptlogin" &&
            link.rawPath == "/qlogin" && link.rawFragment == null)
        return link
    }

    private fun https(uri: URI): Boolean = uri.scheme == "https" &&
        !uri.host.isNullOrEmpty() && uri.rawUserInfo == null && uri.port in setOf(-1, 443)

    private fun query(uri: URI): Map<String, List<String>> = uri.rawQuery.orEmpty()
        .split('&').filter { it.isNotEmpty() }.map {
            decode(it.substringBefore('=')) to decode(it.substringAfter('=', ""))
        }.groupBy({ it.first }, { it.second })

    private fun decode(value: String): String = URLDecoder.decode(value, "UTF-8")
    private fun encode(value: String): String = URLEncoder.encode(value, "UTF-8")
}
