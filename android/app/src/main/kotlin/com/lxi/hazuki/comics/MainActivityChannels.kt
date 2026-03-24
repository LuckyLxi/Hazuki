package com.lxi.hazuki.comics

import android.media.MediaScannerConnection
import android.net.Uri
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
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
    private var pendingSaveTextResult: MethodChannel.Result? = null
    private var pendingSaveTextContent: String? = null

    private val createJsonDocumentLauncher =
        activity.registerForActivityResult(
            ActivityResultContracts.CreateDocument("application/json"),
        ) { uri ->
            handleCreateJsonDocumentResult(uri)
        }
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
                    "saveTextFile" -> {
                        if (pendingSaveTextResult != null) {
                            result.error(
                                "save_in_progress",
                                "Another saveTextFile request is already in progress",
                                null,
                            )
                            return@setMethodCallHandler
                        }

                        val suggestedFileName =
                            call.argument<String>("suggestedFileName")
                                ?.takeIf { it.isNotBlank() }
                                ?: "hazuki_application_logs.json"
                        val content = call.argument<String>("content")
                        if (content == null) {
                            result.error("missing_content", "Missing text content", null)
                            return@setMethodCallHandler
                        }

                        pendingSaveTextResult = result
                        pendingSaveTextContent = content
                        try {
                            createJsonDocumentLauncher.launch(suggestedFileName)
                        } catch (e: Exception) {
                            pendingSaveTextResult = null
                            pendingSaveTextContent = null
                            result.error(
                                "save_launch_failed",
                                "Failed to launch document picker: ${e.message}",
                                null,
                            )
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleCreateJsonDocumentResult(uri: Uri?) {
        val result = pendingSaveTextResult ?: return
        val content = pendingSaveTextContent
        pendingSaveTextResult = null
        pendingSaveTextContent = null

        if (uri == null) {
            result.success(null)
            return
        }

        if (content == null) {
            result.error("missing_content", "Missing pending text content", null)
            return
        }

        try {
            activity.contentResolver.openOutputStream(uri)?.use { output ->
                output.write(content.toByteArray(Charsets.UTF_8))
                output.flush()
            } ?: throw IllegalStateException("Unable to open output stream")
            result.success(uri.toString())
        } catch (e: Exception) {
            Log.e("MainActivityChannels", "Failed to save text file", e)
            result.error(
                "save_write_failed",
                "Failed to save text file: ${e.message}",
                null,
            )
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
