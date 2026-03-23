package com.lxi.hazuki.comics

import android.media.MediaScannerConnection
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

private const val PRIVACY_CHANNEL = "hazuki.comics/privacy"
private const val DISPLAY_MODE_CHANNEL = "hazuki.comics/display_mode"
private const val MEDIA_CHANNEL = "hazuki.comics/media"
private const val READER_DISPLAY_CHANNEL = "hazuki.comics/reader_display"

class MainActivityChannels(
    private val activity: MainActivity,
    private val privacyManager: PrivacyManager,
    private val displayModeManager: DisplayModeManager,
) {
    fun register(flutterEngine: FlutterEngine) {
        registerPrivacyChannel(flutterEngine)
        registerDisplayModeChannel(flutterEngine)
        registerMediaChannel(flutterEngine)
        registerReaderDisplayChannel(flutterEngine)
    }

    private fun registerPrivacyChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPrivacySettings" -> result.success(privacyManager.privacySettings())
                    "setBlurBackground" -> {
                        privacyManager.setBlurBackground(call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }
                    "setBiometricAuth" -> {
                        privacyManager.setBiometricAuth(call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }
                    "setAuthOnResume" -> {
                        privacyManager.setAuthOnResume(call.argument<Boolean>("enabled") ?: false)
                        result.success(null)
                    }
                    "authenticate" -> privacyManager.authenticate(result, requireAuth = false)
                    "requireAuthCheck" -> result.success(privacyManager.requireAuthCheck())
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerDisplayModeChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, DISPLAY_MODE_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getDisplayModes" -> result.success(displayModeManager.getDisplayModes())
                    "applyDisplayModeRaw" -> {
                        result.success(
                            displayModeManager.applyDisplayModeRaw(call.argument<String>("raw")),
                        )
                    }
                    "applyAutoDisplayMode" -> {
                        displayModeManager.applyAutoDisplayMode()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerMediaChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scanFile" -> {
                        val path = call.argument<String>("path")
                        if (path.isNullOrBlank()) {
                            result.success(false)
                            return@setMethodCallHandler
                        }
                        MediaScannerConnection.scanFile(activity, arrayOf(path), null, null)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun registerReaderDisplayChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READER_DISPLAY_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setKeepScreenOn" -> {
                        displayModeManager.setKeepScreenOnFlag(
                            call.argument<Boolean>("enabled") ?: false,
                        )
                        result.success(null)
                    }
                    "setReaderBrightness" -> {
                        result.success(
                            displayModeManager.setReaderBrightness(call.argument<Double>("value")),
                        )
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
