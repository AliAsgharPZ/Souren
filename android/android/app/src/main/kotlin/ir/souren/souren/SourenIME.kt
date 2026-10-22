package ir.souren.souren

import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.drawable.GradientDrawable
import android.inputmethodservice.InputMethodService
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.inputmethod.EditorInfo
import android.view.inputmethod.InputMethodManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import android.widget.Toast

/** Souren keyboard v2 — modelled on the Samsung Keyboard (One UI):
 *  a toolbar strip that swaps with the suggestion strip while typing
 *  (back-arrow returns to the toolbar), Persian number row, long-press
 *  alternates, a dedicated ZWNJ key (Samsung's dashed-arrow key),
 *  key-press preview bubble, clipboard panel, symbols + English pages.
 *  Icons are linear stroke vectors — no emoji anywhere. */
class SourenIME : InputMethodService() {

    private enum class Page { FA, EN, SYMBOLS, CLIPBOARD }

    private var page = Page.FA
    private var shifted = false
    private var capsLock = false
    private lateinit var rootFrame: FrameLayout
    private lateinit var stripArea: FrameLayout
    private lateinit var toolbarView: LinearLayout
    private lateinit var suggestView: LinearLayout
    private lateinit var keysBox: LinearLayout
    private lateinit var preview: TextView
    private val handler = Handler(Looper.getMainLooper())
    private var deleteRepeat: Runnable? = null

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()
    private fun rowHeight(): Int = when (KbData.kbHeight) {
        "short" -> dp(47)
        "normal" -> dp(53)
        else -> dp(58)
    }

