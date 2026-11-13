package dev.local.tvoff;

import android.app.Activity;
import android.content.Intent;
import android.content.res.ColorStateList;
import android.graphics.Color;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.StateListDrawable;
import android.os.Bundle;
import android.os.CountDownTimer;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.KeyEvent;
import android.view.View;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.File;
import java.io.FileOutputStream;

/**
 * Sleep countdown for the TV watcher.
 *
 *   am start -n dev.local.tvoff/.CountdownActivity --ei seconds 30
 *
 * Writes to /sdcard/Android/data/dev.local.tvoff/files/:
 *   result          "pending" | "off" | "cancel"
 *   postpone_until  unix seconds; the watcher skips checks until then
 */
public class CountdownActivity extends Activity {
    private static final int FG = Color.parseColor("#E8E8EA");
    private static final int FG_DIM = Color.parseColor("#A8A8AD");

    private CountDownTimer timer;
    private TextView title, number;
    private LinearLayout actions;
    private Button dismiss;
    private boolean counting = false;
    private int swallowKey = -1;   // key whose UP we eat after it cancelled the countdown

    @Override
    protected void onCreate(Bundle state) {
        super.onCreate(state);
        setFinishOnTouchOutside(false);
        buildUi();
        startCountdown(getIntent());
    }

    @Override
    protected void onNewIntent(Intent intent) { // watcher re-prompted while we're still up
        super.onNewIntent(intent);
        setIntent(intent);
        startCountdown(intent);
    }

    // ---------- UI ----------

    private void buildUi() {
        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        int pad = dp(32);
        root.setPadding(pad, pad, pad, pad);

        title = new TextView(this);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        title.setTextColor(FG);
        title.setGravity(Gravity.CENTER);
        root.addView(title, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT));

