package ir.souren.souren

import android.content.Intent
import android.provider.Settings
import android.view.inputmethod.InputMethodManager
import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
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
                    else -> result.notImplemented()
                }
            }
    }
}
