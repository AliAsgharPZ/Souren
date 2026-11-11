package ir.ario.shell;

import android.app.Activity;
import android.app.AlertDialog;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.Editable;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.animation.DecelerateInterpolator;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.util.ArrayList;
import java.util.List;

/**
 * Ario's first usable local workspace. It owns its preferences and files;
 * no Souren account, profile, or remote sync is used here.
 */
public final class ArioActivity extends Activity {
    private static final int BG = Color.rgb(247, 241, 227);
    private static final int CARD = Color.rgb(239, 231, 212);
    private static final int INK = Color.rgb(43, 38, 32);
    private static final int MUTED = Color.rgb(138, 129, 114);
    private static final int SELECTED = Color.rgb(110, 100, 85);
    private final String[] tabs = {"خانه", "یادداشت‌ها", "جست‌وجو", "تنظیمات"};
    private final String[] icons = {"⌂", "▤", "⌕", "⚙"};
    private LinearLayout root, content, nav;
    private int activeTab = 0;
    private String search = "";

    @Override protected void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().setStatusBarColor(BG);
        getWindow().setNavigationBarColor(BG);
        getWindow().getDecorView().setSystemUiVisibility(
            View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR | View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        buildShell();
        showTab(0);
    }

    private int dp(float v) { return Math.round(v * getResources().getDisplayMetrics().density); }
    private GradientDrawable shape(int color, float h) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(h * .45f));
        return d;
    }
    private TextView text(String value, int size, int color, boolean bold) {
        TextView v = new TextView(this);
        v.setText(value); v.setTextSize(size); v.setTextColor(color);
        v.setGravity(Gravity.CENTER_VERTICAL);
        if (bold) v.setTypeface(Typeface.DEFAULT, Typeface.BOLD);
        v.setFontFeatureSettings("kern");
        return v;
    }
    private LinearLayout column() {
        LinearLayout v = new LinearLayout(this); v.setOrientation(LinearLayout.VERTICAL); return v;
    }
    private LinearLayout row() {
        LinearLayout v = new LinearLayout(this); v.setOrientation(LinearLayout.HORIZONTAL);
        v.setGravity(Gravity.CENTER_VERTICAL); return v;
    }
    private void buildShell() {
        root = column(); root.setBackgroundColor(BG);
        content = column();
        root.addView(content, new LinearLayout.LayoutParams(-1, 0, 1));
        nav = row(); nav.setPadding(dp(6), dp(6), dp(6), dp(6));
        nav.setBackground(shape(CARD, 64));
        LinearLayout.LayoutParams np = new LinearLayout.LayoutParams(-1, dp(64));
        np.setMargins(dp(18), dp(4), dp(18), dp(12));
        root.addView(nav, np);
        setContentView(root);
    }
    private void showTab(int tab) {
        activeTab = tab;
        content.removeAllViews();
        LinearLayout header = column(); header.setPadding(dp(24), dp(22), dp(24), dp(14));
        header.addView(text("Ario", 27, INK, true));
        header.addView(text(tabs[tab], 13, MUTED, false));
        content.addView(header);
        ScrollView scroll = new ScrollView(this);
        scroll.setClipToPadding(false);
        LinearLayout body = column(); body.setPadding(dp(20), dp(4), dp(20), dp(24));
        scroll.addView(body);
        content.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        if (tab == 0) home(body);
        else if (tab == 1) notes(body);
        else if (tab == 2) search(body);
        else settings(body);
        renderNav();
    }
    private void home(LinearLayout body) {
        LinearLayout hero = column(); hero.setPadding(dp(22), dp(22), dp(22), dp(22));
        hero.setBackground(shape(SELECTED, 30));
        TextView eyebrow = text("فضای شخصی شما", 13, BG, false);
        TextView title = text("فکرهایت را\nمرتب کن.", 28, BG, true);
        title.setPadding(0, dp(12), 0, dp(12));
        hero.addView(eyebrow); hero.addView(title);
        hero.addView(text("یادداشت‌ها و ایده‌هایت، فقط روی همین دستگاه.", 13, 0xFFE6DDCC, false));
        body.addView(hero, margins(0, 0, 0, 16));
        body.addView(sectionTitle("شروع سریع"));
        body.addView(actionCard("یادداشت تازه", "یک ایده یا نوشته را ثبت کن", "＋", () -> createNote()));
        body.addView(actionCard("یادداشت‌ها", "همهٔ نوشته‌های ذخیره‌شده", "▤", () -> showTab(1)));
        body.addView(actionCard("جست‌وجو", "در نوشته‌هایت جست‌وجو کن", "⌕", () -> showTab(2)));
        body.addView(text("اطلاعات Ario در فضای اختصاصی خودش ذخیره می‌شود و به حساب کاربری یا سرور ارسال نمی‌شود.", 12, MUTED, false), margins(4, 18, 4, 0));
    }
    private void notes(LinearLayout body) {
        body.addView(actionCard("یادداشت تازه", "ساخت یک نوشتهٔ جدید", "＋", () -> createNote()));
        List<String> items = ArioStorage.preferences(this).getStringSet("notes", new java.util.HashSet<String>()) == null
            ? new ArrayList<>() : new ArrayList<>(ArioStorage.preferences(this).getStringSet("notes", new java.util.HashSet<String>()));
        java.util.Collections.sort(items, java.util.Collections.reverseOrder());
        if (items.isEmpty()) {
            body.addView(emptyState("هنوز یادداشتی نداری", "اولین نوشته‌ات را همین‌جا بساز."));
        } else {
            for (String item : items) {
                String[] parts = item.split("\\n", 2);
                body.addView(actionCard(parts[0], parts.length > 1 ? parts[1] : "", "↗", () -> openNote(item)));
            }
        }
    }
    private void search(LinearLayout body) {
        EditText field = new EditText(this); field.setSingleLine(true); field.setTextSize(14);
        field.setHint("جست‌وجو در یادداشت‌ها"); field.setPadding(dp(18), dp(12), dp(18), dp(12));
        field.setBackground(shape(CARD, 52)); body.addView(field, margins(0, 0, 0, 14));
        LinearLayout results = column(); body.addView(results);
        Runnable update = () -> {
            results.removeAllViews(); String q = field.getText().toString().trim();
            java.util.Set<String> all = ArioStorage.preferences(this).getStringSet("notes", new java.util.HashSet<String>());
            if (all != null) for (String item : all) if (q.isEmpty() || item.toLowerCase().contains(q.toLowerCase())) {
                String[] p = item.split("\\n", 2);
                results.addView(actionCard(p[0], p.length > 1 ? p[1] : "", "↗", () -> openNote(item)));
            }
        };
        field.addTextChangedListener(new TextWatcher() {
            public void beforeTextChanged(CharSequence s,int st,int c,int a) {}
            public void onTextChanged(CharSequence s,int st,int before,int count) { update.run(); }
            public void afterTextChanged(Editable e) {}
        });
        update.run();
    }
    private void settings(LinearLayout body) {
        body.addView(sectionTitle("حریم خصوصی"));
        body.addView(actionCard("ذخیره‌سازی محلی", "یادداشت‌ها در فضای خصوصی Ario نگهداری می‌شوند.", "▣", () -> {}));
        body.addView(actionCard("بدون همگام‌سازی ابری", "Ario هیچ اطلاعاتی را به سرور ارسال نمی‌کند.", "⌁", () -> {}));
        body.addView(sectionTitle("داده‌های Ario"));
        body.addView(actionCard("پاک‌کردن همهٔ یادداشت‌ها", "این کار فقط داده‌های Ario را پاک می‌کند.", "⌫", () -> new AlertDialog.Builder(this)
            .setMessage("همهٔ یادداشت‌های Ario پاک شوند؟")
            .setNegativeButton("انصراف", null)
            .setPositiveButton("پاک‌کردن", (d,w) -> { ArioStorage.preferences(this).edit().remove("notes").apply(); showTab(1); })
            .show()));
    }
    private TextView sectionTitle(String s) {
        TextView t = text(s, 15, INK, true); t.setPadding(dp(4), dp(8), dp(4), dp(10)); return t;
    }
    private View emptyState(String title, String sub) {
        LinearLayout box = column(); box.setPadding(dp(20), dp(22), dp(20), dp(22)); box.setBackground(shape(CARD, 26));
        box.addView(text(title, 16, INK, true)); box.addView(text(sub, 13, MUTED, false), margins(0, 6, 0, 0)); return box;
    }
    private View actionCard(String title, String sub, String glyph, Runnable action) {
        LinearLayout card = row(); card.setPadding(dp(16), dp(14), dp(16), dp(14)); card.setBackground(shape(CARD, 54));
        LinearLayout copy = column(); copy.addView(text(title, 14, INK, true)); copy.addView(text(sub, 12, MUTED, false), margins(0, 4, 0, 0));
        card.addView(copy, new LinearLayout.LayoutParams(0, -2, 1));
        TextView icon = text(glyph, 23, SELECTED, true); icon.setGravity(Gravity.CENTER); card.addView(icon, new LinearLayout.LayoutParams(dp(38), dp(38)));
        card.setOnClickListener(v -> action.run()); card.setClickable(true);
        return cardWithMargin(card);
    }
    private View cardWithMargin(View v) { return wrap(v, 0, 0, 0, 10); }
    private View margins(View v, int l, int t, int r, int b) { return wrap(v,l,t,r,b); }
    private LinearLayout.LayoutParams margins(int l, int t, int r, int b) {
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, -2); p.setMargins(dp(l),dp(t),dp(r),dp(b)); return p;
    }
    private View wrap(View v, int l, int t, int r, int b) {
        LinearLayout holder = column(); holder.addView(v); holder.setPadding(dp(l),dp(t),dp(r),dp(b)); return holder;
    }
    private void createNote() { editNote("", ""); }
    private void openNote(String item) {
        String[] p = item.split("\\n", 2); editNote(p[0], p.length > 1 ? p[1] : "");
    }
    private void editNote(String oldTitle, String oldBody) {
        LinearLayout form = column(); form.setPadding(dp(8),dp(8),dp(8),dp(4));
        EditText title = new EditText(this); title.setSingleLine(true); title.setHint("عنوان"); title.setText(oldTitle);
        EditText body = new EditText(this); body.setHint("متن یادداشت"); body.setMinLines(4); body.setGravity(Gravity.TOP); body.setText(oldBody);
        form.addView(title); form.addView(body);
        new AlertDialog.Builder(this).setTitle("یادداشت").setView(form)
            .setNegativeButton("انصراف", null)
            .setPositiveButton("ذخیره", (d,w) -> {
                java.util.Set<String> notes = new java.util.HashSet<>(ArioStorage.preferences(this).getStringSet("notes", new java.util.HashSet<String>()));
                if (!oldTitle.isEmpty()) notes.remove(oldTitle + "\n" + oldBody);
                String t = title.getText().toString().trim(); if (t.isEmpty()) t = "بدون عنوان";
                notes.add(t + "\n" + body.getText().toString().trim());
                ArioStorage.preferences(this).edit().putStringSet("notes", notes).apply(); showTab(1);
            }).show();
    }
    private void renderNav() {
        nav.removeAllViews();
        for (int i=0;i<tabs.length;i++) {
            final int index=i;
            LinearLayout item=column(); item.setGravity(Gravity.CENTER);
            TextView glyph=text(icons[i],19,i==activeTab?BG:MUTED,true); glyph.setGravity(Gravity.CENTER);
            TextView label=text(tabs[i],10,i==activeTab?BG:MUTED,i==activeTab); label.setGravity(Gravity.CENTER);
            item.addView(glyph); item.addView(label);
            if(i==activeTab) item.setBackground(shape(SELECTED,54));
            nav.addView(item,new LinearLayout.LayoutParams(0,-1,1));
            item.setOnClickListener(v -> { if(index!=activeTab) { item.animate().scaleX(.94f).scaleY(.94f).setDuration(80).withEndAction(() -> { item.animate().scaleX(1).scaleY(1).setDuration(180).setInterpolator(new DecelerateInterpolator()).start(); showTab(index); }).start(); }});
        }
    }
}
