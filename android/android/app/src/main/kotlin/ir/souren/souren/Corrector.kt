package ir.souren.souren

/** Mirror of the Dart correction engine v2 (lib/engine/corrector.dart).
 *  Keep the two in sync — the same cases are unit-tested in both. */
object Corrector {
    const val ZWNJ = "\u200C"
    const val HAMZA = "\u0654"

    private val letterFix = mapOf(
        'ي' to "ی", 'ك' to "ک", 'ة' to "ه", 'ۀ' to "هٔ",
        'أ' to "ا", 'إ' to "ا", 'ٱ' to "ا", 'ؤ' to "و"
    )

    private val stemFix = mapOf("خام" to "خوام", "خاد" to "خواهد", "خان" to "خوان")

    private val miExceptions = setOf("میدان", "میدون")

    private val verbStemStarts = listOf(
        "خواه", "خوا", "دون", "دان", "تون", "توان", "بین", "گیر", "ذار", "زار",
        "خور", "نویس", "خند", "گری", "فهم", "سوز", "خون", "ساز", "پرس", "گرد",
        "زن", "گو", "شو", "کن", "ده", "دو", "رم", "رو", "رس", "ره", "شه",
        "گه", "پر"
    )

    private val fusedComparatives = setOf(
        "بهتر", "کمتر", "بیشتر", "مهتر", "کهتر",
        "بهترین", "کمترین", "بیشترین", "مهترین", "کهترین",
        "دختر", "لیتر", "باختر"
    )

    private val haExceptions = setOf("تنها")

    private val cliticStems = setOf(
        "خانه", "سایه", "صفحه", "نامه", "واژه", "جمله", "قصه", "لحظه", "هفته",
        "پنجره", "خاطره", "مسئله", "بهانه", "نشانه", "کشتی", "همه", "مدرسه",
        "جعبه", "سرمایه", "پرده", "زمینه", "ستاره", "شیشه", "سکه", "تکه"
    )

    private val clitics = listOf("شان", "تان", "مان", "اش", "ام", "ات")

    private val biStems = setOf(
        "آبرو", "ابرو", "نهایت", "پایان", "فرهنگ", "ادب", "انصاف", "سواد",
        "شمار", "اندازه", "رحم", "مزه", "خبر", "نام", "نشان", "رنگ", "بو",
        "حیا", "شرم", "عقلی"
    )

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

    private fun splitBefore(w: String, suffix: String): String =
        w.dropLast(suffix.length) + ZWNJ + suffix

    fun correctWord(
        word: String,
        dictionary: Map<String, List<String>> = emptyMap(),
        replaceArabic: Boolean = true
    ): WordFix {
        var w = normalizeLetters(word)

        if (w.endsWith("ه‌ی")) {
            w = w.dropLast(2) + "ه" + HAMZA
        }

        // می/نمی + verb stem (guarded)
        if (w !in miExceptions) {
            for (prefix in listOf("نمی", "می")) {
                if (w.startsWith(prefix) && w.length > prefix.length + 1 && !w.contains(ZWNJ)) {
                    val rest = w.substring(prefix.length)
                    val stemmed = stemFix[rest]
                        ?: if (verbStemStarts.any { rest.startsWith(it) }) rest else null
                    if (stemmed != null) w = prefix + ZWNJ + stemmed
                    break
                }
            }
        }
        val parts = w.split(ZWNJ)
        if (parts.size == 2 && (parts[0] == "می" || parts[0] == "نمی")) {
            stemFix[parts[1]]?.let { w = parts[0] + ZWNJ + it }
        }

        // ترین / تر
        if (w !in fusedComparatives && !w.contains(ZWNJ)) {
            if (w.endsWith("ترین") && w.length > 5) {
                w = splitBefore(w, "ترین")
            } else if (w.endsWith("تر") && w.length > 4) {
                w = splitBefore(w, "تر")
            }
        }

        // ها attached
        if (w !in haExceptions && w.endsWith("ها") && w.length > 3 && !w.contains(ZWNJ)) {
            w = splitBefore(w, "ها")
        }

        // past-perfect endings after ه
        if (!w.contains(ZWNJ)) {
            for (ending in listOf("ایم", "اید", "اند", "ام", "ای")) {
                if (w.endsWith(ending)) {
                    val stem = w.dropLast(ending.length)
                    if (stem.endsWith("ه") && stem.length >= 3) {
                        w = stem + ZWNJ + ending
                    }
                    break
                }
            }
        }

        // possessive clitics
        if (!w.contains(ZWNJ)) {
            for (c in clitics) {
                if (w.endsWith(c) && w.length > c.length + 2) {
                    val stem = w.dropLast(c.length)
                    if (stem in cliticStems) {
                        w = stem + ZWNJ + c
                        break
                    }
                }
            }
        }

        // شده compounds
        if (w.endsWith("شده") && w.length - 3 >= 2 && !w.contains(ZWNJ)) {
            w = splitBefore(w, "شده")
        }

        // بی prefix
        if (w.startsWith("بی") && w.length > 4 && !w.contains(ZWNJ)) {
            val rest = w.substring(2)
            if (rest in biStems) w = "بی" + ZWNJ + rest
        }

        val suggestions = mutableListOf<String>()
        val eq = dictionary[w] ?: dictionary[word] ?: dictionary[normalizeLetters(word)]
        if (!eq.isNullOrEmpty()) {
            suggestions.addAll(eq)
            if (replaceArabic && eq.size == 1 && !eq[0].contains(' ') && !eq[0].contains('،')) {
                w = eq[0]
            }
        }
        return WordFix(w, suggestions)
    }

    /** Fix to apply right before the cursor when a separator is typed.
     *  Returns (charsToDelete, replacement) or null. */
    fun fixBeforeSeparator(
        before: String,
        dictionary: Map<String, List<String>>,
        replaceArabic: Boolean
    ): Pair<Int, String>? {
        if (before.isEmpty()) return null
        val words = before.split(' ')
        val last = words.last()
        if (last.isEmpty()) return null

        if ((last == "ها" || last == "های" || last == "هایی") && words.size >= 2) {
            val prev = words[words.size - 2]
            if (prev.isNotEmpty()) {
                return (last.length + 1) to (ZWNJ + last)
            }
        }

        val fix = correctWord(last, dictionary, replaceArabic)
        val newLast = fix.fixed

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
