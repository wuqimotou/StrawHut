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
        flutterEngine.plugins.add(CryptoPlugin())
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
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
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
                "saveMediaToAlbum" -> {
                    val fileName = call.argument<String>("fileName") ?: run {
                        result.error("INVALID_ARGS", "fileName is required", null)
                        return@setMethodCallHandler
                    }
                    val mimeType = call.argument<String>("mimeType") ?: "application/octet-stream"
                    val bytes = call.argument<ByteArray>("bytes") ?: run {
                        result.error("INVALID_ARGS", "bytes are required", null)
                        return@setMethodCallHandler
                    }
                    val uri = saveMediaToAlbum(fileName, mimeType, bytes)
                    if (uri != null) {
                        result.success(uri.toString())
                    } else {
                        result.error("SAVE_FAILED", "Failed to save media to album", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun saveToDownloads(fileName: String, mimeType: String, bytes: ByteArray): Uri? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Files.getContentUri("external"), contentValues)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
            return uri
        } else {
            val downloadsDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            val file = File(downloadsDir, fileName)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                return Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            }
        }
    }

    private fun saveToPictures(fileName: String, bytes: ByteArray): Uri? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, "image/png")
                put(MediaStore.MediaColumns.RELATIVE_PATH, Environment.DIRECTORY_PICTURES)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, contentValues)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
            return uri
        } else {
            val picturesDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
            val file = File(picturesDir, fileName)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                return Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            }
        }
    }

    private fun saveMediaToAlbum(fileName: String, mimeType: String, bytes: ByteArray): Uri? {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val contentUri: Uri
            val relativePath: String
            when {
                mimeType.startsWith("image/") -> {
                    contentUri = MediaStore.Images.Media.EXTERNAL_CONTENT_URI
                    relativePath = Environment.DIRECTORY_PICTURES
                }
                mimeType.startsWith("video/") -> {
                    contentUri = MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    relativePath = Environment.DIRECTORY_MOVIES
                }
                mimeType.startsWith("audio/") -> {
                    contentUri = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
                    relativePath = Environment.DIRECTORY_MUSIC
                }
                else -> {
                    contentUri = MediaStore.Files.getContentUri("external")
                    relativePath = Environment.DIRECTORY_DOWNLOADS
                }
            }
            val contentValues = ContentValues().apply {
                put(MediaStore.MediaColumns.DISPLAY_NAME, fileName)
                put(MediaStore.MediaColumns.MIME_TYPE, mimeType)
                put(MediaStore.MediaColumns.RELATIVE_PATH, relativePath)
                put(MediaStore.MediaColumns.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val uri = resolver.insert(contentUri, contentValues)
            if (uri != null) {
                try {
                    resolver.openOutputStream(uri)?.use { outputStream ->
                        outputStream.write(bytes)
                    }
                    contentValues.clear()
                    contentValues.put(MediaStore.MediaColumns.IS_PENDING, 0)
                    resolver.update(uri, contentValues, null, null)
                } catch (e: Exception) {
                    e.printStackTrace()
                    return null
                }
            }
            return uri
        } else {
            val dir = when {
                mimeType.startsWith("image/") -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_PICTURES)
                mimeType.startsWith("video/") -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MOVIES)
                mimeType.startsWith("audio/") -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_MUSIC)
                else -> Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
            }
            val file = File(dir, fileName)
            try {
                FileOutputStream(file).use { it.write(bytes) }
                return Uri.fromFile(file)
            } catch (e: Exception) {
                e.printStackTrace()
                return null
            }
        }
    }
}
