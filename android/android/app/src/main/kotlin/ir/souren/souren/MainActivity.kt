package ir.souren.souren

import android.app.Activity
import android.content.ClipData
import android.content.ClipDescription
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import android.content.ContentValues
import android.provider.MediaStore

class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "filesDir" -> result.success(filesDir.absolutePath)
                    "openInputSettings" -> {
                        startActivity(Intent(Settings.ACTION_INPUT_METHOD_SETTINGS))
                        result.success(null)
                    }
                    "showKeyboardPicker" -> {
                        val imm = getSystemService(Context.INPUT_METHOD_SERVICE)
                            as InputMethodManager
                        imm.showInputMethodPicker()
                        result.success(null)
                    }
                    "pickTextFile" -> {
                        pendingPick = result
                        val intent = Intent(Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = "*/*"
                            putExtra(Intent.EXTRA_MIME_TYPES,
                                arrayOf("application/json", "text/csv", "text/plain"))
                        }
                        startActivityForResult(intent, 4711)
                    }
                    // ---- share / save / copy (owner A10) ----
                    "shareText" -> {
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, call.argument<String>("text"))
                        }
                        startActivity(Intent.createChooser(send, null))
                        result.success(null)
                    }
                    "shareImage" -> {
                        val uri = writeSharePng(call.argument<ByteArray>("png")!!)
                        val send = Intent(Intent.ACTION_SEND).apply {
                            type = "image/png"
                            putExtra(Intent.EXTRA_STREAM, uri)
                            val text = call.argument<String>("text")
                            if (!text.isNullOrEmpty()) {
                                putExtra(Intent.EXTRA_TEXT, text)
                            }
                            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                        }
                        startActivity(Intent.createChooser(send, null))
                        result.success(null)
                    }
                    "saveImage" -> {
                        result.success(savePngToGallery(call.argument<ByteArray>("png")!!))
                    }
                    "copyImage" -> {
                        result.success(copyImageToClipboard(call.argument<ByteArray>("png")!!))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    /** Writes a PNG into cacheDir/share and returns a shareable content
     *  URI (FileProvider) — used for both sharing and clipboard copy. */
    private fun writeSharePng(bytes: ByteArray): Uri {
        val dir = File(cacheDir, "share").apply { mkdirs() }
        val f = File(dir, "souren-share-${System.currentTimeMillis()}.png")
        f.writeBytes(bytes)
        return FileProvider.getUriForFile(
            this, "${applicationContext.packageName}.share", f
        )
    }

    /** Saves a PNG into the phone gallery (Pictures/Souren); returns the
     *  path, or null when the platform refuses. */
    private fun savePngToGallery(bytes: ByteArray): String? {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Images.Media.DISPLAY_NAME,
                        "souren-${System.currentTimeMillis()}.png")
                    put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Souren")
                }
                val uri = contentResolver.insert(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values
                ) ?: return null
                contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                uri.toString()
            } else {
                @Suppress("DEPRECATION")
                val dir = File(
                    android.os.Environment.getExternalStoragePublicDirectory(
                        android.os.Environment.DIRECTORY_PICTURES
                    ),
                    "Souren"
                )
                dir.mkdirs()
                val f = File(dir, "souren-${System.currentTimeMillis()}.png")
                f.writeBytes(bytes)
                f.absolutePath
            }
        } catch (e: Exception) {
            null
        }
    }

    /** Copies a PNG to the clipboard as an image URI clip. */
    private fun copyImageToClipboard(bytes: ByteArray): Boolean {
        return try {
            val uri = writeSharePng(bytes)
            val cm = getSystemService(Context.CLIPBOARD_SERVICE) as android.content.ClipboardManager
            cm.setPrimaryClip(
                ClipData(
                    ClipDescription("سورن", arrayOf("image/png")),
                    ClipData.Item(uri),
                )
            )
            // Grants the current paste target temporary read access.
            true
        } catch (e: Exception) {
            false
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == 4711) {
            val result = pendingPick ?: return
            pendingPick = null
            val uri = data?.data
            if (resultCode != Activity.RESULT_OK || uri == null) {
                result.success(null)
                return
            }
            try {
                val text = contentResolver.openInputStream(uri)
                    ?.bufferedReader()?.readText()
                result.success(text)
            } catch (e: Exception) {
                result.success(null)
            }
        }
    }
}
