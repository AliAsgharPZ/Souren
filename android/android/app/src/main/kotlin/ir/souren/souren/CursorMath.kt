package ir.souren.souren

/** Absolute cursor-position math for the spacebar trackpad.
 *
 * ExtractedText selection bounds are relative to its extracted window,
 * while InputConnection.setSelection expects offsets in the full editor.
 */
object CursorMath {
    fun newSelection(
        startOffset: Int,
        selStart: Int,
        selEnd: Int,
        extractedTextLength: Int,
        delta: Int
    ): Int {
        val windowStart = startOffset.coerceAtLeast(0)
        val windowEnd = (windowStart.toLong() + extractedTextLength.coerceAtLeast(0))
            .coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        val s = if (selStart < 0) windowStart
            else (windowStart.toLong() + selStart)
                .coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
        val e = if (selEnd < 0) windowStart
            else (windowStart.toLong() + selEnd)
                .coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
        val base = if (delta >= 0) maxOf(s, e) else minOf(s, e)
        return (base.toLong() + delta)
            .coerceIn(windowStart.toLong(), windowEnd.toLong()).toInt()
    }
}
