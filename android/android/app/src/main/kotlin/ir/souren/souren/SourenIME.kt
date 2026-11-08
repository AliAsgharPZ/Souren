package ir.souren.souren

import android.content.Intent
import android.content.ClipboardManager
import android.content.res.Configuration
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
import android.widget.PopupWindow
import android.widget.ScrollView
import android.widget.TextView
import kotlin.math.abs
import kotlin.math.roundToInt

/**
 * Souren Keyboard — rebuilt as a native Samsung One UI–inspired IME.
 *
 * The visual system is deliberately based on Samsung Keyboard's hierarchy:
 * compact toolbar/suggestion rail, a dedicated number row, square-soft keys,
 * restrained elevation, cool neutral surfaces, and high-contrast action keys.
 * All input is committed through Android's InputConnection; no Flutter view
 * is embedded in the IME.
 */
class SourenIME : InputMethodService() {

    private enum class Page { FA, EN, SYMBOLS, EMOJI, CLIPBOARD }
    private enum class Action { CHAR, SHIFT, DELETE, SPACE, ENTER, SYMBOLS, EMOJI, LANGUAGE, ZWNJ, CLIPBOARD, BACK }

    private data class KeySpec(
        val label: String,
        val action: Action = Action.CHAR,
        val weight: Float = 1f,
        val icon: Int = 0
    )

    private var page = Page.FA
    private var lastLanguage = Page.FA
    private var shifted = false
    private var capsLock = false
    private var appliedHeight = ""
    private var emojiCategory = -1
    private var customSymbol = "،"
    private var topArea: LinearLayout? = null
    private var keyArea: LinearLayout? = null
    private var root: FrameLayout? = null
    private var popup: PopupWindow? = null
    private var popupCells = mutableListOf<TextView>()
    private var popupValues = emptyList<String>()
    private var popupSelection = 0
    private val handler = Handler(Looper.getMainLooper())
    private var repeatDelete: Runnable? = null
    private var lastSuggestionWord = ""

    private fun dp(value: Int): Int =
        (value * resources.displayMetrics.density).roundToInt()

    private val dark: Boolean
        get() = (resources.configuration.uiMode and Configuration.UI_MODE_NIGHT_MASK) ==
            Configuration.UI_MODE_NIGHT_YES

    private fun color(light: String, night: String): Int =
        Color.parseColor(if (dark) night else light)

    private val surface get() = color("#DDE1E8", "#17191E")
    private val keySurface get() = color("#FFFFFF", "#30343B")
    private val specialSurface get() = color("#C7CDD6", "#444A54")
    private val ink get() = color("#20242B", "#F2F4F7")
    private val mutedInk get() = color("#59616D", "#C0C6D0")
    private val accent get() = color("#3974C6", "#8AB4F8")

    private fun keyHeight(): Int = when (KbData.kbHeight) {
        "short" -> dp(42)
        "normal" -> dp(46)
        else -> dp(49)
    }

    override fun onStartInput(info: EditorInfo?, restarting: Boolean) {
        super.onStartInput(info, restarting)
        KbData.load(this)
        KbData.readSettings(this)
        KbData.readLearned(this)
        customSymbol = KbData.customSymbol(this, page == Page.FA)
    }

    override fun onStartInputView(info: EditorInfo, restarting: Boolean) {
        super.onStartInputView(info, restarting)
        KbData.readSettings(this)
        KbData.readLearned(this)
        if (KbData.kbHeight != appliedHeight) {
            appliedHeight = KbData.kbHeight
            rebuildKeyboard()
        } else {
            refreshSuggestions()
        }
    }

    override fun onFinishInputView(finishingInput: Boolean) {
        stopDeleteRepeat()
        dismissPopup()
        super.onFinishInputView(finishingInput)
    }

