package ir.souren.souren

/** Absolute cursor-position math for the spacebar trackpad (owner B1).
 *
 *  The old moveCursor() computed the target from
 *  getTextBeforeCursor(200) + getTextAfterCursor(200) and passed that
 *  WINDOW-relative offset to InputConnection.setSelection(), which
 *  expects ABSOLUTE editor offsets — so the cursor jumped whenever the
 *  caret was beyond the 200-character window.
 *
 *  The IME now reads the absolute selection from ExtractedText and lets
 *  this pure function compute the new absolute offset, so cursor
 *  movement is correct near the beginning, past character 200/500, at
 *  the end of long documents, and with a selection active.
 */
object CursorMath {
    /** Absolute caret offset after moving by [delta] characters.
     *  [selStart]/[selEnd] are the editor's absolute selection bounds
     *  (either may be -1 when unknown). Moving forward starts from the
     *  selection end, moving backward from the selection start, so a
     *  selection is collapsed the way Samsung's trackpad does. */
    fun newSelection(
        selStart: Int,
        selEnd: Int,
        textLength: Int,
        delta: Int
    ): Int {
        val len = textLength.coerceAtLeast(0)
        val s = if (selStart < 0) 0 else selStart.coerceIn(0, len)
        val e = if (selEnd < 0) 0 else selEnd.coerceIn(0, len)
        val base = if (delta >= 0) maxOf(s, e) else minOf(s, e)
        return (base + delta).coerceIn(0, len)
    }
}
