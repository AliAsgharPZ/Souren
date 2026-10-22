package ir.souren.souren

/** Mirror of the Dart correction engine (lib/engine/corrector.dart).
 *  Keep the two in sync — the same owner examples are unit-tested in both. */
object Corrector {
    const val ZWNJ = "\u200C"
    const val HAMZA = "\u0654"

    private val letterFix = mapOf(
        'ي' to "ی", 'ك' to "ک", 'ة' to "ه", 'ۀ' to "هٔ",
        'أ' to "ا", 'إ' to "ا", 'ٱ' to "ا", 'ؤ' to "و"
    )

    private val stemFix = mapOf("خام" to "خوام", "خاد" to "خواهد", "خان" to "خوان")

    val ezafeHeads = setOf(
        "همه", "خانه", "صفحه", "نامه", "سایه", "پنجره", "هفته", "لحظه",
        "نکته", "واژه", "جمله", "قصه", "خاطره", "مسئله", "بهانه", "نشانه"
    )

    fun normalizeLetters(s: String): String {
        val sb = StringBuilder()
        for (c in s) sb.append(letterFix[c] ?: c.toString())
        return sb.toString()
    }

    data class WordFix(val fixed: String, val suggestions: List<String>)

    fun correctWord(
        word: String,
        dictionary: Map<String, List<String>> = emptyMap(),
        replaceArabic: Boolean = true
    ): WordFix {
        var w = normalizeLetters(word)
        if (w.endsWith("ه‌ی")) {
            w = w.dropLast(2) + "ه" + HAMZA
        }
        for (prefix in listOf("نمی", "می")) {
            if (w.startsWith(prefix) && w.length > prefix.length + 1 && !w.contains(ZWNJ)) {
                var stem = w.substring(prefix.length)
                stem = stemFix[stem] ?: stem
                w = prefix + ZWNJ + stem
                break
            }
        }
        val parts = w.split(ZWNJ)
        if (parts.size == 2 && (parts[0] == "می" || parts[0] == "نمی")) {
            stemFix[parts[1]]?.let { w = parts[0] + ZWNJ + it }
        }
        val suggestions = mutableListOf<String>()
        val eq = dictionary[w] ?: dictionary[word]
        if (!eq.isNullOrEmpty()) {
            suggestions.addAll(eq)
            if (replaceArabic && eq.size == 1 && !eq[0].contains(' ') && !eq[0].contains('،')) {
                w = eq[0]
            }
        }
        return WordFix(w, suggestions)
    }

    /** Fix to apply to the text right before the cursor when a separator
     *  (space/punctuation) is typed. Returns (charsToDelete, replacement)
     *  or null when nothing changes. [before] is the text before cursor. */
    fun fixBeforeSeparator(
        before: String,
        dictionary: Map<String, List<String>>,
        replaceArabic: Boolean
    ): Pair<Int, String>? {
        if (before.isEmpty()) return null
        val words = before.split(' ')
        val last = words.last()
        if (last.isEmpty()) return null

        // ها-merge: "… کتاب ها" -> "… کتاب‌ها"
        if ((last == "ها" || last == "های" || last == "هایی") && words.size >= 2) {
            val prev = words[words.size - 2]
            if (prev.isNotEmpty()) {
                return (last.length + 1) to (ZWNJ + last)
            }
        }

        val fix = correctWord(last, dictionary, replaceArabic)
        var newLast = fix.fixed

        // Ezafe: previous word is an ه-final head and this word follows it.
        if (words.size >= 2) {
            val prev = words[words.size - 2]
            val prevBare = prev.replace(HAMZA, "")
            if (prev.endsWith('ه') && prevBare in ezafeHeads && last.length >= 2) {
                return (prev.length + 1 + last.length) to (prev + HAMZA + " " + newLast)
            }
        }
        if (newLast != last) return last.length to newLast
        return null
    }

    /** Suggestions for the word being typed: dictionary equivalents first,
     *  then learned completions (prefix matches ranked by learned counts). */
    fun suggestionsFor(
        word: String,
        dictionary: Map<String, List<String>>,
        learnedCounts: Map<String, Int>,
        vocab: List<String>
    ): List<String> {
        if (word.isEmpty()) return emptyList()
        val out = mutableListOf<String>()
        val fix = correctWord(word, dictionary, replaceArabic = false)
        if (fix.fixed != word) out.add(fix.fixed)
        dictionary[word]?.let { out.addAll(it) }
        val completions = vocab
            .filter { it.startsWith(word) && it != word }
            .sortedByDescending { learnedCounts[it] ?: 0 }
            .take(3)
        out.addAll(completions)
        return out.distinct().take(4)
    }
}
