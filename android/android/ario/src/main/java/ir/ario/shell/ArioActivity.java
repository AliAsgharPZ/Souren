package ir.ario.shell;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.View;

/** Empty native shell used to verify the Ario module boundary. */
public final class ArioActivity extends Activity {
    private static final int BACKGROUND = Color.rgb(247, 241, 227);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(BACKGROUND);
        getWindow().setNavigationBarColor(BACKGROUND);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        );

        View root = new View(this);
        root.setBackgroundColor(BACKGROUND);
        setContentView(root);
    }
}
