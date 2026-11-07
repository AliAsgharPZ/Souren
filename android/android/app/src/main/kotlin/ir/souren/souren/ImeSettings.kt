package ir.souren.souren

/** Pure snapshot of the settings that affect the keyboard layout —
 *  lets the IME rebuild key rows ONLY when something relevant changed
 *  (owner B5: height changes must apply while the keyboard is already
 *  enabled, without flickering on every input switch). Pure JVM: unit
 *  tested without Robolectric; the IME feeds it from KbData. */
object ImeSettings {
    data class Snapshot(
        val kbHeight: String,
        val autoCorrect: Boolean,
        val replaceArabic: Boolean,
    )

    fun snapshot(
        kbHeight: String,
        autoCorrect: Boolean,
        replaceArabic: Boolean
    ) = Snapshot(kbHeight, autoCorrect, replaceArabic)

    /** True when the key rows must be rebuilt (a relevant setting
     *  changed between two activations of the input view). */
    fun needsRebuild(previous: Snapshot?, now: Snapshot): Boolean =
        previous != now
}
