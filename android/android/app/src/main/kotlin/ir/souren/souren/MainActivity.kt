package ir.souren.souren

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Build
import android.provider.Settings
import android.view.RoundedCorner
import android.view.inputmethod.InputMethodManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                    else -> result.notImplemented()
                }
            }
        // Screen corner radius (API 31+): the nav bar's corners must
        // match the phone's own rounded screen corners. Returns the
        // largest bottom-corner radius in dp, or 0 when unavailable
        // (the Dart side falls back to a sensible default).
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "souren/screen")
            .setMethodCallHandler { call, result ->
                if (call.method == "cornerRadius") {
                    var px = 0
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val insets = window.decorView.rootWindowInsets
                        val bl = insets?.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_LEFT)?.radius ?: 0
                        val br = insets?.getRoundedCorner(RoundedCorner.POSITION_BOTTOM_RIGHT)?.radius ?: 0
                        px = maxOf(bl, br)
                    }
                    val dp = px / resources.displayMetrics.density
                    result.success(dp.toDouble())
                } else {
                    result.notImplemented()
                }
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
