package ir.ario.shell;

import android.app.Activity;
import android.graphics.Color;
import android.os.Bundle;
import android.view.Gravity;
import android.view.View;
import android.widget.FrameLayout;
import android.widget.TextView;

/** Minimal native shell used to verify the Ario module boundary. */
public final class ArioActivity extends Activity {
    private static final int BACKGROUND = Color.rgb(247, 241, 227);
    private static final int FOREGROUND = Color.rgb(111, 102, 87);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        getWindow().setStatusBarColor(BACKGROUND);
        getWindow().setNavigationBarColor(BACKGROUND);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR
                | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR
        );

        FrameLayout root = new FrameLayout(this);
        root.setBackgroundColor(BACKGROUND);

        TextView marker = new TextView(this);
        marker.setText("Ario");
        marker.setTextColor(FOREGROUND);
        marker.setTextSize(22);
        marker.setGravity(Gravity.CENTER);

        root.addView(marker, new FrameLayout.LayoutParams(
            FrameLayout.LayoutParams.MATCH_PARENT,
            FrameLayout.LayoutParams.MATCH_PARENT
        ));
        setContentView(root);
    }
}
