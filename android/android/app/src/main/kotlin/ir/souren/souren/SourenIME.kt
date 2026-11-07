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
import android.widget.FrameLayout
import android.widget.HorizontalScrollView
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView

/** Souren keyboard v3 — a faithful copy of the Samsung Keyboard (One UI)
 *  behaviour, per the owner's order:
 *  - ISIRI Persian layout (the layout Samsung/Android use for Persian),
 *    optional Persian number row, toolbar that swaps with the
 *    suggestion strip while typing.
 *  - Long-press opens a popup ABOVE the key holding everything the
 *    shift layer would show plus the key's relatives; the first option
 *    is pre-selected, sliding the finger picks another, releasing
 *    inserts it (Samsung's exact gesture).
 *  - Spacebar: horizontal drag switches language (FA <-> EN);
 *    long-press turns it into a cursor trackpad.
 *  - The comma-side key is Samsung's "custom" key: it remembers the
 *    last symbol picked from its long-press popup.
 *  - Emoji panel with categories, recents, keyword search and
 *    long-press skin tones; two symbol pages, the second carrying the
 *    full Arabic ligature/glyph set (﷽ ﷲ ﷺ ﷻ ﷼, diacritics, tatweel).
 *  - Keys are built once per page; shift only relabels them in place
 *    (the v2 full-rebuild on every keystroke-state change was the lag).
 *  Icons are linear stroke vectors — no emoji anywhere in the chrome. */
class SourenIME : InputMethodService() {

    private enum class Page { FA, EN, SYMBOLS, SYMBOLS2, EMOJI, CLIPBOARD }

