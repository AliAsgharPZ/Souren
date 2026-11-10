package ir.souren.souren

import android.app.Activity
import android.content.ComponentName
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import ir.ario.shell.ArioActivity
import java.io.File

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
                    "shareText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val intent = Intent(Intent.ACTION_SEND).apply {
                            type = "text/plain"
                            putExtra(Intent.EXTRA_TEXT, text)
                        }
                        startActivity(Intent.createChooser(intent, "اشتراک‌گذاری"))
                        result.success(true)
                    }
                    "shareImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "souren-share.png"
                        val uri = if (bytes != null) savePng(bytes, name) else null
                        if (uri != null) {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "اشتراک‌گذاری"))
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "shareTextAndImage" -> {
                        val text = call.argument<String>("text") ?: ""
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "souren-share.png"
                        val uri = if (bytes != null) savePng(bytes, name) else null
                        if (uri != null) {
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "image/png"
                                putExtra(Intent.EXTRA_TEXT, text)
                                putExtra(Intent.EXTRA_STREAM, uri)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "اشتراک‌گذاری"))
                            result.success(true)
                        } else {
                            result.success(false)
                        }
                    }
                    "saveImage" -> {
                        val bytes = call.argument<ByteArray>("bytes")
                        val name = call.argument<String>("name") ?: "souren-share.png"
                        result.success(bytes != null && savePng(bytes, name) != null)
                    }
                    "saveText" -> {
                        val text = call.argument<String>("text") ?: ""
                        val name = call.argument<String>("name") ?: "souren-share.txt"
                        result.success(saveTextFile(text, name))
                    }
                    else -> result.notImplemented()
                }
            }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/ario")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        startActivity(Intent(this, ArioActivity::class.java))
                        result.success(true)
                    }
                    "launcherEnabled" -> {
                        result.success(isArioLauncherEnabled())
                    }
                    "setLauncherEnabled" -> {
                        val enabled = call.argument<Boolean>("enabled") ?: false
                        try {
                            packageManager.setComponentEnabledSetting(
                                ComponentName(this, "ir.souren.souren.ArioLauncher"),
                                if (enabled) PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                                else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                                PackageManager.DONT_KILL_APP
                            )
                            result.success(isArioLauncherEnabled())
                        } catch (error: Exception) {
                            result.error("ARIO_LAUNCHER", error.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun isArioLauncherEnabled(): Boolean {
        val component = ComponentName(this, "ir.souren.souren.ArioLauncher")
        return packageManager.getComponentEnabledSetting(component) ==
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED
    }

    /** Saves PNG bytes to Pictures/Souren and returns the content URI,
     *  which can also be shared (grant read permission on the intent). */
    private fun savePng(bytes: ByteArray, name: String): Uri? {
        return try {
            val values = ContentValues().apply {
                put(MediaStore.Images.Media.DISPLAY_NAME, name)
                put(MediaStore.Images.Media.MIME_TYPE, "image/png")
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Souren")
                }
            }
            val uri = contentResolver.insert(
                MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values) ?: return null
            contentResolver.openOutputStream(uri)?.use { it.write(bytes) }
                ?: return null
            uri
        } catch (e: Exception) {
            null
        }
    }

    /** Saves plain text to Download/Souren (Q+) or the app's external
     *  Downloads dir on older Android. */
    private fun saveTextFile(text: String, name: String): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                val values = ContentValues().apply {
                    put(MediaStore.Downloads.DISPLAY_NAME, name)
                    put(MediaStore.Downloads.MIME_TYPE, "text/plain")
                    put(MediaStore.Downloads.RELATIVE_PATH, "Download/Souren")
                }
                val uri = contentResolver.insert(
                    MediaStore.Downloads.EXTERNAL_CONTENT_URI, values)
                    ?: return false
                contentResolver.openOutputStream(uri)?.use {
                    it.write(text.toByteArray(Charsets.UTF_8))
                } ?: return false
                true
            } else {
                val dir = getExternalFilesDir(Environment.DIRECTORY_DOWNLOADS)
                    ?: return false
                File(dir, name).writeText(text)
                true
            }
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
