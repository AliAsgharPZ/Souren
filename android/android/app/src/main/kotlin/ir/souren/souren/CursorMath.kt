package ir.souren.souren

/** Absolute cursor-position math for the spacebar trackpad (owner B1).
 *
 *  The old moveCursor() computed the target from
 *  getTextBeforeCursor(200) + getTextAfterCursor(200) and passed that
 *  WINDOW-relative offset to InputConnection.setSelection(), which
 *  expects ABSOLUTE editor offsets — so the cursor jumped whenever the
 *  caret was beyond the 200-character window.
 *
 *  The IME reads ExtractedText's window start plus its window-relative
 *  selection bounds, then this pure function returns an absolute editor
 *  offset. Movement therefore remains correct for partial extracts and
 *  long documents, including selections.
 */
object CursorMath {
    /** Absolute caret offset after moving by [delta] characters.
     *  [selStart]/[selEnd] are relative to the extracted window
     *  (either may be -1 when unknown). Moving forward starts from the
     *  selection end, moving backward from the selection start, so a
     *  selection is collapsed the way Samsung's trackpad does. */
    fun newSelection(
        startOffset: Int,
        selStart: Int,
        selEnd: Int,
        extractedTextLength: Int,
        delta: Int
    ): Int {
        // ExtractedText selectionStart/End are RELATIVE to its extracted
        // window. setSelection(), however, requires an ABSOLUTE editor
        // offset. Translate through startOffset before clamping/moving.
        val windowStart = startOffset.coerceAtLeast(0)
        val windowEnd = (windowStart.toLong() + extractedTextLength.coerceAtLeast(0))
            .coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        val s = if (selStart < 0) windowStart
            else (windowStart.toLong() + selStart).coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
        val e = if (selEnd < 0) windowStart
            else (windowStart.toLong() + selEnd).coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
        val base = if (delta >= 0) maxOf(s, e) else minOf(s, e)
        return (base.toLong() + delta).coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
    }
}
