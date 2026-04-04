package com.lxi.hazuki.comics

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.media.MediaScannerConnection
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.Settings
import android.util.Log
import android.view.KeyEvent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
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
    private var pendingStorageAccessResult: MethodChannel.Result? = null
    private var readerDisplayChannel: MethodChannel? = null
    private var volumeButtonPagingSessionId: String? = null

    private val createJsonDocumentLauncher =
            activity.registerForActivityResult(
                    ActivityResultContracts.CreateDocument("application/json"),
            ) { uri -> handleCreateJsonDocumentResult(uri) }
    private val manageStorageAccessLauncher =
            activity.registerForActivityResult(
                    ActivityResultContracts.StartActivityForResult(),
            ) { completePendingStorageAccessResult(hasStorageAccess()) }
    private val requestLegacyStoragePermissionsLauncher =
            activity.registerForActivityResult(
                    ActivityResultContracts.RequestMultiplePermissions(),
            ) { completePendingStorageAccessResult(hasStorageAccess()) }
    fun register(flutterEngine: FlutterEngine) {
        registerPrivacyChannel(flutterEngine)
        registerDisplayModeChannel(flutterEngine)
        registerMediaChannel(flutterEngine)
        registerReaderDisplayChannel(flutterEngine)
    }

    fun handleReaderVolumeButtonKeyEvent(event: KeyEvent): Boolean {
        val channel = readerDisplayChannel ?: return false
        val sessionId = volumeButtonPagingSessionId ?: return false
        val keyCode = event.keyCode
        if (keyCode != KeyEvent.KEYCODE_VOLUME_UP && keyCode != KeyEvent.KEYCODE_VOLUME_DOWN) {
            return false
        }
        when (event.action) {
            KeyEvent.ACTION_DOWN -> {
                channel.invokeMethod(
                        "onVolumeButtonPressed",
                        mapOf(
                                "direction" to
                                        if (keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down",
                                "sessionId" to sessionId,
                        ),
                )
                return true
            }

            KeyEvent.ACTION_UP -> return true
            else -> return true
        }
    }

    private fun registerPrivacyChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PRIVACY_CHANNEL)
                .setMethodCallHandler { call, result ->
                    when (call.method) {
                        "getPrivacySettings" -> result.success(privacyManager.privacySettings())
                        "setBlurBackground" -> {
                            privacyManager.setBlurBackground(
                                    call.argument<Boolean>("enabled") ?: false
                            )
                            result.success(null)
                        }
                        "setBiometricAuth" -> {
                            privacyManager.setBiometricAuth(
                                    call.argument<Boolean>("enabled") ?: false
                            )
                            result.success(null)
                        }
                        "setAuthOnResume" -> {
                            privacyManager.setAuthOnResume(
                                    call.argument<Boolean>("enabled") ?: false
                            )
                            result.success(null)
                        }
                        "setPasswordLockEnabled" -> {
                            privacyManager.setPasswordLockEnabled(
                                call.argument<Boolean>("enabled") ?: false,
                            )
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
                                    displayModeManager.applyDisplayModeRaw(
                                            call.argument<String>("raw")
                                    ),
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
                        "hasStorageAccess" -> result.success(hasStorageAccess())
                        "requestStorageAccess" -> requestStorageAccess(result)
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
                                    call.argument<String>("suggestedFileName")?.takeIf {
                                        it.isNotBlank()
                                    }
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

    private fun hasStorageAccess(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return Environment.isExternalStorageManager()
        }
        return ContextCompat.checkSelfPermission(
                activity,
                Manifest.permission.READ_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }

    private fun requestStorageAccess(result: MethodChannel.Result) {
        if (hasStorageAccess()) {
            result.success(true)
            return
        }
        if (pendingStorageAccessResult != null) {
            result.error(
                    "storage_access_in_progress",
                    "Another storage access request is already in progress",
                    null,
            )
            return
        }

        pendingStorageAccessResult = result
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                launchManageStorageAccessSettings()
            } else {
                requestLegacyStoragePermissionsLauncher.launch(
                        arrayOf(
                                Manifest.permission.READ_EXTERNAL_STORAGE,
                                Manifest.permission.WRITE_EXTERNAL_STORAGE,
                        ),
                )
            }
        } catch (e: Exception) {
            pendingStorageAccessResult = null
            result.error(
                    "storage_access_launch_failed",
                    "Failed to request storage access: ${e.message}",
                    null,
            )
        }
    }

    private fun launchManageStorageAccessSettings() {
        val intent =
                Intent(Settings.ACTION_MANAGE_APP_ALL_FILES_ACCESS_PERMISSION).apply {
                    data = Uri.parse("package:${activity.packageName}")
                }
        try {
            manageStorageAccessLauncher.launch(intent)
        } catch (_: Exception) {
            manageStorageAccessLauncher.launch(
                    Intent(Settings.ACTION_MANAGE_ALL_FILES_ACCESS_PERMISSION),
            )
        }
    }

    private fun completePendingStorageAccessResult(granted: Boolean) {
        val result = pendingStorageAccessResult ?: return
        pendingStorageAccessResult = null
        result.success(granted)
    }

    private fun setVolumeButtonPaging(enabled: Boolean, sessionId: String?): Boolean {
        if (enabled) {
            if (sessionId.isNullOrBlank()) {
                return volumeButtonPagingSessionId != null
            }
            volumeButtonPagingSessionId = sessionId
            return true
        }
        if (sessionId.isNullOrBlank() || sessionId == volumeButtonPagingSessionId) {
            volumeButtonPagingSessionId = null
            return false
        }
        return volumeButtonPagingSessionId != null
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
            }
                    ?: throw IllegalStateException("Unable to open output stream")
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
        readerDisplayChannel =
                MethodChannel(flutterEngine.dartExecutor.binaryMessenger, READER_DISPLAY_CHANNEL)
        readerDisplayChannel?.setMethodCallHandler { call, result ->
                    when (call.method) {
                        "setKeepScreenOn" -> {
                            displayModeManager.setKeepScreenOnFlag(
                                    call.argument<Boolean>("enabled") ?: false,
                            )
                            result.success(null)
                        }
                        "setReaderBrightness" -> {
                            result.success(
                                    displayModeManager.setReaderBrightness(
                                            call.argument<Double>("value")
                                    ),
                            )
                        }
                        "setVolumeButtonPaging" -> {
                            result.success(
                                    setVolumeButtonPaging(
                                            call.argument<Boolean>("enabled") ?: false,
                                            call.argument<String>("sessionId"),
                                    ),
                            )
                        }
                        else -> result.notImplemented()
                    }
                }
    }
}
