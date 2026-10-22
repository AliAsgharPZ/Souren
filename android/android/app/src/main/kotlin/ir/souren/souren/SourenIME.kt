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
import android.widget.LinearLayout
import android.widget.TextView
import android.widget.Toast

/** Souren keyboard — Samsung-style layout (same rows, toolbar and
 *  bottom bar as the reference screenshot), Persian-first, with the
 *  Souren correction engine and on-device learning wired in. */
class SourenIME : InputMethodService() {

    private enum class Page { FA, EN, SYMBOLS, EMOJI }

    private var page = Page.FA
    private var shifted = false
    private var capsLock = false
    private lateinit var strip: LinearLayout
    private lateinit var keysBox: LinearLayout
    private val handler = Handler(Looper.getMainLooper())
    private var deleteRepeat: Runnable? = null

    private fun dp(v: Int): Int = (v * resources.displayMetrics.density).toInt()

    override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
        super.onStartInput(info, restarting)
        KbData.load(this)
        KbData.readSettings(this)
        KbData.readLearned(this)
    }

    override fun onCreateInputView(): View {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.parseColor("#E8E8E8"))
            setPadding(dp(4), dp(6), dp(4), dp(4))
        }
        // Suggestion strip
        strip = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            setPadding(dp(6), 0, dp(6), 0)
        }
        root.addView(strip, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(42)))
        showHintStrip()
        // Toolbar (Samsung order: emoji, clipboard, keyboard/언어, settings, more)
        root.addView(buildToolbar())
        // Keys
        keysBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        root.addView(keysBox)
        rebuildKeys()
        // Bottom bar: voice (left), collapse (right)
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val mic = toolKey("🎙") { voiceInput() }
        val spacer = View(this)
        val hide = toolKey("⌄") { requestHideSelf(0) }
        bottom.addView(mic, LinearLayout.LayoutParams(dp(52), dp(38)))
        bottom.addView(spacer, LinearLayout.LayoutParams(0, 1, 1f))
        bottom.addView(hide, LinearLayout.LayoutParams(dp(52), dp(38)))
        root.addView(bottom)
        return root
    }

    // ---------------- toolbar ----------------
    private fun toolKey(label: String, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            text = label
            textSize = 17f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#3A3A3A"))
            val bg = GradientDrawable().apply {
                cornerRadius = dp(20).toFloat()
                setColor(Color.parseColor("#F2F2F2"))
            }
            background = bg
            setOnClickListener { onClick() }
        }
    }

    private fun buildToolbar(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(2), dp(2), dp(2), dp(6))
        }
        val items = listOf(
            "😊" to { page = Page.EMOJI; rebuildKeys() },
            "📋" to { pasteClipboard() },
            "⌨" to {
                page = if (page == Page.EN) Page.FA else Page.EN
                rebuildKeys()
            },
            "⚙" to { openApp() },
            "•••" to { page = Page.SYMBOLS; rebuildKeys() }
        )
        for ((label, action) in items) {
            val k = toolKey(label, action)
            val lp = LinearLayout.LayoutParams(dp(52), dp(38))
            lp.marginStart = dp(10); lp.marginEnd = dp(10)
            bar.addView(k, lp)
        }
        return bar
    }

    // ---------------- key model ----------------
    private data class K(
        val label: String,
        val out: String = label,
        val alt: String? = null,
        val weight: Float = 1f,
        val kind: Kind = Kind.CHAR,
        val shiftedLabel: String? = null
    )
    private enum class Kind { CHAR, SHIFT, DELETE, SPACE, ENTER, MODE, BACK }

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
                K("🌐", kind = Kind.MODE, weight = 1.1f),
                K("،"),
                K("فارسی", kind = Kind.SPACE, weight = 4f),
                K("◀", out = "◀"), K("▶", out = "▶"),
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
                K("🌐", kind = Kind.MODE, weight = 1.1f),
                K(","),
                K("English", kind = Kind.SPACE, weight = 4f),
                K("◀", out = "◀"), K("▶", out = "▶"),
                K("."),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            )
        )
        Page.SYMBOLS -> listOf(
            listOf("!", "@", "#", "٪", "^", "&", "*", "(", ")", "/").map { K(it) },
            listOf("-", "+", "=", "_", ":", "؛", "؟", "!", "،", ".").map { K(it) },
            listOf("«", "»", "[", "]", "{", "}", "<", ">", "|", "\\").map { K(it) },
            listOf("~", "`", "'", "\"", "…", "٫", "﷼", "€", "$", "°").map { K(it) },
            listOf(
                K("اب", kind = Kind.BACK, weight = 2f),
                K("فارسی", kind = Kind.SPACE, weight = 5f),
                K("⌫", kind = Kind.DELETE, weight = 1.5f),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            )
        )
        Page.EMOJI -> {
            val emojis = listOf(
                "😊", "😂", "😍", "🤣", "😅", "🙏", "❤️", "👍",
                "🔥", "🎉", "😎", "🤔", "😴", "😢", "😡", "🥰",
                "👏", "🙌", "💪", "👌", "✌️", "🤝", "🌹", "🌟",
                "☀️", "🌙", "⚡", "❄️", "🍎", "🍇", "☕", "🍵"
            )
            val rows = emojis.chunked(8).map { r -> r.map { K(it) } }.toMutableList()
            rows.add(listOf(
                K("اب", kind = Kind.BACK, weight = 2f),
                K("فارسی", kind = Kind.SPACE, weight = 5f),
                K("⌫", kind = Kind.DELETE, weight = 1.5f),
                K("↵", kind = Kind.ENTER, weight = 1.4f)
            ))
            rows
        }
    }

    private val shiftMap = mapOf(
        "ص" to "ض", "ع" to "غ", "ی" to "ئ", "ا" to "آ",
        "ط" to "ظ", "ز" to "ژ", "د" to "ذ", "ه" to "ة", "ک" to "ك", "گ" to "ء"
    )

    private fun rebuildKeys() {
        keysBox.removeAllViews()
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
            val lp = LinearLayout.LayoutParams(0, dp(50), k.weight)
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
        val main = TextView(this).apply {
            text = label
            textSize = if (k.kind == Kind.SPACE) 14f else 19f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#16181D"))
        }
        frame.addView(main, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
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
                    page = when (k.label) {
                        "!#1" -> Page.SYMBOLS
                        "🌐" -> if (page == Page.EN) Page.FA else Page.EN
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
        view.setOnTouchListener { _, ev ->
            if (ev.action == MotionEvent.ACTION_UP || ev.action == MotionEvent.ACTION_CANCEL) {
                stopDeleteRepeat()
            }
            false
        }
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
        showHintStrip()
    }

    private fun onEnter() {
        val ic = currentInputConnection ?: return
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

    private fun pasteClipboard() {
        val cm = getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager
        val text = cm.primaryClip?.getItemAt(0)?.coerceToText(this)?.toString()
        if (!text.isNullOrEmpty()) commit(text)
        else Toast.makeText(this, "حافظهٔ موقت خالی است", Toast.LENGTH_SHORT).show()
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
        }
    }

    // ---------------- suggestion strip ----------------
    private fun showHintStrip() {
        strip.removeAllViews()
        val t = TextView(this).apply {
            text = "سورن"
            textSize = 13f
            setTextColor(Color.parseColor("#8A8F98"))
        }
        strip.addView(t)
    }

    private fun refreshStrip() {
        if (page != Page.FA && page != Page.EN) return
        val word = currentWord()
        if (word.length < 2) { showHintStrip(); return }
        val suggestions = if (page == Page.FA) {
            Corrector.suggestionsFor(word, KbData.dictionary, KbData.learnedCounts, KbData.vocab)
        } else emptyList()
        if (suggestions.isEmpty()) { showHintStrip(); return }
        strip.removeAllViews()
        // original word chip (tap = keep as typed)
        strip.addView(chip(word, bold = true) { showHintStrip() })
        for (s in suggestions) {
            strip.addView(chip(s, bold = false) {
                val ic = currentInputConnection ?: return@chip
                val w = currentWord()
                ic.deleteSurroundingText(w.length, 0)
                ic.commitText(s, 1)
                KbData.recordLearned(this, w, s)
                refreshStrip()
            })
        }
    }

    private fun chip(text: String, bold: Boolean, onClick: () -> Unit): TextView {
        return TextView(this).apply {
            this.text = text
            textSize = 15f
            if (bold) paint.isFakeBoldText = true
            setTextColor(Color.parseColor("#16181D"))
            setPadding(dp(12), dp(6), dp(12), dp(6))
            val bg = GradientDrawable().apply {
                cornerRadius = dp(16).toFloat()
                setColor(Color.parseColor("#F7F7F7"))
            }
            background = bg
            val lp = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT)
            lp.marginStart = dp(4); lp.marginEnd = dp(4)
            layoutParams = lp
            setOnClickListener { onClick() }
        }
    }
}
