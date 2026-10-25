package com.messpod.app

import android.app.Activity
import android.content.Intent
import android.database.Cursor
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private var pendingFilePickerResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ytpodcast/app_dirs"
        ).setMethodCallHandler { call, result ->
            if (call.method == "documentsPath") {
                result.success(filesDir.absolutePath)
            } else {
                result.notImplemented()
            }
        }

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "ytpodcast/file_picker"
        ).setMethodCallHandler { call, result ->
            if (call.method == "pickDictionaryFile") {
                openDictionaryFilePicker(result)
            } else {
                result.notImplemented()
            }
        }
    }

    private fun openDictionaryFilePicker(result: MethodChannel.Result) {
        if (pendingFilePickerResult != null) {
            result.error("picker_busy", "A file picker is already open.", null)
            return
        }

        pendingFilePickerResult = result
        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
            addCategory(Intent.CATEGORY_OPENABLE)
            type = "*/*"
        }
        startActivityForResult(intent, PICK_DICTIONARY_FILE_REQUEST)
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)

        if (requestCode != PICK_DICTIONARY_FILE_REQUEST) {
            return
        }

        val result = pendingFilePickerResult ?: return
        pendingFilePickerResult = null

        if (resultCode != Activity.RESULT_OK || data?.data == null) {
            result.success(null)
            return
        }

        try {
            val uri = data.data!!
            val name = sanitizeFileName(queryDisplayName(uri) ?: "dictionary.dict")
            val importsDir = File(filesDir, "dictionary_imports").apply {
                mkdirs()
            }
            val destination = File(importsDir, name)

            contentResolver.openInputStream(uri).use { input ->
                if (input == null) {
                    result.error("open_failed", "Unable to open selected file.", null)
                    return
                }
                destination.outputStream().use { output ->
                    input.copyTo(output)
                }
            }

            result.success(
                mapOf(
                    "name" to name,
                    "path" to destination.absolutePath
                )
            )
        } catch (error: Exception) {
            result.error("copy_failed", error.message, null)
        }
    }

    private fun queryDisplayName(uri: Uri): String? {
        var cursor: Cursor? = null
        return try {
            cursor = contentResolver.query(
                uri,
                arrayOf(OpenableColumns.DISPLAY_NAME),
                null,
                null,
                null
            )
            if (cursor != null && cursor.moveToFirst()) {
                val index = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (index >= 0) cursor.getString(index) else null
            } else {
                null
            }
        } finally {
            cursor?.close()
        }
    }

    private fun sanitizeFileName(name: String): String {
        return name.replace(Regex("[\\\\/:*?\"<>|]"), "_")
    }

    companion object {
        private const val PICK_DICTIONARY_FILE_REQUEST = 4097
    }
}