    override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
        super.onStartInput(info, restarting)
        KbData.load(this)
        KbData.readSettings(this)
        KbData.readLearned(this)
    }

    override fun onCreateInputView(): View {
        rootFrame = FrameLayout(this)
        val content = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E8E8E8"))
            setPadding(dp(4), dp(6), dp(4), dp(4))
        }
        rootFrame.addView(content, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        // Strip area: toolbar XOR suggestions (Samsung behaviour)
        stripArea = FrameLayout(this)
        toolbarView = buildToolbar()
        suggestView = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            setPadding(dp(4), 0, dp(4), 0)
            visibility = View.GONE
        }
        stripArea.addView(toolbarView)
        stripArea.addView(suggestView)
        content.addView(stripArea, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(46)))

        keysBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(keysBox)
        rebuildKeys()

        // Bottom bar: voice (icon), spacer, collapse (icon)
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        bottom.addView(iconButton(R.drawable.ic_mic) { voiceInput() },
            LinearLayout.LayoutParams(dp(52), dp(38)))
        bottom.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
        bottom.addView(iconButton(R.drawable.ic_chevron_down) { requestHideSelf(0) },
            LinearLayout.LayoutParams(dp(52), dp(38)))
        content.addView(bottom)

        // Key-press preview bubble (hidden)
        preview = TextView(this).apply {
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#16181D"))
            background = GradientDrawable().apply {
                cornerRadius = dp(10).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#D8D8D8"))
            }
            visibility = View.GONE
        }
        rootFrame.addView(preview, FrameLayout.LayoutParams(dp(52), dp(58)))
        return rootFrame
    }

    // ---------------- toolbar / strip ----------------
    private fun iconButton(resId: Int, onClick: () -> Unit): ImageView {
        return ImageView(this).apply {
            setImageResource(resId)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(dp(11), dp(8), dp(11), dp(8))
            background = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#F2F2F2"))
            }
            setOnClickListener { onClick() }
        }
    }

    private fun buildToolbar(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(2), dp(3), dp(2), dp(3))
        }
        val items = listOf(
            R.drawable.ic_clipboard to { openClipboard() },
            R.drawable.ic_keyboard to {
                page = if (page == Page.EN) Page.FA else Page.EN
                rebuildKeys()
            },
            R.drawable.ic_sliders to { openApp() },
            R.drawable.ic_more to { page = Page.SYMBOLS; rebuildKeys() }
        )
        for ((res, action) in items) {
            val b = iconButton(res, action)
            val lp = LinearLayout.LayoutParams(dp(54), dp(38))
            lp.marginStart = dp(12); lp.marginEnd = dp(12)
            bar.addView(b, lp)
        }
        return bar
    }

    private fun showToolbar() {
        toolbarView.visibility = View.VISIBLE
        suggestView.visibility = View.GONE
    }

    private fun showSuggestions(chips: List<String>, word: String) {
        suggestView.removeAllViews()
        // back-arrow returns to the toolbar (Samsung behaviour)
        suggestView.addView(iconButton(R.drawable.ic_arrow_back) { showToolbar() })
        suggestView.addView(chip(word, bold = true) { showToolbar() })
        for (s in chips) {
            suggestView.addView(chip(s, bold = false) {
                val ic = currentInputConnection ?: return@chip
                val w = currentWord()
                ic.deleteSurroundingText(w.length, 0)
                ic.commitText(s, 1)
                KbData.recordLearned(this, w, s)
                refreshStrip()
            })
        }
        toolbarView.visibility = View.GONE
        suggestView.visibility = View.VISIBLE
    }

    private fun chip(text: String, bold: Boolean, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 15f
            if (bold) paint.isFakeBoldText = true
            setTextColor(Color.parseColor("#16181D"))
            setPadding(dp(12), dp(6), dp(12), dp(6))
            background = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#F7F7F7"))
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            lp.marginStart = dp(4); lp.marginEnd = dp(4)
            layoutParams = lp
            setOnClickListener { onClick() }
        }
    }

    // ---------------- key model ----------------
    private data class K(
        val label: String,
        val alt: String? = null,
        val weight: Float = 1f,
        val kind: Kind = Kind.CHAR,
        val iconRes: Int = 0
    )
    private enum class Kind { CHAR, SHIFT, DELETE, SPACE, ENTER, MODE, BACK, ZWNJ }

    private fun rowsFor(p: Page): List<List<K>> = when (p) {
        Page.FA -> listOf(
            "۱۲۳۴۵۶۷۸۹۰".map { K(it.toString()) },
            listOf(
                K("ص", alt = "ض"), K("ث"), K("ق"), K("ف"), K("ع", alt = "غ"),
                K("ه"), K("خ"), K("ح"), K("ج"), K("چ")
            ),
            listOf(
                K("ش"), K("س"), K("ی", alt = "ئ"), K("ب"), K("ل"),
                K("ا", alt = "آ"), K("ت"), K("ن"), K("م"), K("پ")
            ),
            listOf(
                K("⇧", kind = Kind.SHIFT, weight = 1.5f),
                K("ط", alt = "ظ"), K("ز", alt = "ژ"), K("ر"), K("د", alt = "ذ"),
                K("و"), K("ک"), K("گ", alt = "ء"),
                K("⌫", kind = Kind.DELETE, weight = 1.5f)
            ),
            listOf(
                K("!#1", kind = Kind.MODE, weight = 1.4f),
                K("", kind = Kind.MODE, iconRes = R.drawable.ic_globe, weight = 1.1f),
                K("،"),
                K("فارسی", kind = Kind.SPACE, weight = 3.9f),
                K("◀┆▶", kind = Kind.ZWNJ, weight = 1.2f),
                K("."),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            )
        )
        Page.EN -> listOf(
            "1234567890".map { K(it.toString()) },
            "qwertyuiop".map { K(it.toString()) },
            "asdfghjkl".map { K(it.toString()) },
            listOf(K("⇧", kind = Kind.SHIFT, weight = 1.5f)) +
                "zxcvbnm".map { K(it.toString()) } +
                listOf(K("⌫", kind = Kind.DELETE, weight = 1.5f)),
            listOf(
                K("!#1", kind = Kind.MODE, weight = 1.4f),
                K("", kind = Kind.MODE, iconRes = R.drawable.ic_globe, weight = 1.1f),
                K(","),
                K("English", kind = Kind.SPACE, weight = 4.6f),
                K("."),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            )
        )
        Page.SYMBOLS -> listOf(
            listOf("!", "@", "#", "٪", "^", "&", "*", "(", ")", "/").map { K(it) },
            listOf("-", "+", "=", "_", ":", "؛", "؟", "!", "،", ".").map { K(it) },
            listOf("«", "»", "[", "]", "{", "}", "<", ">", "|", "\\").map { K(it) },
            listOf("~", "`", "'", "\"", "…", "٫", "€", "$", "°", "•").map { K(it) },
            listOf(
                K("◀"), K("▶"),
                K("اب", kind = Kind.BACK, weight = 1.6f),
                K("فارسی", kind = Kind.SPACE, weight = 4f),
                K("⌫", kind = Kind.DELETE, weight = 1.5f),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            )
        )
        Page.CLIPBOARD -> emptyList()
    }

    private val shiftMap = mapOf(
        "ص" to "ض", "ع" to "غ", "ی" to "ئ", "ا" to "آ",
        "ط" to "ظ", "ز" to "ژ", "د" to "ذ", "ه" to "ة", "ک" to "ك", "گ" to "ء"
    )

    private fun rebuildKeys() {
        keysBox.removeAllViews()
        if (page == Page.CLIPBOARD) {
            keysBox.addView(buildClipboardPanel())
            return
        }
        for (row in rowsFor(page)) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(3), 0, dp(3))
            }
            for (k in row) rowLayout.addView(makeKey(k))
            keysBox.addView(rowLayout)
        }
    }

    private fun keyBackground(special: Boolean): GradientDrawable {
        return GradientDrawable().apply {
            cornerRadius = dp(8).toFloat()
            setColor(Color.parseColor(if (special) "#C9CDD6" else "#FFFFFF"))
        }
    }

    private fun makeKey(k: K): View {
        val special = k.kind != Kind.CHAR
        val frame = FrameLayout(this).apply {
            background = keyBackground(special)
            val lp = LinearLayout.LayoutParams(0, rowHeight(), k.weight)
            lp.marginStart = dp(3); lp.marginEnd = dp(3)
            layoutParams = lp
        }
        var label = k.label
        if (page == Page.FA && shifted && shiftMap.containsKey(k.label)) {
            label = shiftMap[k.label]!!
        }
        if (page == Page.EN && (shifted || capsLock) && k.kind == Kind.CHAR &&
            k.label.length == 1 && k.label[0].isLetter()
        ) {
            label = k.label.uppercase()
        }
        if (k.iconRes != 0) {
            val iv = ImageView(this).apply {
                setImageResource(k.iconRes)
                scaleType = ImageView.ScaleType.CENTER_INSIDE
                setPadding(dp(10), dp(10), dp(10), dp(10))
            }
            frame.addView(iv, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        } else {
            val main = TextView(this).apply {
                text = label
                textSize = when {
                    k.kind == Kind.SPACE -> 14f
                    k.kind == Kind.ZWNJ -> 13f
                    else -> 19f
                }
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#16181D"))
            }
            frame.addView(main, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        }
        val altText = if (shifted) null else k.alt
        if (altText != null && page == Page.FA) {
            val alt = TextView(this).apply {
                text = altText
                textSize = 9f
                setTextColor(Color.parseColor("#9AA0A6"))
                setPadding(0, dp(2), dp(5), 0)
            }
            frame.addView(alt, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT,
                ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.END))
        }
        attachKeyBehavior(frame, k, label)
        return frame
    }

    // ---------------- key behaviour ----------------
    private fun attachKeyBehavior(view: View, k: K, label: String) {
        view.setOnClickListener {
            when (k.kind) {
                Kind.CHAR -> {
                    if (label == "◀") moveCursor(-1)
                    else if (label == "▶") moveCursor(1)
                    else commit(label)
                    if (page == Page.EN && shifted && !capsLock) {
                        shifted = false; rebuildKeys()
                    }
                    if (page == Page.FA && shifted) {
                        shifted = false; rebuildKeys()
                    }
                }
                Kind.ZWNJ -> commit(Corrector.ZWNJ)
                Kind.SPACE -> onSpace()
                Kind.ENTER -> onEnter()
                Kind.DELETE -> deleteOnce()
                Kind.SHIFT -> {
                    if (page == Page.EN && shifted) capsLock = !capsLock
                    shifted = !shifted
                    if (!shifted) capsLock = false
                    rebuildKeys()
                }
                Kind.MODE -> {
                    page = when {
                        k.label == "!#1" -> Page.SYMBOLS
                        k.iconRes == R.drawable.ic_globe ->
                            if (page == Page.EN) Page.FA else Page.EN
                        else -> page
                    }
                    rebuildKeys()
                }
                Kind.BACK -> { page = Page.FA; rebuildKeys() }
            }
        }
        view.setOnLongClickListener {
            when {
                k.kind == Kind.DELETE -> { startDeleteRepeat(); true }
                k.alt != null && page == Page.FA && !shifted -> { commit(k.alt); true }
                else -> false
            }
        }
        view.setOnTouchListener { v, ev ->
            when (ev.action) {
                MotionEvent.ACTION_DOWN -> {
                    if (k.kind == Kind.CHAR && label.length == 1) showPreview(v, label)
                }
                MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                    stopDeleteRepeat()
                    handler.postDelayed({ preview.visibility = View.GONE }, 50)
                }
            }
            false
        }
    }

    private fun showPreview(key: View, text: String) {
        val rootLoc = IntArray(2); rootFrame.getLocationInWindow(rootLoc)
        val keyLoc = IntArray(2); key.getLocationInWindow(keyLoc)
        preview.text = text
        val lp = preview.layoutParams as FrameLayout.LayoutParams
        lp.leftMargin = keyLoc[0] - rootLoc[0] + key.width / 2 - dp(26)
        lp.topMargin = (keyLoc[1] - rootLoc[1] - dp(62)).coerceAtLeast(0)
        preview.layoutParams = lp
        preview.visibility = View.VISIBLE
    }

    // ---------------- clipboard panel ----------------
    private fun openClipboard() {
        // Remember the system's current clip as the newest history item.
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val cur = cm.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()
        if (!cur.isNullOrEmpty()) KbData.rememberClipboard(this, cur)
        page = Page.CLIPBOARD
        rebuildKeys()
    }

    private fun buildClipboardPanel(): View {
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(8), dp(6), dp(8), dp(8))
        }
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val title = TextView(this).apply {
            text = "کلیپ‌بورد"
            textSize = 16f
            paint.isFakeBoldText = true
            setTextColor(Color.parseColor("#16181D"))
        }
        header.addView(title, LinearLayout.LayoutParams(0, dp(40), 1f))
        val clear = TextView(this).apply {
            text = "پاک‌کردن همه"
            textSize = 13f
            setTextColor(Color.parseColor("#8A2F2F"))
            setPadding(dp(10), dp(6), dp(10), dp(6))
            setOnClickListener {
                val kept = KbData.clipboardItems(this@SourenIME).filter { it.second }
                KbData.saveClipboardItems(this@SourenIME, kept)
                rebuildKeys()
            }
        }
        header.addView(clear)
        val back = TextView(this).apply {
            text = "بازگشت"
            textSize = 13f
            setTextColor(Color.parseColor("#16181D"))
            setPadding(dp(10), dp(6), dp(10), dp(6))
            setOnClickListener { page = Page.FA; rebuildKeys() }
        }
        header.addView(back)
        panel.addView(header)

        val items = KbData.clipboardItems(this)
        val scroll = ScrollView(this)
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        if (items.isEmpty()) {
            list.addView(TextView(this).apply {
                text = "هنوز چیزی در کلیپ‌بورد نیست. متنی را کپی کنید و دوباره اینجا را باز کنید."
                textSize = 14f
                setTextColor(Color.parseColor("#6E6E6E"))
                setPadding(dp(8), dp(16), dp(8), dp(16))
            })
        }
        for ((text, pinned) in items) {
            val row = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                gravity = Gravity.CENTER_VERTICAL
                background = GradientDrawable().apply {
                    cornerRadius = dp(10).toFloat()
                    setColor(Color.WHITE)
                }
                setPadding(dp(12), dp(10), dp(12), dp(10))
            }
            val body = TextView(this).apply {
                this.text = text
                textSize = 15f
                maxLines = 2
                setTextColor(Color.parseColor("#16181D"))
            }
            row.addView(body, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
            val pin = TextView(this).apply {
                this.text = if (pinned) "سنجاق‌شده" else "سنجاق"
                textSize = 12f
                setTextColor(Color.parseColor("#8A8172"))
                setPadding(dp(8), dp(4), dp(8), dp(4))
                setOnClickListener {
                    val all = KbData.clipboardItems(this@SourenIME)
                    val updated = all.map {
                        if (it.first == text) it.first to !it.second else it
                    }
                    KbData.saveClipboardItems(this@SourenIME, updated)
                    rebuildKeys()
                }
            }
            row.addView(pin)
            row.setOnClickListener {
                currentInputConnection?.commitText(text, 1)
                page = Page.FA
                rebuildKeys()
            }
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            lp.bottomMargin = dp(7)
            list.addView(row, lp)
        }
        scroll.addView(list)
        panel.addView(scroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(208)))
        return panel
    }

    // ---------------- editing ----------------
    private fun commit(text: String) {
        currentInputConnection?.commitText(text, 1)
        refreshStrip()
    }

    private fun currentWord(): String {
        val ic = currentInputConnection ?: return ""
        val before = ic.getTextBeforeCursor(48, 0)?.toString() ?: return ""
        val seps = charArrayOf(' ', '\n', '،', '.', '؟', '!', '؛', ':', '(', ')', '«', '»', '"')
        val idx = before.lastIndexOfAny(seps)
        return if (idx < 0) before else before.substring(idx + 1)
    }

    private fun refreshStrip() {
        if (page != Page.FA && page != Page.EN) return
        val word = currentWord()
        if (word.length < 2 || page != Page.FA) { showToolbar(); return }
        val suggestions = Corrector.suggestionsFor(
            word, KbData.dictionary, KbData.learnedCounts, KbData.vocab)
        if (suggestions.isEmpty()) showToolbar()
        else showSuggestions(suggestions, word)
    }

    private fun onSpace() {
        val ic = currentInputConnection ?: return
        if (KbData.autoCorrect && page == Page.FA) {
            val before = ic.getTextBeforeCursor(64, 0)?.toString() ?: ""
            val fix = Corrector.fixBeforeSeparator(before, KbData.dictionary, KbData.replaceArabic)
            if (fix != null) {
                val fromWord = before.split(' ').lastOrNull() ?: ""
                ic.deleteSurroundingText(fix.first, 0)
                ic.commitText(fix.second, 1)
                val toWord = fix.second.split(' ').lastOrNull() ?: ""
                if (fromWord.isNotEmpty() && toWord.isNotEmpty() && fromWord != toWord) {
                    KbData.recordLearned(this, fromWord, toWord)
                }
            }
        }
        ic.commitText(" ", 1)
        showToolbar()
    }

    private fun onEnter() {
        val ic = currentInputConnection ?: return
        // Auto-correction also applies on Enter (Samsung behaviour).
        if (KbData.autoCorrect && page == Page.FA) {
            val before = ic.getTextBeforeCursor(64, 0)?.toString() ?: ""
            val fix = Corrector.fixBeforeSeparator(before, KbData.dictionary, KbData.replaceArabic)
            if (fix != null) {
                ic.deleteSurroundingText(fix.first, 0)
                ic.commitText(fix.second, 1)
            }
        }
        val action = currentInputEditorInfo?.imeOptions?.and(EditorInfo.IME_MASK_ACTION)
            ?: EditorInfo.IME_ACTION_NONE
        if (action != EditorInfo.IME_ACTION_NONE &&
            action != EditorInfo.IME_ACTION_UNSPECIFIED
        ) {
            ic.performEditorAction(action)
        } else {
            ic.commitText("\n", 1)
        }
    }

    private fun deleteOnce() {
        val ic = currentInputConnection ?: return
        val sel = ic.getSelectedText(0)
        if (sel.isNullOrEmpty()) ic.deleteSurroundingText(1, 0)
        else ic.commitText("", 1)
        refreshStrip()
    }

    private fun startDeleteRepeat() {
        deleteOnce()
        val r = object : Runnable {
            override fun run() {
                deleteOnce()
                handler.postDelayed(this, 55)
            }
        }
        deleteRepeat = r
        handler.postDelayed(r, 380)
    }

    private fun stopDeleteRepeat() {
        deleteRepeat?.let { handler.removeCallbacks(it) }
        deleteRepeat = null
    }

    private fun moveCursor(delta: Int) {
        val ic = currentInputConnection ?: return
        val before = ic.getTextBeforeCursor(200, 0)?.toString() ?: ""
        val after = ic.getTextAfterCursor(200, 0)?.toString() ?: ""
        val pos = (before.length + delta).coerceIn(0, before.length + after.length)
        ic.setSelection(pos, pos)
    }

    private fun openApp() {
        val intent = Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        startActivity(intent)
    }

    private fun voiceInput() {
        val imm = getSystemService(Context.INPUT_METHOD_SERVICE) as InputMethodManager
        val voice = imm.inputMethodList.firstOrNull { imi ->
            (0 until imi.subtypeCount).any { i ->
                imi.getSubtypeAt(i).mode.contains("voice", ignoreCase = true)
            }
        }
        if (voice != null) {
            @Suppress("DEPRECATION")
            switchInputMethod(voice.id)
        } else {
            imm.showInputMethodPicker()
            Toast.makeText(this, "ورودی صوتی آماده نیست؛ از فهرست، ورودی صوتی را برگزینید", Toast.LENGTH_LONG).show()
        }
    }
}
