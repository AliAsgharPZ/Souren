package ir.ario.shell;

import android.app.Activity;
import android.content.Intent;
import android.os.Bundle;
import ir.souren.souren.MainActivity;

/** Launcher trampoline into the shared Souren Flutter experience. */
public final class ArioActivity extends Activity {
    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        Intent intent = new Intent(this, MainActivity.class);
        intent.putExtra("souren_open_ario", true);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        startActivity(intent);
        finish();
    }
}
