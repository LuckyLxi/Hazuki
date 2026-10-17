package com.lxi.hazuki

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.media.MediaScannerConnection
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.webkit.MimeTypeMap
import androidx.core.content.FileProvider
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/** Image bytes have already been decoded/unscrambled by the reader's source gateway. */
class ReaderImageActions(private val activity: MainActivity) {
    fun handle(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        val extension = call.argument<String>("extension")?.lowercase()
        if (bytes == null || bytes.isEmpty() ||
            extension == null || !extension.matches(Regex("[a-z0-9]{1,10}"))) {
            result.error("invalid_image", "Missing image data or invalid extension", null)
            return
        }
        val mimeType = MimeTypeMap.getSingleton().getMimeTypeFromExtension(extension)
            ?.takeIf { it.startsWith("image/") } ?: "image/*"

        Thread {
            try {
                if (call.method == "saveImage") {
                    val fileName = call.argument<String>("fileName")
                        ?.takeIf { it.isNotBlank() && File(it).name == it && it != "." && it != ".." }
                        ?: "hazuki_${System.currentTimeMillis()}.$extension"
                    val path = saveImage(bytes, fileName, mimeType)
                    activity.runOnUiThread { result.success(path) }
                } else {
                    val directory = File(activity.cacheDir, "reader_images").apply { mkdirs() }
                    val file = File.createTempFile("hazuki_", ".$extension", directory)
                    file.writeBytes(bytes)
                    val uri = FileProvider.getUriForFile(
                        activity, "${activity.packageName}.fileprovider", file,
                    )
                    activity.runOnUiThread {
                        try {
                            when (call.method) {
                                "shareImage" -> {
                                    val intent = Intent(Intent.ACTION_SEND).apply {
                                        type = mimeType
                                        putExtra(Intent.EXTRA_STREAM, uri)
                                        clipData = ClipData.newUri(activity.contentResolver, "Hazuki", uri)
                                        addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                    }
                                    activity.startActivity(Intent.createChooser(intent, null))
                                }
                                "copyImage" -> {
                                    val clipboard = activity.getSystemService(Context.CLIPBOARD_SERVICE)
                                        as ClipboardManager
                                    clipboard.setPrimaryClip(
                                        ClipData.newUri(activity.contentResolver, "Hazuki", uri),
                                    )
                                }
                            }
                            result.success(null)
                        } catch (error: Exception) {
                            result.error("image_action_failed", error.message, null)
                        }
                    }
                }
            } catch (error: Exception) {
                activity.runOnUiThread {
                    result.error("image_action_failed", error.message, null)
                }
            }
        }.start()
    }

    private fun saveImage(bytes: ByteArray, fileName: String, mimeType: String): String {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val resolver = activity.contentResolver
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, fileName)
                put(MediaStore.Images.Media.MIME_TYPE, mimeType)
                put(MediaStore.Images.Media.RELATIVE_PATH, "${Environment.DIRECTORY_PICTURES}/Hazuki")
                put(MediaStore.Images.Media.IS_PENDING, 1)
            }
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
                ?: throw IllegalStateException("Unable to create gallery image")
            try {
                val stream = resolver.openOutputStream(uri)
                    ?: throw IllegalStateException("Unable to open gallery image")
                stream.use { it.write(bytes) }
                val published = resolver.update(uri, ContentValues().apply {
                    put(MediaStore.Images.Media.IS_PENDING, 0)
                }, null, null)
                check(published > 0) { "Unable to publish gallery image" }
                return uri.toString()
            } catch (error: Exception) {
                resolver.delete(uri, null, null)
                throw error
            }
        }

        @Suppress("DEPRECATION")
        val directory = File(
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES),
            "Hazuki",
        ).apply { mkdirs() }
        val file = File(directory, fileName)
        file.writeBytes(bytes)
        MediaScannerConnection.scanFile(activity, arrayOf(file.path), arrayOf(mimeType), null)
        return file.path
    }
}
