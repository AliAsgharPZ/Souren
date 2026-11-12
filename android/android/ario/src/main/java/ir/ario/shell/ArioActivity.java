package ir.ario.shell;

import android.app.Activity;
import android.app.ActivityManager;
import android.content.Intent;
import android.os.Bundle;

/**
 * Opens Ario in its own task using the existing Souren MainActivity/Flutter
 * entry point. This keeps one APK/package while isolating both UI instances.
 */
public final class ArioActivity extends Activity {
    private static final String ARIO_TASK_ACTION = "ir.souren.souren.OPEN_ARIO_TASK";

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);

        // Reuse the existing Ario task when it is already running. Do not
        // bring the Souren task forward or mutate its Flutter navigation state.
        ActivityManager manager = (ActivityManager) getSystemService(ACTIVITY_SERVICE);
        if (manager != null) {
            for (ActivityManager.AppTask task : manager.getAppTasks()) {
                Intent base = task.getTaskInfo().baseIntent;
                if (base != null && ARIO_TASK_ACTION.equals(base.getAction())) {
                    try {
                        task.moveToFront();
                        finish();
                        return;
                    } catch (RuntimeException ignored) {
                        // A stale task can disappear between enumeration and moveToFront.
                    }
                }
            }
        }

        Intent intent = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (intent != null) {
            intent.setAction(ARIO_TASK_ACTION);
            intent.putExtra("souren_open_ario", true);
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_MULTIPLE_TASK);
            startActivity(intent);
        }
        finish();
    }
}
