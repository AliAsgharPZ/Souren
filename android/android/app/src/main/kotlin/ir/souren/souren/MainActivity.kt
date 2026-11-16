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
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import android.view.inputmethod.InputMethodManager
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

open class MainActivity : FlutterActivity() {
    private var pendingPick: MethodChannel.Result? = null
    private var arioChannel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/files")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "secureRead" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrBlank()) result.error("SECURE_KEY", "Missing secure key", null)
                        else try { result.success(readSecureValue(key)) }
                        catch (error: Exception) { result.error("SECURE_READ", "Could not decrypt secure value", null) }
                    }
                    "secureWrite" -> {
                        val key = call.argument<String>("key")
                        val value = call.argument<String>("value")
                        if (key.isNullOrBlank() || value == null) result.error("SECURE_VALUE", "Missing secure value", null)
                        else try { writeSecureValue(key, value); result.success(true) }
                        catch (error: Exception) { result.error("SECURE_WRITE", "Could not encrypt secure value", null) }
                    }
                    "secureDelete" -> {
                        val key = call.argument<String>("key")
                        if (key.isNullOrBlank()) result.error("SECURE_KEY", "Missing secure key", null)
                        else { getSharedPreferences("souren_secure", Context.MODE_PRIVATE).edit().remove(key).apply(); result.success(true) }
                    }
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

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "refresh" -> {
                        SourenWidgetProvider.refreshAll(applicationContext)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }

        arioChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/ario")
        arioChannel?.setMethodCallHandler { call, result ->
                when (call.method) {
                    "open" -> {
                        startActivity(Intent(this, ArioActivity::class.java))
                        result.success(true)
                    }
                    "consumeArioLaunch" -> {
                        val open = intent?.getBooleanExtra("souren_open_ario", false) == true
                        intent?.removeExtra("souren_open_ario")
                        result.success(open)
                    }
                    "consumeWidgetAction" -> {
                        val action = intent?.getStringExtra("souren_widget_action")
                        intent?.removeExtra("souren_widget_action")
                        result.success(action)
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

    private fun secureKey(): SecretKey {
        val alias = "souren.account.session.aes"
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        val existing = keyStore.getKey(alias, null) as? SecretKey
        if (existing != null) return existing
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                alias,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT
            )
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build()
        )
        return generator.generateKey()
    }

    private fun readSecureValue(name: String): String? {
        val encoded = getSharedPreferences("souren_secure", Context.MODE_PRIVATE).getString(name, null)
            ?: return null
        val packed = Base64.decode(encoded, Base64.NO_WRAP)
        require(packed.size > 12) { "Invalid encrypted value" }
        val iv = packed.copyOfRange(0, 12)
        val encrypted = packed.copyOfRange(12, packed.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secureKey(), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }

    private fun writeSecureValue(name: String, value: String) {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secureKey())
        val packed = cipher.iv + cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val encoded = Base64.encodeToString(packed, Base64.NO_WRAP)
        check(getSharedPreferences("souren_secure", Context.MODE_PRIVATE)
            .edit().putString(name, encoded).commit())
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra("souren_open_ario", false)) {
            intent.removeExtra("souren_open_ario")
            arioChannel?.invokeMethod("openArio", null)
        }
        val widgetAction = intent.getStringExtra("souren_widget_action")
        if (!widgetAction.isNullOrBlank()) {
            intent.removeExtra("souren_widget_action")
            arioChannel?.invokeMethod("openWidgetAction", widgetAction)
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