    private var page = Page.FA
    private var lastLang = Page.FA
    private var shifted = false
    private var capsLock = false
    private lateinit var rootFrame: FrameLayout
    private lateinit var stripArea: FrameLayout
    private lateinit var toolbarView: LinearLayout
    private lateinit var suggestView: LinearLayout
    private lateinit var keysBox: LinearLayout
    private lateinit var preview: TextView
    private lateinit var popupBar: LinearLayout
    private val handler = Handler(Looper.getMainLooper())
    private var deleteRepeat: Runnable? = null
    private var lastWordShown = ""

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
            setBackgroundColor(Color.parseColor("#E3E4E7"))
            // Bottom clearance so the last row never fights the phone's
            // gesture/navigation area (Samsung keeps the same gap).
            setPadding(dp(5), 0, dp(5), dp(12))
        }
        rootFrame.addView(content, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT))

        stripArea = FrameLayout(this).apply {
            setBackgroundColor(Color.parseColor("#F7F7F8"))
        }
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
            ViewGroup.LayoutParams.MATCH_PARENT, dp(48)))

        keysBox = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        content.addView(keysBox)
        rebuildKeys()

        preview = TextView(this).apply {
            textSize = 26f
            gravity = Gravity.CENTER
            setTextColor(Color.parseColor("#16181D"))
            background = GradientDrawable().apply {
                cornerRadius = dp(12).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#D8D8D8"))
            }
            visibility = View.GONE
        }
        rootFrame.addView(preview, FrameLayout.LayoutParams(dp(52), dp(58)))

        popupBar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(5), dp(5), dp(5), dp(5))
            background = GradientDrawable().apply {
                cornerRadius = dp(14).toFloat()
                setColor(Color.WHITE)
                setStroke(dp(1), Color.parseColor("#C9CCD1"))
            }
            elevation = dp(6).toFloat()
            visibility = View.GONE
        }
        rootFrame.addView(popupBar, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.WRAP_CONTENT, dp(58)))
        return rootFrame
    }

    // ---------------- toolbar / strip ----------------
    private fun iconButton(resId: Int, onClick: () -> Unit): ImageView {
        return ImageView(this).apply {
            setImageResource(resId)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(dp(10), dp(10), dp(10), dp(10))
            background = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(Color.parseColor("#ECEDEF"))
            }
            setOnClickListener { onClick() }
        }
    }

    private fun plainIconButton(resId: Int, onClick: () -> Unit): ImageView {
        return ImageView(this).apply {
            setImageResource(resId)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
            setPadding(dp(8), dp(8), dp(8), dp(8))
            alpha = 0.75f
            setOnClickListener { onClick() }
        }
    }

    private fun buildToolbar(): LinearLayout {
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(14), dp(3), dp(14), dp(3))
        }
        val items = listOf(
            R.drawable.ic_emoji to { page = Page.EMOJI; emojiSearchOn = false; rebuildKeys() },
            R.drawable.ic_clipboard to { openClipboard() },
            R.drawable.ic_keyboard to {
                val target = if (page == Page.EN) Page.FA else Page.EN
                page = target; lastLang = target
                rebuildKeys()
            },
            R.drawable.ic_gear to { openApp() },
            R.drawable.ic_more to { page = Page.SYMBOLS; rebuildKeys() }
        )
        items.forEachIndexed { i, (res, action) ->
            if (i > 0) bar.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
            bar.addView(iconButton(res, action), LinearLayout.LayoutParams(dp(42), dp(42)))
        }
        return bar
    }

    private fun showToolbar() {
        if (page != Page.FA && page != Page.EN) return
        toolbarView.visibility = View.VISIBLE
        suggestView.visibility = View.GONE
    }

    private fun showSuggestions(chips: List<String>, word: String) {
        suggestView.removeAllViews()
        val slots = mutableListOf<Pair<String, Boolean>>()
        slots.add(word to false)
        for (c in chips) if (slots.size < 3) slots.add(c to (slots.size == 1))
        slots.forEachIndexed { i, (text, bold) ->
            if (i > 0) {
                val div = View(this).apply { setBackgroundColor(Color.parseColor("#D9DBDF")) }
                suggestView.addView(div, LinearLayout.LayoutParams(dp(1), dp(24)))
            }
            val slot = TextView(this).apply {
                this.text = text
                textSize = 15.5f
                if (bold) paint.isFakeBoldText = true
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#191B1E"))
                setOnClickListener {
                    if (i == 0) { showToolbar(); return@setOnClickListener }
                    val ic = currentInputConnection ?: return@setOnClickListener
                    val w = currentWord()
                    ic.deleteSurroundingText(w.length, 0)
                    ic.commitText(text, 1)
                    KbData.recordLearned(this@SourenIME, w, text)
                    refreshStrip()
                }
            }
            suggestView.addView(slot, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.MATCH_PARENT, 1f))
        }
        suggestView.addView(plainIconButton(R.drawable.ic_arrow_back) { showToolbar() },
            LinearLayout.LayoutParams(dp(38), dp(38)))
        toolbarView.visibility = View.GONE
        suggestView.visibility = View.VISIBLE
    }

    // ---------------- key model ----------------
    private enum class Kind { CHAR, SHIFT, DELETE, SPACE, ENTER, MODE, BACK, ZWNJ, CUSTOM }

    private data class K(
        val label: String,
        val weight: Float = 1f,
        val kind: Kind = Kind.CHAR,
        val iconRes: Int = 0
    )

    /** What the shift layer shows for a Persian key (diacritics on the
     *  top row, hamza/Arabic forms elsewhere) — Samsung/ISIRI style. */
    private val faShift = mapOf(
        "ض" to "ً", "ص" to "ٌ", "ث" to "ٍ", "ق" to "َ", "ف" to "ُ",
        "غ" to "ِ", "ع" to "ّ", "ه" to "ة", "خ" to "ْ", "ح" to "ٰ",
        "ج" to "ٔ", "چ" to "ٓ", "ش" to "ـ", "ا" to "آ", "ی" to "ئ",
        "ک" to "ك", "و" to "ؤ"
    )

    /** Extra long-press relatives per Persian key (beyond the shift form). */
    private val faAlts = mapOf(
        "ا" to listOf("أ", "إ", "ٱ", "ء"),
        "و" to listOf("ؤ"),
        "ی" to listOf("ي", "ى"),
        "ک" to listOf("ك"),
        "ه" to listOf("ۀ", "ھ"),
        "گ" to listOf("ڧ"),
        "ر" to listOf("ڑ"),
        "ز" to listOf("ژ")
    )

    private val enAlts = mapOf(
        "a" to listOf("à", "á", "â", "ä", "æ", "ã", "å", "ā"),
        "c" to listOf("ç", "ć", "č"),
        "e" to listOf("è", "é", "ê", "ë", "ē"),
        "i" to listOf("ì", "í", "î", "ï", "ī", "ı"),
        "n" to listOf("ñ", "ń"),
        "o" to listOf("ò", "ó", "ô", "ö", "ø", "õ", "ō"),
        "s" to listOf("ß", "ś", "š", "${'$'}"),
        "u" to listOf("ù", "ú", "û", "ü", "ū"),
        "y" to listOf("ý", "ÿ"),
        "z" to listOf("ž", "ź", "ż"),
        "l" to listOf("ł"), "d" to listOf("đ"),
        "g" to listOf("ğ"), "r" to listOf("ŕ"), "t" to listOf("ť")
    )

    private val quickSymbols = listOf("ً", "ٌ", "ٍ", "َ", "ُ", "ِ", "ّ", "ْ", "ـ", "؟")
    private val customPopupSymbols = listOf(
        "،", "؛", "؟", "!", "«", "»", "(", ")", ":", "…", "@", "#", "&", "/", "٫", "٪"
    )
    private val customPopupSymbolsEn = listOf(
        ",", ";", "?", "!", "(", ")", ":", "...", "@", "#", "&", "/", ".", "%", "'", "\""
    )

    private fun rowsFor(p: Page): List<List<K>> = when (p) {
        Page.FA -> listOf(
            "۱۲۳۴۵۶۷۸۹۰".map { K(it.toString()) },
            listOf("ض", "ص", "ث", "ق", "ف", "غ", "ع", "ه", "خ", "ح", "ج", "چ").map { K(it) },
            listOf("ش", "س", "ی", "ب", "ل", "ا", "ت", "ن", "م", "ک", "گ").map { K(it) },
            listOf(K("", kind = Kind.SHIFT, iconRes = R.drawable.ic_shift, weight = 1.5f)) +
                listOf("ظ", "ط", "ز", "ژ", "ر", "ذ", "د", "پ", "و").map { K(it) } +
                listOf(K("", kind = Kind.DELETE, iconRes = R.drawable.ic_backspace, weight = 1.5f)),
            listOf(
                K("!#1", kind = Kind.MODE, weight = 1.4f),
                K("", kind = Kind.MODE, iconRes = R.drawable.ic_globe, weight = 1.1f),
                K("،", kind = Kind.CUSTOM, weight = 1.0f),
                K("فارسی", kind = Kind.SPACE, weight = 3.6f),
                K("◀┆▶", kind = Kind.ZWNJ, weight = 1.2f),
                K("."),
                K("", kind = Kind.ENTER, iconRes = R.drawable.ic_enter, weight = 1.4f)
            )
        )
        Page.EN -> listOf(
            "1234567890".map { K(it.toString()) },
            "qwertyuiop".map { K(it.toString()) },
            "asdfghjkl".map { K(it.toString()) },
            listOf(K("", kind = Kind.SHIFT, iconRes = R.drawable.ic_shift, weight = 1.5f)) +
                "zxcvbnm".map { K(it.toString()) } +
                listOf(K("", kind = Kind.DELETE, iconRes = R.drawable.ic_backspace, weight = 1.5f)),
            listOf(
                K("!#1", kind = Kind.MODE, weight = 1.4f),
                K("", kind = Kind.MODE, iconRes = R.drawable.ic_globe, weight = 1.1f),
                K(",", kind = Kind.CUSTOM, weight = 1.0f),
                K("English", kind = Kind.SPACE, weight = 3.9f),
                K("."),
                K("", kind = Kind.ENTER, iconRes = R.drawable.ic_enter, weight = 1.4f)
            )
        )
        Page.SYMBOLS -> listOf(
            (if (lastLang == Page.FA) "۱۲۳۴۵۶۷۸۹۰" else "1234567890").map { K(it.toString()) },
            listOf("@", "#", "﷼", "&", "*", "(", ")", "-", "+").map { K(it) },
            listOf("=", "/", "_", ":", "؛", "،", ".", "؟", "!").map { K(it) },
            listOf("\"", "'", "«", "»", "[", "]", "{", "}", "<", ">").map { K(it) },
            listOf(
                K("=<", kind = Kind.MODE, weight = 1.5f),
                K(if (lastLang == Page.FA) "اب" else "ABC", kind = Kind.BACK, weight = 1.5f),
                K(if (lastLang == Page.FA) "فارسی" else "English", kind = Kind.SPACE, weight = 3.4f),
                K("", kind = Kind.DELETE, iconRes = R.drawable.ic_backspace, weight = 1.4f),
                K("", kind = Kind.ENTER, iconRes = R.drawable.ic_enter, weight = 1.4f)
            )
        )
        Page.SYMBOLS2 -> listOf(
            listOf("﷽", "ﷲ", "ﷺ", "ﷻ", "﷼", "ـ", "ٰ", "٭", "۩").map { K(it) },
            listOf("ً", "ٌ", "ٍ", "َ", "ُ", "ِ", "ّ", "ْ", "ٓ", "ٔ").map { K(it) },
            listOf("^", "~", "`", "|", "\\", "•", "…", "÷", "×", "±").map { K(it) },
            listOf("≠", "≈", "∞", "π", "√", "§", "¶", "©", "®", "™").map { K(it) },
            listOf(
                K("1/2", kind = Kind.MODE, weight = 1.5f),
                K(if (lastLang == Page.FA) "اب" else "ABC", kind = Kind.BACK, weight = 1.5f),
                K("€", weight = 1f), K("${'$'}", weight = 1f),
                K("", kind = Kind.DELETE, iconRes = R.drawable.ic_backspace, weight = 1.4f),
                K("", kind = Kind.ENTER, iconRes = R.drawable.ic_enter, weight = 1.4f)
            )
        )
        else -> emptyList()
    }

    // ---------------- key views ----------------
    private class KeyView(
        val frame: FrameLayout,
        val k: K,
        val labelTv: TextView?,
        val iconIv: ImageView?
    )
    private val keyViews = mutableListOf<KeyView>()

    private fun rebuildKeys() {
        keyViews.clear()
        keysBox.removeAllViews()
        stripArea.visibility =
            if (page == Page.FA || page == Page.EN) View.VISIBLE else View.GONE
        when (page) {
            Page.CLIPBOARD -> { keysBox.addView(buildClipboardPanel()); return }
            Page.EMOJI -> { keysBox.addView(buildEmojiPanel()); return }
            else -> Unit
        }
        for (row in rowsFor(page)) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(3), 0, dp(3))
            }
            for (k in row) rowLayout.addView(makeKey(k))
            keysBox.addView(rowLayout)
        }
        applyShiftLabels()
    }

    private fun isGrayKey(k: K): Boolean = when (k.kind) {
        Kind.SHIFT, Kind.DELETE, Kind.ENTER, Kind.MODE -> true
        else -> false
    }

    private fun customSym(): String = KbData.customSymbol(this, page != Page.EN)

    private fun displayLabel(k: K): String {
        if (k.kind == Kind.CUSTOM) return customSym()
        if (page == Page.FA && shifted) faShift[k.label]?.let { return it }
        if (page == Page.EN && (shifted || capsLock) && k.kind == Kind.CHAR &&
            k.label.length == 1 && k.label[0].isLetter()
        ) return k.label.uppercase()
        return k.label
    }

    private fun hintFor(k: K): String? {
        if (page != Page.FA || shifted || k.kind != Kind.CHAR) return null
        return faShift[k.label] ?: faAlts[k.label]?.firstOrNull()
    }

    private fun makeKey(k: K): View {
        val frame = FrameLayout(this).apply {
            setBackgroundResource(
                if (isGrayKey(k)) R.drawable.key_special else R.drawable.key_letter)
            val lp = LinearLayout.LayoutParams(0, rowHeight(), k.weight)
            lp.marginStart = dp(3); lp.marginEnd = dp(3)
            layoutParams = lp
        }
        val effectiveIcon = if (k.iconRes != 0) k.iconRes else 0
        var labelTv: TextView? = null
        var iconIv: ImageView? = null
        if (effectiveIcon != 0) {
            iconIv = ImageView(this).apply {
                setImageResource(effectiveIcon)
                scaleType = ImageView.ScaleType.CENTER_INSIDE
                setPadding(dp(11), dp(11), dp(11), dp(11))
            }
            frame.addView(iconIv, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
        } else {
            labelTv = TextView(this).apply {
                text = displayLabel(k)
                textSize = when {
                    k.kind == Kind.SPACE -> 15f
                    k.kind == Kind.ZWNJ -> 13f
                    k.label.length == 1 && k.label[0].isDigit() -> 16.5f
                    k.kind == Kind.MODE -> 15f
                    k.label.length > 2 -> 15f
                    else -> 19.5f
                }
                if (k.kind == Kind.MODE) paint.isFakeBoldText = true
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor(
                    if (k.kind == Kind.SPACE) "#3C4043" else "#191B1E"))
            }
            frame.addView(labelTv, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT))
            val hint = hintFor(k)
            if (hint != null) {
                val alt = TextView(this).apply {
                    text = hint
                    textSize = 9.5f
                    setTextColor(Color.parseColor("#A3A8AE"))
                    setPadding(dp(6), dp(3), 0, 0)
                    tag = "hint"
                }
                frame.addView(alt, FrameLayout.LayoutParams(
                    ViewGroup.LayoutParams.WRAP_CONTENT,
                    ViewGroup.LayoutParams.WRAP_CONTENT, Gravity.TOP or Gravity.START))
            }
        }
        val kv = KeyView(frame, k, labelTv, iconIv)
        keyViews.add(kv)
        attachBehavior(kv)
        return frame
    }

    /** Shift changes labels in place — no view rebuild (the lag fix). */
    private fun applyShiftLabels() {
        for (kv in keyViews) {
            kv.labelTv?.let { it.text = displayLabel(kv.k) }
            if (kv.k.kind == Kind.SHIFT) {
                kv.iconIv?.setColorFilter(
                    if (shifted || capsLock) Color.parseColor("#2F5FE8") else Color.TRANSPARENT)
                if (shifted || capsLock) kv.iconIv?.alpha = 1f else kv.iconIv?.alpha = 0.85f
            }
            // hint visibility follows the shift layer
            val frame = kv.frame
            for (i in 0 until frame.childCount) {
                val child = frame.getChildAt(i)
                if (child.tag == "hint") child.visibility =
                    if (shifted) View.GONE else View.VISIBLE
            }
        }
    }

    // ---------------- popup options ----------------
    /** (display, value) pairs; index 0 is the pre-selected default. */
    private fun popupOptions(k: K): List<Pair<String, String>> {
        val out = mutableListOf<Pair<String, String>>()
        fun add(v: String) { if (v != k.label && out.none { it.second == v }) out.add(v to v) }
        when {
            k.kind == Kind.CUSTOM ->
                (if (page == Page.EN) customPopupSymbolsEn else customPopupSymbols)
                    .forEach { add(it) }
            k.kind == Kind.ZWNJ -> {
                out.add("نیم‌فاصله" to Corrector.ZWNJ)
                out.add("چسبان" to "\u200D")
            }
            k.label == "." -> quickSymbols.forEach { add(it) }
            page == Page.FA && k.kind == Kind.CHAR -> {
                faShift[k.label]?.let { add(it) }
                faAlts[k.label]?.forEach { add(it) }
                // Persian digits <-> Latin digits, like Samsung.
                val persianDigits = "۱۲۳۴۵۶۷۸۹۰"
                val idx = persianDigits.indexOf(k.label)
                if (idx >= 0) add(idx.toString())
            }
            page == Page.EN && k.kind == Kind.CHAR ->
                enAlts[k.label.lowercase()]?.forEach { add(it) }
        }
        return out
    }

    // ---------------- touch machine (tap / hold-popup / space gestures) ----------------
    private var activeKv: KeyView? = null
    private var longFired = false
    private var consumed = false
    private var popupShown = false
    private var popupOpts: List<Pair<String, String>> = emptyList()
    private var popupIndex = 0
    private var popupLeftPx = 0
    private var popupCellW = 1
    private var downX = 0f
    private var downY = 0f
    private var spaceAnchorX = 0f
    private var cursorMode = false
    private var cursorAccum = 0f
    private var longRunnable: Runnable? = null

    private fun attachBehavior(kv: KeyView) {
        val k = kv.k
        when (k.kind) {
            Kind.DELETE -> {
                kv.frame.setOnClickListener { deleteOnce() }
                kv.frame.setOnLongClickListener { startDeleteRepeat(); true }
                kv.frame.setOnTouchListener { _, ev ->
                    if (ev.action == MotionEvent.ACTION_UP ||
                        ev.action == MotionEvent.ACTION_CANCEL) stopDeleteRepeat()
                    false
                }
            }
            Kind.SHIFT -> {
                kv.frame.setOnClickListener { onShiftTap() }
                kv.frame.setOnLongClickListener {
                    capsLock = true; shifted = true; applyShiftLabels(); true
                }
            }
            Kind.ENTER -> kv.frame.setOnClickListener { onEnter() }
            else -> kv.frame.setOnTouchListener { v, ev -> onKeyTouch(kv, v, ev) }
        }
    }

    private fun onShiftTap() {
        if (capsLock) {
            capsLock = false; shifted = false
        } else {
            shifted = !shifted
        }
        applyShiftLabels()
    }

    private fun onKeyTouch(kv: KeyView, v: View, ev: MotionEvent): Boolean {
        val k = kv.k
        when (ev.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                // A second finger landing: finish the previous key as a tap.
                if (activeKv != null && activeKv !== kv && !popupShown) finishAsTap()
                activeKv = kv
                longFired = false; consumed = false; popupShown = false
                cursorMode = false; cursorAccum = 0f
                downX = ev.rawX; downY = ev.rawY; spaceAnchorX = ev.rawX
                if (k.kind == Kind.CHAR && displayLabel(k).length == 1) showPreview(v, displayLabel(k))
                longRunnable = Runnable { onLongPress(kv) }
                handler.postDelayed(longRunnable!!, 380)
                return true
            }
            MotionEvent.ACTION_MOVE -> {
                if (popupShown) {
                    val idx = ((ev.rawX - popupLeftPx) / popupCellW)
                        .toInt().coerceIn(0, popupOpts.size - 1)
                    if (idx != popupIndex) { popupIndex = idx; paintPopup() }
                } else if (k.kind == Kind.SPACE && activeKv === kv) {
                    if (cursorMode) {
                        cursorAccum += ev.rawX - spaceAnchorX
                        spaceAnchorX = ev.rawX
                        val step = dp(13).toFloat()
                        while (cursorAccum >= step) { moveCursor(1); cursorAccum -= step }
                        while (cursorAccum <= -step) { moveCursor(-1); cursorAccum += step }
                    } else {
                        val dx = ev.rawX - spaceAnchorX
                        if (dx > dp(42)) { switchLang(); spaceAnchorX = ev.rawX }
                        else if (dx < -dp(42)) { switchLang(); spaceAnchorX = ev.rawX }
                    }
                }
                return true
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                handler.removeCallbacks(longRunnable ?: Runnable {})
                preview.visibility = View.GONE
                val wasPopup = popupShown
                val wasConsumed = consumed
                val wasCursor = cursorMode
                val wasSpaceGesture = k.kind == Kind.SPACE &&
                    (kotlin.math.abs(ev.rawX - downX) > dp(42) || wasCursor)
                if (popupShown) {
                    hidePopup()
                    commitPopupChoice()
                }
                val act = activeKv
                activeKv = null
                popupShown = false; consumed = false; cursorMode = false
                if (!wasPopup && !wasConsumed && !wasSpaceGesture && act === kv) doTap(k)
                return true
            }
        }
        return true
    }

    private fun finishAsTap() {
        handler.removeCallbacks(longRunnable ?: Runnable {})
        val kv = activeKv ?: return
        activeKv = null
        if (!consumed) doTap(kv.k)
        consumed = false
    }

    private fun onLongPress(kv: KeyView) {
        if (activeKv !== kv) return
        val k = kv.k
        longFired = true
        preview.visibility = View.GONE
        when {
            k.kind == Kind.SPACE -> { cursorMode = true; consumed = false }
            k.kind == Kind.ZWNJ -> {
                currentInputConnection?.commitText("\u200D", 1); consumed = true
            }
            else -> {
                val opts = popupOptions(k)
                if (opts.size == 1) {
                    commitPopupValue(k, opts[0].second); consumed = true
                } else if (opts.size > 1) {
                    popupOpts = opts; popupIndex = 0
                    showPopup(kv.frame, opts)
                    popupShown = true
                }
            }
        }
    }

    private fun doTap(k: K) {
        when (k.kind) {
            Kind.CHAR -> {
                commit(displayLabel(k))
                if (shifted && !capsLock && (page == Page.FA || page == Page.EN)) {
                    shifted = false; applyShiftLabels()
                }
            }
            Kind.CUSTOM -> commit(customSym())
            Kind.ZWNJ -> commit(Corrector.ZWNJ)
            Kind.SPACE -> onSpace()
            Kind.MODE -> {
                page = when {
                    k.label == "!#1" -> Page.SYMBOLS
                    k.label == "=<" -> Page.SYMBOLS2
                    k.label == "1/2" -> Page.SYMBOLS
                    k.iconRes == R.drawable.ic_globe ->
                        if (page == Page.EN) Page.FA else Page.EN
                    else -> page
                }
                if (page == Page.FA || page == Page.EN) lastLang = page
                rebuildKeys()
            }
            Kind.BACK -> { page = lastLang; rebuildKeys() }
            else -> Unit
        }
    }

    private fun switchLang() {
        if (page != Page.FA && page != Page.EN) return
        // The rebuild detaches the space key mid-gesture; cancel the
        // gesture state so no stale tap fires afterwards.
        handler.removeCallbacks(longRunnable ?: Runnable {})
        activeKv = null
        popupShown = false; consumed = false; cursorMode = false
        emojiSearchOn = false
        page = if (page == Page.FA) Page.EN else Page.FA
        lastLang = page
        shifted = false; capsLock = false
        rebuildKeys()
    }

    // ---------------- popup UI ----------------
    private fun showPopup(anchor: View, opts: List<Pair<String, String>>) {
        popupBar.removeAllViews()
        popupCellW = dp(46)
        for ((display, _) in opts) {
            val cell = TextView(this).apply {
                text = display
                textSize = if (display.length > 2) 13f else 19f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#16181D"))
            }
            popupBar.addView(cell, LinearLayout.LayoutParams(popupCellW, dp(48)))
        }
        paintPopup()
        val rootLoc = IntArray(2); rootFrame.getLocationInWindow(rootLoc)
        val keyLoc = IntArray(2); anchor.getLocationInWindow(keyLoc)
        val totalW = popupCellW * opts.size + dp(10)
        val lp = popupBar.layoutParams as FrameLayout.LayoutParams
        var left = keyLoc[0] - rootLoc[0] + anchor.width / 2 - totalW / 2
        left = left.coerceIn(0, (rootFrame.width - totalW).coerceAtLeast(0))
        lp.leftMargin = left
        lp.topMargin = (keyLoc[1] - rootLoc[1] - dp(64)).coerceAtLeast(0)
        popupBar.layoutParams = lp
        popupLeftPx = rootLoc[0] + left + dp(5)
        popupBar.visibility = View.VISIBLE
    }

    private fun paintPopup() {
        for (i in 0 until popupBar.childCount) {
            val cell = popupBar.getChildAt(i)
            cell.background = if (i == popupIndex) GradientDrawable().apply {
                cornerRadius = dp(10).toFloat()
                setColor(Color.parseColor("#E3E4E7"))
            } else null
        }
    }

    private fun hidePopup() { popupBar.visibility = View.GONE }

    private fun commitPopupChoice() {
        val kv = activeKv ?: return
        val value = popupOpts.getOrNull(popupIndex)?.second ?: return
        commitPopupValue(kv.k, value)
    }

    private fun commitPopupValue(k: K, value: String) {
        if (k.kind == Kind.CUSTOM) {
            KbData.setCustomSymbol(this, page != Page.EN, value)
            applyShiftLabels()
            commit(value)
        } else {
            commit(value)
        }
        if (shifted && !capsLock) { shifted = false; applyShiftLabels() }
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
            setOnClickListener { page = lastLang; rebuildKeys() }
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
                    cornerRadius = dp(12).toFloat()
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
                page = lastLang
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

    // ---------------- emoji panel ----------------
    private var emojiCat = -1 // -1 = recents
    private var emojiSearchOn = false
    private var emojiQuery = ""

    private fun emojiCell(emoji: String): TextView {
        return TextView(this).apply {
            text = emoji
            textSize = 25f
            gravity = Gravity.CENTER
            setOnClickListener {
                hidePopup()
                currentInputConnection?.commitText(emoji, 1)
                KbData.recordEmoji(this@SourenIME, emoji)
            }
            setOnLongClickListener {
                if (emoji in EmojiData.toneSet) {
                    val options = listOf(emoji) + EmojiData.tones.map { emoji + it }
                    showClickPopup(this, options.map { it to it }) { value ->
                        currentInputConnection?.commitText(value, 1)
                        KbData.recordEmoji(this@SourenIME, value)
                    }
                    true
                } else false
            }
        }
    }

    private var clickPopupCallback: ((String) -> Unit)? = null

    /** Click-to-pick popup (used by the emoji skin-tone picker). */
    private fun showClickPopup(anchor: View, opts: List<Pair<String, String>>,
                               onPick: (String) -> Unit) {
        clickPopupCallback = onPick
        popupBar.removeAllViews()
        popupCellW = dp(46)
        for ((display, value) in opts) {
            val cell = TextView(this).apply {
                text = display
                textSize = 20f
                gravity = Gravity.CENTER
                setTextColor(Color.parseColor("#16181D"))
                setOnClickListener {
                    hidePopup()
                    clickPopupCallback?.invoke(value)
                }
            }
            popupBar.addView(cell, LinearLayout.LayoutParams(popupCellW, dp(48)))
        }
        val rootLoc = IntArray(2); rootFrame.getLocationInWindow(rootLoc)
        val keyLoc = IntArray(2); anchor.getLocationInWindow(keyLoc)
        val totalW = popupCellW * opts.size + dp(10)
        val lp = popupBar.layoutParams as FrameLayout.LayoutParams
        var left = keyLoc[0] - rootLoc[0] + anchor.width / 2 - totalW / 2
        left = left.coerceIn(0, (rootFrame.width - totalW).coerceAtLeast(0))
        lp.leftMargin = left
        lp.topMargin = (keyLoc[1] - rootLoc[1] - dp(64)).coerceAtLeast(0)
        popupBar.layoutParams = lp
        popupBar.visibility = View.VISIBLE
    }

    private fun buildEmojiPanel(): View {
        val panel = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(4), dp(4), dp(4), dp(2))
        }
        // Header: search + category tabs + close
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        header.addView(plainIconButton(R.drawable.ic_search) {
            emojiSearchOn = true; emojiQuery = ""; rebuildKeys()
        }, LinearLayout.LayoutParams(dp(40), dp(40)))
        val tabsScroll = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
        }
        val tabs = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val tabDefs = listOf("🕘" to -1) +
            EmojiData.categories.mapIndexed { i, c -> c.icon to i }
        for ((icon, idx) in tabDefs) {
            val selected = emojiCat == idx
            val tv = TextView(this).apply {
                text = icon
                textSize = 20f
                gravity = Gravity.CENTER
                setPadding(dp(9), dp(5), dp(9), dp(5))
                if (selected) background = GradientDrawable().apply {
                    cornerRadius = dp(12).toFloat()
                    setColor(Color.parseColor("#C9CCD1"))
                }
                setOnClickListener { emojiCat = idx; rebuildKeys() }
            }
            tabs.addView(tv)
        }
        tabsScroll.addView(tabs)
        header.addView(tabsScroll, LinearLayout.LayoutParams(0, dp(44), 1f))
        val close = TextView(this).apply {
            text = "بستن"
            textSize = 13.5f
            setTextColor(Color.parseColor("#16181D"))
            setPadding(dp(10), dp(6), dp(10), dp(6))
            setOnClickListener { page = lastLang; rebuildKeys() }
        }
        header.addView(close)
        panel.addView(header)

        val items = if (emojiCat == -1) {
            KbData.emojiRecents(this).ifEmpty {
                EmojiData.categories[0].items.take(24)
            }
        } else EmojiData.categories[emojiCat].items
        val scroll = ScrollView(this)
        val grid = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        for (chunk in items.chunked(8)) {
            val rowL = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            for (e in chunk) {
                rowL.addView(emojiCell(e),
                    LinearLayout.LayoutParams(0, dp(50), 1f))
            }
            for (i in chunk.size until 8) {
                rowL.addView(View(this), LinearLayout.LayoutParams(0, dp(50), 1f))
            }
            grid.addView(rowL)
        }
        scroll.addView(grid)
        panel.addView(scroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(212)))

        // Bottom row: back to letters / space / delete
        val bottom = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            setPadding(0, dp(3), 0, dp(3))
        }
        bottom.addView(makeKey(K(if (lastLang == Page.FA) "اب" else "ABC",
            kind = Kind.BACK, weight = 1.6f)))
        bottom.addView(makeKey(K(if (lastLang == Page.FA) "فارسی" else "English",
            kind = Kind.SPACE, weight = 4f)))
        bottom.addView(makeKey(K("", kind = Kind.DELETE,
            iconRes = R.drawable.ic_backspace, weight = 1.5f)))
        panel.addView(bottom)
        return panel
    }

    private fun buildEmojiSearch(): View {
        val panel = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val bar = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor("#F7F7F8"))
            setPadding(dp(12), 0, dp(12), 0)
        }
        val q = TextView(this).apply {
            text = if (emojiQuery.isEmpty()) "جست‌وجوی ایموجی… (مثل: گربه، خنده، قلب)"
                   else "جست‌وجو: $emojiQuery"
            textSize = 14.5f
            setTextColor(Color.parseColor("#191B1E"))
        }
        bar.addView(q, LinearLayout.LayoutParams(0, dp(42), 1f))
        val cancel = TextView(this).apply {
            text = "لغو"
            textSize = 13.5f
            setTextColor(Color.parseColor("#8A2F2F"))
            setPadding(dp(8), dp(6), dp(8), dp(6))
            setOnClickListener { emojiSearchOn = false; rebuildKeys() }
        }
        bar.addView(cancel)
        panel.addView(bar)

        val results = EmojiData.search(emojiQuery)
        val scroll = ScrollView(this)
        val grid = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        if (results.isEmpty()) {
            grid.addView(TextView(this).apply {
                text = if (emojiQuery.isEmpty()) ""
                       else "چیزی پیدا نشد؛ واژهٔ دیگری بنویسید."
                textSize = 13.5f
                setTextColor(Color.parseColor("#6E6E6E"))
                setPadding(dp(12), dp(10), dp(12), dp(10))
            })
        }
        for (chunk in results.chunked(8)) {
            val rowL = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            for (e in chunk) {
                rowL.addView(emojiCell(e), LinearLayout.LayoutParams(0, dp(44), 1f))
            }
            for (i in chunk.size until 8) {
                rowL.addView(View(this), LinearLayout.LayoutParams(0, dp(44), 1f))
            }
            grid.addView(rowL)
        }
        scroll.addView(grid)
        panel.addView(scroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(96)))
        for (row in rowsFor(lastLang)) {
            val rowLayout = LinearLayout(this).apply {
                orientation = LinearLayout.HORIZONTAL
                setPadding(0, dp(3), 0, dp(3))
            }
            for (k in row) rowLayout.addView(makeKey(k))
            panel.addView(rowLayout)
        }
        applyShiftLabels()
        return panel
    }

    // ---------------- editing ----------------
    private fun commit(text: String) {
        if (page == Page.EMOJI && emojiSearchOn) {
            if (text.length == 1 && text != " ") {
                emojiQuery += text
                rebuildKeys()
            }
            return
        }
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
        if (word == lastWordShown && suggestView.visibility == View.VISIBLE) return
        if (word.length < 2 || page != Page.FA) {
            lastWordShown = word
            showToolbar(); return
        }
        val suggestions = Corrector.suggestionsFor(
            word, KbData.dictionary, KbData.learnedCounts, KbData.vocab)
        lastWordShown = word
        if (suggestions.isEmpty()) showToolbar()
        else showSuggestions(suggestions, word)
    }

    private fun onSpace() {
        if (page == Page.EMOJI && emojiSearchOn) return
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
        lastWordShown = ""
        showToolbar()
    }

    private fun onEnter() {
        if (page == Page.EMOJI && emojiSearchOn) {
            emojiSearchOn = false; rebuildKeys(); return
        }
        val ic = currentInputConnection ?: return
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
        lastWordShown = ""
    }

    private fun deleteOnce() {
        if (page == Page.EMOJI && emojiSearchOn) {
            if (emojiQuery.isNotEmpty()) {
                emojiQuery = emojiQuery.dropLast(1)
                rebuildKeys()
            }
            return
        }
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
}
