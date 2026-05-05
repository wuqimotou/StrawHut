package com.strawhut.strawhut

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.strawhut.strawhut/file_saver"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "saveToDownloads" -> {
                    val fileName = call.argument<String>("fileName") ?: run {
                        result.error("INVALID_ARGS", "fileName is required", null)
                        return@setMethodCallHandler
                    }
                    val mimeType = call.argument<String>("mimeType") ?: "application/json"
                    val bytes = call.argument<ByteArray>("bytes") ?: run {
                        result.error("INVALID_ARGS", "bytes are required", null)
                        return@setMethodCallHandler
                    }

                    val uri = saveToDownloads(fileName, mimeType, bytes)
                    if (uri != null) {
                        result.success(uri.toString())
                    } else {
                        result.error("SAVE_FAILED", "Failed to save file to Downloads", null)
                    }
                }
                "saveToPictures" -> {
                    val fileName = call.argument<String>("fileName") ?: run {
                        result.error("INVALID_ARGS", "fileName is required", null)
                        return@setMethodCallHandler
                    }
                    val bytes = call.argument<ByteArray>("bytes") ?: run {
                        result.error("INVALID_ARGS", "bytes are required", null)
                        return@setMethodCallHandler
                    }

                    val uri = saveToPictures(fileName, bytes)
                    if (uri != null) {
                        result.success(uri.toString())
                    } else {
                        result.error("SAVE_FAILED", "Failed to save file to Pictures", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * Save a file to the system Downloads folder.
     * 
     * On Android 10+ (API 29+): uses MediaStore.Files to preserve the exact file name
     * without MIME-based extension manipulation.
     * Falls back to direct file writing on older versions.
     */
    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            // Use MediaStore.Files instead of MediaStore.Downloads to prevent
            // Android from auto-appending extensions based on MIME type
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(
                MediaStore.Files.getContentUri("external"),
                contentValues
            )

            uri?.let {
                try {
                    resolver.openOutputStream(it)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    // Clear pending flag
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(it, contentValues, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
            uri
        } else {
            // Fallback for Android 9 and below
            val downloadsDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_DOWNLOADS
            )
            val file = File(downloadsDir, fileName)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }

    /**
     * Save a PNG image to the system Pictures folder using MediaStore.
     * Works on Android 10+ (API 29+) with scoped storage.
     * Falls back to direct file writing on older versions.
     */
    private fun saveToPictures(fileName: String, bytes: ByteArray): Uri? {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }

            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)

            uri?.let {
                try {
                    resolver.openOutputStream(it)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    // Clear pending flag
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(it, contentValues, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
            uri
        } else {
            // Fallback for Android 9 and below
            val picturesDir = Environment.getExternalStoragePublicDirectory(
                Environment.DIRECTORY_PICTURES
            )
            val file = File(picturesDir, fileName)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                null
            }
        }
    }
}