    override fun onCreateInputView(): View {
        val frame = FrameLayout(this).apply {
            setBackgroundColor(surface)
            clipChildren = false
            clipToPadding = false
        }
        root = frame
        val shell = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(surface)
            setPadding(dp(4), dp(2), dp(4), dp(9))
        }
        frame.addView(shell, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ))

        topArea = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setPadding(dp(3), 0, dp(3), 0)
        }
        shell.addView(topArea, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(45)
        ))

        keyArea = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(0, dp(1), 0, 0)
        }
        shell.addView(keyArea, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ))
        appliedHeight = KbData.kbHeight
        renderToolbar()
        rebuildKeyboard()
        return frame
    }

    // ── Top toolbar and live suggestions ────────────────────────────────────

    private fun toolbarButton(icon: Int, label: String, action: () -> Unit): View {
        val box = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(7), dp(3), dp(7), dp(2))
            background = rounded(specialSurface, 14, 0)
            setOnClickListener { action() }
        }
        val image = ImageView(this).apply {
            setImageResource(icon)
            setColorFilter(mutedInk)
            scaleType = ImageView.ScaleType.CENTER_INSIDE
        }
        box.addView(image, LinearLayout.LayoutParams(dp(21), dp(21)))
        box.addView(TextView(this).apply {
            text = label
            textSize = 9f
            setTextColor(mutedInk)
            gravity = Gravity.CENTER
        })
        box.setOnTouchListener { v, event ->
            pressFeedback(v, event)
            false
        }
        return box
    }

    private fun renderToolbar() {
        val bar = topArea ?: return
        bar.removeAllViews()
        bar.addView(toolbarButton(R.drawable.ic_more, "بیشتر") {
            lastLanguage = page
            page = Page.SYMBOLS
            rebuildKeyboard()
        })
        addSpacer(bar)
        bar.addView(toolbarButton(R.drawable.ic_clipboard, "کلیپ‌بورد") {
            lastLanguage = page
            page = Page.CLIPBOARD
            rebuildKeyboard()
        })
        addSpacer(bar)
        bar.addView(toolbarButton(R.drawable.ic_emoji, "ایموجی") {
            lastLanguage = page
            page = Page.EMOJI
            rebuildKeyboard()
        })
        addSpacer(bar)
        bar.addView(toolbarButton(R.drawable.ic_keyboard, "زبان") {
            switchLanguage()
        })
        addSpacer(bar)
        bar.addView(toolbarButton(R.drawable.ic_gear, "تنظیمات") {
            openApp()
        })
    }

    private fun addSpacer(parent: LinearLayout) {
        parent.addView(View(this), LinearLayout.LayoutParams(0, 1, 1f))
    }

    private fun renderSuggestions(word: String, suggestions: List<String>) {
        val bar = topArea ?: return
        bar.removeAllViews()
        val all = (listOf(word) + suggestions).filter { it.isNotBlank() }.distinct().take(3)
        if (all.isEmpty()) {
            renderToolbar()
            return
        }
        all.forEachIndexed { index, candidate ->
            val slot = TextView(this).apply {
                text = candidate
                textSize = if (index == 0) 14f else 15f
                gravity = Gravity.CENTER
                setTextColor(if (index == 0) mutedInk else ink)
                if (index == 1) paint.isFakeBoldText = true
                setPadding(dp(6), 0, dp(6), 0)
                setOnClickListener { replaceCurrentWord(candidate) }
            }
            bar.addView(slot, LinearLayout.LayoutParams(0, dp(42), 1f))
            if (index != all.lastIndex) {
                bar.addView(View(this).apply {
                    setBackgroundColor(color("#C5CAD2", "#484E58"))
                }, LinearLayout.LayoutParams(dp(1), dp(22)))
            }
        }
        bar.addView(toolbarButton(R.drawable.ic_more, "⋯") { renderToolbar() },
            LinearLayout.LayoutParams(dp(48), dp(42)))
    }

    private fun refreshSuggestions() {
        if (page != Page.FA && page != Page.EN) return
        val word = currentWord()
        if (word.length < 2 || page == Page.EN) {
            lastSuggestionWord = word
            renderToolbar()
            return
        }
        if (word == lastSuggestionWord) return
        lastSuggestionWord = word
        val suggestions = Corrector.suggestionsFor(
            word, KbData.dictionary, KbData.learnedCounts, KbData.vocab
        )
        if (suggestions.isEmpty()) renderToolbar()
        else renderSuggestions(word, suggestions)
    }

    private fun replaceCurrentWord(value: String) {
        val ic = currentInputConnection ?: return
        val old = currentWord()
        if (old.isEmpty()) return
        ic.deleteSurroundingText(old.length, 0)
        ic.commitText(value, 1)
        KbData.recordLearned(this, old, value)
        lastSuggestionWord = ""
        refreshSuggestions()
    }

    // ── Keyboard layout ─────────────────────────────────────────────────────

    private fun rebuildKeyboard() {
        val area = keyArea ?: return
        dismissPopup()
        area.removeAllViews()
        when (page) {
            Page.FA, Page.EN -> buildLetters(area)
            Page.SYMBOLS -> buildSymbols(area)
            Page.EMOJI -> buildEmoji(area)
            Page.CLIPBOARD -> buildClipboard(area)
        }
    }

    private fun buildLetters(area: LinearLayout) {
        val numberRow = if (page == Page.FA) "۱۲۳۴۵۶۷۸۹۰" else "1234567890"
        addRow(area, numberRow.map { KeySpec(it.toString()) }, 0.72f)

        if (page == Page.FA) {
            addRow(area, "ضصثقفغعهخحجچ".map { KeySpec(it.toString()) })
            addRow(area, "شسیبلاتنمکگ".map { KeySpec(it.toString()) })
            addRow(area,
                listOf(KeySpec("", Action.SHIFT, 1.45f, R.drawable.ic_shift)) +
                    "ظطزژرذدپو".map { KeySpec(it.toString()) } +
                    listOf(KeySpec("", Action.DELETE, 1.45f, R.drawable.ic_backspace))
            )
        } else {
            addRow(area, "qwertyuiop".map { KeySpec(it.toString()) })
            addRow(area, "asdfghjkl".map { KeySpec(it.toString()) })
            addRow(area,
                listOf(KeySpec("", Action.SHIFT, 1.45f, R.drawable.ic_shift)) +
                    "zxcvbnm".map { KeySpec(it.toString()) } +
                    listOf(KeySpec("", Action.DELETE, 1.45f, R.drawable.ic_backspace))
            )
        }

        val bottom = mutableListOf(
            KeySpec("?۱۲۳", Action.SYMBOLS, 1.35f),
            KeySpec("", Action.EMOJI, 1.0f, R.drawable.ic_emoji),
            KeySpec(customSymbol, Action.CHAR, 1.0f),
            KeySpec(if (page == Page.FA) "فارسی" else "English", Action.SPACE, 4.1f),
        )
        if (page == Page.FA) bottom.add(KeySpec("", Action.ZWNJ, 1.25f, R.drawable.ic_half_space))
        bottom.add(KeySpec(".", Action.CHAR, 0.8f))
        bottom.add(KeySpec("", Action.ENTER, 1.35f, R.drawable.ic_enter))
        addRow(area, bottom)
    }

    private fun buildSymbols(area: LinearLayout) {
        val nums = if (lastLanguage == Page.FA) "۱۲۳۴۵۶۷۸۹۰" else "1234567890"
        addRow(area, nums.map { KeySpec(it.toString()) }, 0.72f)
        listOf("@#٪&*()-+".map { KeySpec(it.toString()) },
            "=/_:؛،.؟!".map { KeySpec(it.toString()) },
            listOf("«", "»", "'", "\"", "[", "]", "{", "}", "<", ">").map { KeySpec(it) },
            listOf("﷼", "ـ", "…", "÷", "×", "±", "∞", "√", "©", "®").map { KeySpec(it) }
        ).forEach { addRow(area, it) }
        addRow(area, listOf(
            KeySpec("ABC", Action.BACK, 1.5f),
            KeySpec("", Action.DELETE, 1.4f, R.drawable.ic_backspace),
            KeySpec("فاصله", Action.SPACE, 3.7f),
            KeySpec("", Action.ENTER, 1.4f, R.drawable.ic_enter)
        ))
    }

    private fun addRow(area: LinearLayout, keys: List<KeySpec>, topGap: Float = 0.0f) {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(0, dp(if (topGap > 0) 2 else 3), 0, dp(3))
        }
        keys.forEach { spec ->
            row.addView(createKey(spec), LinearLayout.LayoutParams(
                0, keyHeight(), spec.weight
            ).apply {
                marginStart = dp(2)
                marginEnd = dp(2)
            })
        }
        area.addView(row)
    }

    private fun createKey(spec: KeySpec): View {
        val frame = FrameLayout(this).apply {
            val keyColor = when {
                spec.action == Action.ENTER -> accent
                spec.action in listOf(Action.SHIFT, Action.DELETE, Action.SYMBOLS,
                    Action.EMOJI, Action.LANGUAGE, Action.ZWNJ, Action.CLIPBOARD) -> specialSurface
                else -> keySurface
            }
            background = rounded(
                keyColor,
                if (spec.action == Action.SPACE) 8 else 7,
                if (spec.action == Action.ENTER) dp(2) else dp(1)
            )
            elevation = if (spec.action == Action.SPACE) dp(1).toFloat() else dp(2).toFloat()
            isClickable = true
            isFocusable = true
        }
        if (spec.icon != 0) {
            frame.addView(ImageView(this).apply {
                setImageResource(spec.icon)
                setColorFilter(if (spec.action == Action.ENTER) color("#FFFFFF", "#FFFFFF") else ink)
                scaleType = ImageView.ScaleType.CENTER_INSIDE
                setPadding(dp(11), dp(11), dp(11), dp(11))
            }, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
        } else {
            val label = if (shifted && page == Page.EN &&
                spec.action == Action.CHAR && spec.label.length == 1)
                spec.label.uppercase() else spec.label
            frame.addView(TextView(this).apply {
                text = label
                gravity = Gravity.CENTER
                textSize = when {
                    spec.action == Action.SPACE -> 13f
                    spec.action == Action.ZWNJ -> 10f
                    spec.label.length > 3 -> 11.5f
                    spec.label.length == 1 && spec.label[0].isDigit() -> 17f
                    else -> 19f
                }
                setTextColor(if (spec.action == Action.ENTER) Color.WHITE else ink)
                if (spec.action == Action.ENTER || spec.action == Action.SYMBOLS)
                    paint.isFakeBoldText = true
            }, FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            ))
        }
        attachKeyTouch(frame, spec)
        return frame
    }

    private fun rounded(fill: Int, radius: Int, stroke: Int): GradientDrawable =
        GradientDrawable().apply {
            setColor(fill)
            cornerRadius = dp(radius).toFloat()
            if (stroke > 0) setStroke(dp(1), color("#D5DAE2", "#4A505A"))
        }

    private fun pressFeedback(view: View, event: MotionEvent) {
        when (event.actionMasked) {
            MotionEvent.ACTION_DOWN -> {
                view.animate().scaleX(0.96f).scaleY(0.94f).alpha(0.92f)
                    .setDuration(65).start()
            }
            MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> {
                view.animate().scaleX(1f).scaleY(1f).alpha(1f)
                    .setDuration(115).start()
            }
        }
    }

    // ── Touch, long-press alternatives, language swipe and cursor pad ────────

    private fun alternativesFor(label: String): List<String> {
        val map = mapOf(
            "ا" to listOf("آ", "أ", "إ", "ٱ"),
            "و" to listOf("ؤ", "ۥ"),
            "ی" to listOf("ئ", "ي"),
            "ک" to listOf("ك", "ڪ"),
            "ه" to listOf("ۀ", "ة", "ھ"),
            "س" to listOf("ص", "ث"),
            "ز" to listOf("ذ", "ض", "ظ"),
            "ر" to listOf("ڑ", "ڕ"),
            "." to listOf("؟", "!", "…", "؛", ":"),
            "," to listOf("،", ";", "؛", "؟"),
            "،" to listOf("؛", "؟", ".", "…"),
        )
        return map[label] ?: emptyList()
    }

    private fun attachKeyTouch(view: View, spec: KeySpec) {
        var downX = 0f
        var lastX = 0f
        var longTriggered = false
        var cursorMode = false
        var popupValuesLocal = emptyList<String>()
        var selected = 0
        var longRunnable: Runnable? = null

        view.setOnTouchListener { v, event ->
            when (event.actionMasked) {
                MotionEvent.ACTION_DOWN -> {
                    downX = event.rawX
                    lastX = event.rawX
                    longTriggered = false
                    cursorMode = false
                    pressFeedback(v, event)
                    val options = if (spec.action == Action.CHAR) alternativesFor(spec.label)
                        else emptyList()
                    if (options.isNotEmpty()) {
                        longRunnable = Runnable {
                            longTriggered = true
                            popupValuesLocal = listOf(spec.label) + options
                            selected = 0
                            showAlternatives(v, popupValuesLocal)
                        }
                        handler.postDelayed(longRunnable!!, 380)
                    } else if (spec.action == Action.SPACE) {
                        longRunnable = Runnable {
                            longTriggered = true
                            cursorMode = true
                        }
                        handler.postDelayed(longRunnable!!, 430)
                    } else if (spec.action == Action.DELETE) {
                        longRunnable = Runnable {
                            longTriggered = true
                            startDeleteRepeat()
                        }
                        handler.postDelayed(longRunnable!!, 380)
                    } else if (spec.action == Action.SHIFT) {
                        longRunnable = Runnable {
                            longTriggered = true
                            capsLock = !capsLock
                            shifted = capsLock
                        }
                        handler.postDelayed(longRunnable!!, 430)
                    }
                    true
                }
                MotionEvent.ACTION_MOVE -> {
                    if (cursorMode) {
                        val delta = (event.rawX - lastX) / dp(7).toFloat()
                        if (abs(delta) >= 1f) moveCursor(delta.roundToInt())
                        lastX = event.rawX
                    } else if (popupValuesLocal.isNotEmpty() && popup?.isShowing == true) {
                        val loc = IntArray(2)
                        popup?.contentView?.getLocationOnScreen(loc)
                        val cellWidth = dp(44).coerceAtLeast(1)
                        selected = ((event.rawX - loc[0]) / cellWidth)
                            .toInt().coerceIn(0, popupValuesLocal.lastIndex)
                        paintAlternatives(selected)
                    }
                    true
                }
                MotionEvent.ACTION_UP -> {
                    longRunnable?.let { handler.removeCallbacks(it) }
                    pressFeedback(v, event)
                    stopDeleteRepeat()
                    when {
                        popupValuesLocal.isNotEmpty() && popup?.isShowing == true -> {
                            val choice = popupValuesLocal[selected]
                            dismissPopup()
                            if (spec.label == customSymbol && spec.action == Action.CHAR) {
                                customSymbol = choice
                                KbData.setCustomSymbol(this, page == Page.FA, choice)
                            }
                            commit(choice)
                        }
                        cursorMode -> Unit
                        longTriggered -> {
                            if (spec.action == Action.SHIFT) applyShift()
                        }
                        spec.action == Action.SPACE && abs(event.rawX - downX) > dp(48) ->
                            switchLanguage()
                        else -> perform(spec)
                    }
                    true
                }
                MotionEvent.ACTION_CANCEL -> {
                    longRunnable?.let { handler.removeCallbacks(it) }
                    stopDeleteRepeat()
                    dismissPopup()
                    pressFeedback(v, event)
                    true
                }
                else -> false
            }
        }
    }

    private fun showAlternatives(anchor: View, values: List<String>) {
        dismissPopup()
        popupValues = values
        popupSelection = 0
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setPadding(dp(4), dp(4), dp(4), dp(4))
            background = rounded(color("#FFFFFF", "#343941"), 12, dp(1))
            elevation = dp(8).toFloat()
        }
        popupCells.clear()
        values.forEachIndexed { index, value ->
            val cell = TextView(this).apply {
                text = value
                textSize = 19f
                gravity = Gravity.CENTER
                setTextColor(ink)
                setBackground(if (index == 0) rounded(color("#DCE8F8", "#3E526E"), 9, 0) else null)
            }
            row.addView(cell, LinearLayout.LayoutParams(dp(44), dp(44)))
            popupCells.add(cell)
        }
        val window = PopupWindow(row,
            dp(44 * values.size + 8), dp(54), false).apply {
            isOutsideTouchable = false
            isTouchable = false
            elevation = dp(8).toFloat()
        }
        popup = window
        val location = IntArray(2)
        anchor.getLocationOnScreen(location)
        val y = (location[1] - dp(62)).coerceAtLeast(0)
        val x = (location[0] + anchor.width / 2 - dp(22 * values.size + 4)).coerceAtLeast(0)
        val parent = root ?: return
        window.showAtLocation(parent, Gravity.TOP or Gravity.START, x, y)
    }

    private fun paintAlternatives(index: Int) {
        popupCells.forEachIndexed { i, cell ->
            cell.background = if (i == index)
                rounded(color("#DCE8F8", "#3E526E"), 9, 0) else null
        }
    }

    private fun dismissPopup() {
        try { popup?.dismiss() } catch (_: Exception) {}
        popup = null
        popupCells.clear()
        popupValues = emptyList()
    }

    private fun perform(spec: KeySpec) {
        when (spec.action) {
            Action.CHAR -> {
                val value = if (shifted && page == Page.EN && spec.label.length == 1)
                    spec.label.uppercase() else spec.label
                commit(value)
                if (shifted && !capsLock) {
                    shifted = false
                    rebuildKeyboard()
                }
            }
            Action.SHIFT -> {
                shifted = !shifted
                if (!shifted) capsLock = false
                applyShift()
            }
            Action.DELETE -> deleteOnce()
            Action.SPACE -> onSpace()
            Action.ENTER -> onEnter()
            Action.SYMBOLS -> {
                lastLanguage = page
                page = Page.SYMBOLS
                rebuildKeyboard()
            }
            Action.EMOJI -> {
                lastLanguage = page
                page = Page.EMOJI
                rebuildKeyboard()
            }
            Action.LANGUAGE -> switchLanguage()
            Action.ZWNJ -> commit("\u200c")
            Action.CLIPBOARD -> {
                page = Page.CLIPBOARD
                rebuildKeyboard()
            }
            Action.BACK -> {
                page = lastLanguage
                rebuildKeyboard()
            }
        }
    }

    private fun applyShift() {
        // The layout is rebuilt only on a deliberate shift action, never on each
        // typed character; ordinary typing keeps the keyboard view tree stable.
        rebuildKeyboard()
    }

    private fun switchLanguage() {
        val current = if (page == Page.FA || page == Page.EN) page else lastLanguage
        page = if (current == Page.FA) Page.EN else Page.FA
        lastLanguage = page
        shifted = false
        capsLock = false
        customSymbol = KbData.customSymbol(this, page == Page.FA)
        renderToolbar()
        rebuildKeyboard()
    }

    // ── Emoji and clipboard panels ──────────────────────────────────────────

    private fun buildEmoji(area: LinearLayout) {
        val header = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
        }
        val tabs = HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
        }
        val tabRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        (listOf("🕘" to -1) + EmojiData.categories.mapIndexed { index, category ->
            category.icon to index
        }).forEach { (icon, index) ->
            val tab = TextView(this).apply {
                text = icon
                textSize = 19f
                gravity = Gravity.CENTER
                setPadding(dp(10), dp(6), dp(10), dp(6))
                if (emojiCategory == index) background =
                    rounded(specialSurface, 10, 0)
                setOnClickListener { emojiCategory = index; rebuildKeyboard() }
            }
            tabRow.addView(tab)
        }
        tabs.addView(tabRow)
        header.addView(tabs, LinearLayout.LayoutParams(0, dp(44), 1f))
        header.addView(TextView(this).apply {
            text = "بستن"
            textSize = 12f
            setTextColor(ink)
            setPadding(dp(10), dp(8), dp(10), dp(8))
            setOnClickListener { page = lastLanguage; renderToolbar(); rebuildKeyboard() }
        })
        area.addView(header)

        val scroll = ScrollView(this)
        val grid = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        val items = if (emojiCategory == -1) KbData.emojiRecents(this).ifEmpty {
            EmojiData.categories.firstOrNull()?.items?.take(24) ?: emptyList()
        } else EmojiData.categories.getOrNull(emojiCategory)?.items ?: emptyList()
        for (chunk in items.chunked(8)) {
            val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
            chunk.forEach { emoji ->
                row.addView(TextView(this).apply {
                    text = emoji
                    textSize = 24f
                    gravity = Gravity.CENTER
                    setOnClickListener {
                        currentInputConnection?.commitText(emoji, 1)
                        KbData.recordEmoji(this@SourenIME, emoji)
                    }
                }, LinearLayout.LayoutParams(0, dp(48), 1f))
            }
            repeat(8 - chunk.size) {
                row.addView(View(this), LinearLayout.LayoutParams(0, dp(48), 1f))
            }
            grid.addView(row)
        }
        scroll.addView(grid)
        area.addView(scroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(206)))
        addRow(area, listOf(
            KeySpec("ABC", Action.BACK, 1.5f),
            KeySpec("فاصله", Action.SPACE, 4f),
            KeySpec("", Action.DELETE, 1.4f, R.drawable.ic_backspace)
        ))
    }

    private fun buildClipboard(area: LinearLayout) {
        val header = TextView(this).apply {
            text = "کلیپ‌بورد"
            textSize = 14f
            setTextColor(ink)
            gravity = Gravity.CENTER_VERTICAL or Gravity.END
            setPadding(dp(12), 0, dp(12), 0)
        }
        area.addView(header, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(38)))
        val clipboard = getSystemService(CLIPBOARD_SERVICE) as? ClipboardManager
        val clipText = clipboard?.primaryClip?.takeIf { it.itemCount > 0 }
            ?.getItemAt(0)?.coerceToText(this)?.toString()
        if (!clipText.isNullOrBlank()) KbData.rememberClipboard(this, clipText)
        val items = KbData.clipboardItems(this)
        val scroll = ScrollView(this)
        val list = LinearLayout(this).apply { orientation = LinearLayout.VERTICAL }
        if (items.isEmpty()) {
            list.addView(TextView(this).apply {
                text = "چیزی در کلیپ‌بورد نیست."
                textSize = 13f
                setTextColor(mutedInk)
                gravity = Gravity.CENTER
                setPadding(dp(10), dp(25), dp(10), dp(25))
            })
        }
        items.forEachIndexed { index, pair ->
            val item = TextView(this).apply {
                text = (if (pair.second) "◆  " else "") + pair.first
                textSize = 13f
                setTextColor(ink)
                gravity = Gravity.CENTER_VERTICAL or Gravity.END
                maxLines = 2
                setPadding(dp(12), dp(10), dp(12), dp(10))
                setOnClickListener {
                    currentInputConnection?.commitText(pair.first, 1)
                    page = lastLanguage
                    renderToolbar()
                    rebuildKeyboard()
                }
                setOnLongClickListener {
                    val updated = items.toMutableList()
                    updated[index] = pair.first to !pair.second
                    KbData.saveClipboardItems(this@SourenIME, updated)
                    rebuildKeyboard()
                    true
                }
            }
            list.addView(item)
            list.addView(View(this).apply {
                setBackgroundColor(color("#C9CFD8", "#414751"))
            }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(1)))
        }
        scroll.addView(list)
        area.addView(scroll, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(210)))
        addRow(area, listOf(
            KeySpec("ABC", Action.BACK, 1.5f),
            KeySpec("فاصله", Action.SPACE, 4f),
            KeySpec("", Action.DELETE, 1.4f, R.drawable.ic_backspace)
        ))
    }

    // ── Text editing ────────────────────────────────────────────────────────

    private fun commit(value: String) {
        currentInputConnection?.commitText(value, 1)
        refreshSuggestions()
    }

    private fun currentWord(): String {
        val before = currentInputConnection?.getTextBeforeCursor(64, 0)?.toString() ?: return ""
        val separators = charArrayOf(' ', '\n', '،', ',', '.', '؟', '!', '؛', ':', '(', ')', '«', '»')
        val index = before.lastIndexOfAny(separators)
        return if (index < 0) before else before.substring(index + 1)
    }

    private fun onSpace() {
        val ic = currentInputConnection ?: return
        if (KbData.autoCorrect && page == Page.FA) {
            val before = ic.getTextBeforeCursor(64, 0)?.toString() ?: ""
            val fix = Corrector.fixBeforeSeparator(
                before, KbData.dictionary, KbData.replaceArabic
            )
            if (fix != null) {
                val from = currentWord()
                ic.deleteSurroundingText(fix.first, 0)
                ic.commitText(fix.second, 1)
                KbData.recordLearned(this, from, fix.second)
            }
        }
        ic.commitText(" ", 1)
        lastSuggestionWord = ""
        renderToolbar()
    }

    private fun onEnter() {
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
            action != EditorInfo.IME_ACTION_UNSPECIFIED) {
            ic.performEditorAction(action)
        } else {
            ic.commitText("\n", 1)
        }
        lastSuggestionWord = ""
        renderToolbar()
    }

    private fun deleteOnce() {
        val ic = currentInputConnection ?: return
        val selected = ic.getSelectedText(0)
        if (selected.isNullOrEmpty()) ic.deleteSurroundingText(1, 0)
        else ic.commitText("", 1)
        lastSuggestionWord = ""
        refreshSuggestions()
    }

    private fun startDeleteRepeat() {
        deleteOnce()
        val runnable = object : Runnable {
            override fun run() {
                deleteOnce()
                handler.postDelayed(this, 55)
            }
        }
        repeatDelete = runnable
        handler.postDelayed(runnable, 350)
    }

    private fun stopDeleteRepeat() {
        repeatDelete?.let { handler.removeCallbacks(it) }
        repeatDelete = null
    }

    private fun moveCursor(delta: Int) {
        val ic = currentInputConnection ?: return
        val before = ic.getTextBeforeCursor(500, 0)?.length ?: return
        val after = ic.getTextAfterCursor(500, 0)?.length ?: 0
        val position = (before + delta).coerceIn(0, before + after)
        ic.setSelection(position, position)
    }

    private fun openApp() {
        startActivity(Intent(this, MainActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        })
    }
}
