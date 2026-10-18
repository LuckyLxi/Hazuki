package com.lxi.hazuki

import java.net.URI
import java.net.URLDecoder
import java.net.URLEncoder
import org.junit.Assert.*
import org.junit.Test

class PluginAuthorizationQqHandoffTest {
    private val session = "a".repeat(32)
    private val page = "https://xui.ptlogin2.qq.com/cgi-bin/xlogin"
    private val jump = "https://ssl.ptlogin2.qq.com/jump?u1=https%3A%2F%2Fconnect.qq.com%2Fauthorize%3Fstate%3Dopaque"
    private val qrCode = "http://txz.qq.com/p?k=synthetic&f=1"
    private fun webLink(target: String = jump) = "wtloginmqq://ptlogin/qlogin?p=" + encode(target)
    private fun qrLink(target: String = qrCode) = "wtloginmqq://ptlogin/qlogin?qrcode=" + encode(target)
    private fun encode(value: String) = URLEncoder.encode(value, "UTF-8")
    private fun fields(url: String) = URI(url).rawQuery.split('&').associate {
        URLDecoder.decode(it.substringBefore('='), "UTF-8") to URLDecoder.decode(it.substringAfter('='), "UTF-8")
    }

    @Test fun recognizesOnlyQqWebLoginsOnTrustedPages() {
        assertTrue(PluginAuthorizationQqHandoff.isWebLogin(page, webLink()))
        for (untrusted in listOf(null, "https://evil.example", "https://xui.ptlogin2.qq.com.evil.example/",
            "http://xui.ptlogin2.qq.com/", "https://user@xui.ptlogin2.qq.com/", "https://xui.ptlogin2.qq.com:444/")) {
            assertFalse(PluginAuthorizationQqHandoff.isWebLogin(untrusted, webLink()))
            assertNull(PluginAuthorizationQqHandoff.prepareQr(untrusted, qrLink(), "com.lxi.hazuki", session))
        }
        for (url in listOf(webLink("https://evil.example/jump?u1=x"), webLink("https://ssl.ptlogin2.qq.com/jump"),
            webLink() + "&p=duplicate", "intent://ptlogin/qlogin", webLink().replace("/qlogin?", "/other?"))) {
            assertFalse(PluginAuthorizationQqHandoff.isWebLogin(page, url))
        }
    }

    @Test fun replacesBrowserCallbacksWithTheCurrentBuildWithoutChangingTheQrTicket() {
        for ((packageName, scheme) in listOf("com.lxi.hazuki" to "hazuki-auth",
            "com.lxi.hazuki.debug" to "hazuki-auth-debug", "com.lxi.hazuki.profile" to "hazuki-auth-profile")) {
            val input = qrLink() + "&schemacallback=weixin%3A%2F%2F&schemacallback=googlechrome%3A%2F%2F"
            val launch = PluginAuthorizationQqHandoff.prepareQr(page, input, packageName, session)!!
            assertEquals("wtloginmqq", URI(launch).scheme)
            assertEquals(qrCode, fields(launch)["qrcode"])
            assertEquals("$scheme://authorize/qq/$session", fields(launch)["schemacallback"])
            assertEquals(2, URI(launch).rawQuery.split('&').size)
            assertFalse(fields(launch).containsKey("p"))
        }
    }

    @Test fun rejectsArbitraryQrIntentsAndAmbiguousTickets() {
        for (url in listOf(qrLink("https://evil.example/p?k=x"), qrLink("file://txz.qq.com/p?k=x"),
            qrLink("http://txz.qq.com:81/p?k=x"),
            qrLink("https://txz.qq.com/p/extra?k=x"), qrLink("https://user@txz.qq.com/p?k=x"),
            qrLink("https://txz.qq.com/p"), qrLink("https://txz.qq.com/p?k=x&k=other"),
            qrLink() + "&qrcode=duplicate", qrLink() + "&p=" + encode(jump),
            "wtloginmqq://ptlogin/qlogin?qrcode=%ZZ", qrLink().replace("ptlogin/", "other/"))) {
            assertNull(PluginAuthorizationQqHandoff.prepareQr(page, url, "com.lxi.hazuki", session))
        }
        assertNull(PluginAuthorizationQqHandoff.prepareQr(page, qrLink(), "com.lxi.hazuki", "invalid"))
    }
}