        // Fixed-height body holding either the number or the actions,
        // so both states are exactly the same size.
        FrameLayout body = new FrameLayout(this);
        root.addView(body, new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, dp(150)));

        number = new TextView(this);
        number.setTextSize(TypedValue.COMPLEX_UNIT_SP, 96);
        number.setTypeface(Typeface.DEFAULT_BOLD);
        number.setTextColor(FG);
        number.setGravity(Gravity.CENTER);
        number.setIncludeFontPadding(false);
        body.addView(number, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT));

        // Shown only after activity is detected
        actions = new LinearLayout(this);
        actions.setOrientation(LinearLayout.HORIZONTAL);
        actions.setGravity(Gravity.TOP);

        // Left column: invisible label (same size as "Postpone sleep for:")
        // so Dismiss lines up with the hour buttons.
        LinearLayout left = new LinearLayout(this);
        left.setOrientation(LinearLayout.VERTICAL);
        TextView spacer = new TextView(this);
        spacer.setText(" ");
        spacer.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        spacer.setVisibility(View.INVISIBLE);
        left.addView(spacer);
        dismiss = button("Dismiss");
        dismiss.setOnClickListener(v -> finish());
        LinearLayout.LayoutParams blp = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        blp.topMargin = dp(10);
        left.addView(dismiss, blp);
        actions.addView(left);

        View divider = new View(this);
        divider.setBackgroundColor(Color.parseColor("#55555A"));
        LinearLayout.LayoutParams dlp = new LinearLayout.LayoutParams(dp(1), dp(90));
        dlp.leftMargin = dp(32);
        dlp.rightMargin = dp(32);
        actions.addView(divider, dlp);

        LinearLayout right = new LinearLayout(this);
        right.setOrientation(LinearLayout.VERTICAL);
        TextView pLabel = new TextView(this);
        pLabel.setText("Postpone sleep for:");
        pLabel.setTextSize(TypedValue.COMPLEX_UNIT_SP, 18);
        pLabel.setTextColor(FG_DIM);
        right.addView(pLabel);

        LinearLayout hours = new LinearLayout(this);
        hours.setOrientation(LinearLayout.HORIZONTAL);
        hours.setPadding(0, dp(10), 0, 0);
        for (int h = 1; h <= 3; h++) {
            final int hrs = h;
            Button b = button(h == 1 ? "1 hour" : h + " hours");
            b.setOnClickListener(v -> postpone(hrs));
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                    LinearLayout.LayoutParams.WRAP_CONTENT, LinearLayout.LayoutParams.WRAP_CONTENT);
            if (h > 1) lp.leftMargin = dp(12);
            hours.addView(b, lp);
        }
        right.addView(hours);
        actions.addView(right);

        actions.setVisibility(View.GONE);
        body.addView(actions, new FrameLayout.LayoutParams(
                FrameLayout.LayoutParams.WRAP_CONTENT, FrameLayout.LayoutParams.WRAP_CONTENT,
                Gravity.CENTER));
        setContentView(root, new ViewGroup.LayoutParams(dp(600), ViewGroup.LayoutParams.WRAP_CONTENT));
    }

    private Button button(String text) {
        Button b = new Button(this);
        b.setText(text);
        b.setAllCaps(false);
        b.setTextSize(TypedValue.COMPLEX_UNIT_SP, 20);
        b.setPadding(dp(22), dp(10), dp(22), dp(10));
        b.setFocusable(true);

        StateListDrawable bg = new StateListDrawable();
        bg.addState(new int[]{android.R.attr.state_focused}, pill(Color.parseColor("#F2F2F4")));
        bg.addState(new int[]{}, pill(Color.parseColor("#3A3A3E")));
        b.setBackground(bg);
        b.setTextColor(new ColorStateList(
                new int[][]{{android.R.attr.state_focused}, {}},
                new int[]{Color.parseColor("#111114"), FG}));
        b.setStateListAnimator(null);
        return b;
    }

    private GradientDrawable pill(int color) {
        GradientDrawable d = new GradientDrawable();
        d.setColor(color);
        d.setCornerRadius(dp(24));
        return d;
    }

    // ---------- behaviour ----------

    private void startCountdown(Intent intent) {
        int seconds = intent.getIntExtra("seconds", 30);
        if (timer != null) timer.cancel();
        writeFile("result", "pending");
        counting = true;
        swallowKey = -1;
        title.setText("TV sleeping in:");
        number.setText(String.valueOf(seconds));
        number.setVisibility(View.VISIBLE);
        actions.setVisibility(View.GONE);

        timer = new CountDownTimer(seconds * 1000L, 250) {
            @Override public void onTick(long left) {
                number.setText(String.valueOf((left + 999) / 1000));
            }
            @Override public void onFinish() {
                counting = false;
                number.setText("0");
                writeFile("result", "off");
                finish();
            }
        }.start();
    }

    private void activityDetected() {
        counting = false;
        if (timer != null) timer.cancel();
        writeFile("result", "cancel");
        title.setText("Activity detected. Sleep cancelled.");
        number.setVisibility(View.GONE);
        actions.setVisibility(View.VISIBLE);
        dismiss.requestFocus();
    }

    private void postpone(int hours) {
        long until = System.currentTimeMillis() / 1000L + hours * 3600L;
        writeFile("postpone_until", String.valueOf(until));
        finish();
    }

    @Override
    public boolean dispatchKeyEvent(KeyEvent e) {
        int code = e.getKeyCode();
        boolean volume = code == KeyEvent.KEYCODE_VOLUME_UP
                || code == KeyEvent.KEYCODE_VOLUME_DOWN
                || code == KeyEvent.KEYCODE_VOLUME_MUTE;

        if (counting) {
            if (e.getAction() == KeyEvent.ACTION_DOWN) {
                activityDetected();
                if (volume) return super.dispatchKeyEvent(e); // still change volume
                swallowKey = code;
            }
            return volume ? super.dispatchKeyEvent(e) : true;
        }
        // eat the rest of the key press that cancelled the countdown (repeats + release)
        if (swallowKey != -1 && code == swallowKey) {
            if (e.getAction() == KeyEvent.ACTION_UP) swallowKey = -1;
            return true;
        }
        return super.dispatchKeyEvent(e);
    }

    @Override
    protected void onUserLeaveHint() { // Home pressed
        if (counting) activityDetected();
        finish();
    }

    @Override
    protected void onDestroy() {
        if (timer != null) timer.cancel();
        super.onDestroy();
    }

    private void writeFile(String name, String value) {
        try {
            File dir = getExternalFilesDir(null);
            if (dir == null) return;
            try (FileOutputStream out = new FileOutputStream(new File(dir, name))) {
                out.write(value.getBytes());
            }
        } catch (Exception ignored) { }
    }

    private int dp(int v) {
        return Math.round(v * getResources().getDisplayMetrics().density);
    }
}
