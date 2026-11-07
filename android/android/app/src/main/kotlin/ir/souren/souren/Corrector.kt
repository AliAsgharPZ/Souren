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

    private val miExceptions = setOf(
        "میدان", "میدون", "میخک", "میهن", "میان", "میوه", "میراث"
    )

    private val verbStemStarts = listOf(
        "خواه", "خوا", "آی", "آور", "آفرین", "افکن", "فکن", "انداز", "انگیز",
        "دون", "دان", "تون", "توان", "بین", "گیر", "ذار", "زار", "گذار", "گزار",
        "خور", "خر", "نویس", "نوش", "نشین", "خند", "گری", "گریز", "فهم", "سوز",
        "سوزان", "خون", "ساز", "پرس", "پرست", "گرد", "گشا", "زن", "گو", "گوی",
        "شو", "کن", "ده", "نه", "دو", "رم", "رو", "روی", "رس", "ره", "شه",
        "گه", "پر", "جه", "بار", "باف", "بند", "بر", "بوس", "پاش", "پذیر",
        "پوش", "پیچ", "تاب", "تراش", "ترس", "جوش", "چرخ", "چسب", "چین",
        "دار", "دم", "دوش", "ران", "رقص", "ریز", "ستان", "سرا", "شتاب",
        "شکاف", "شمار", "شناس", "طلب", "غلت", "فرست", "فروش", "فشار",
        "کار", "کش", "کوش", "کوب", "لرز", "مان", "مال", "مک", "نال"
    )

    private val fusedComparatives = setOf(
        "بهتر", "کمتر", "بیشتر", "مهتر", "کهتر",
        "بهترین", "کمترین", "بیشترین", "مهترین", "کهترین",
        "دختر", "لیتر", "باختر", "کبوتر", "انگشتر"
    )

    private val haExceptions = setOf("تنها", "آنها", "اینها")

    private val cliticStems = setOf(
        "خانه", "سایه", "صفحه", "نامه", "واژه", "جمله", "قصه", "لحظه", "هفته",
        "پنجره", "خاطره", "مسئله", "بهانه", "نشانه", "کشتی", "همه", "مدرسه",
        "جعبه", "سرمایه", "پرده", "زمینه", "ستاره", "شیشه", "سکه", "تکه",
        "حادثه", "فاجعه", "واقعه", "صحنه", "نغمه", "شعله", "قطره", "نمره",
        "نقشه", "چهره", "جلوه", "زاویه", "قهوه", "میوه", "پایه", "مایه",
        "رویه", "لایه", "کوچه", "بوته", "غنچه", "جوانه", "کرانه", "ترانه",
        "افسانه", "پیمانه", "شکوفه", "خاله", "عمه", "صندلی", "بازی", "ماهی",
        "گاری", "دایی", "نیمه", "دهه", "گونه"
    )

    private val clitics = listOf(
        "شان", "تان", "مان", "شون", "تون", "مون", "اش", "ام", "ات", "م", "ت", "ش"
    )

    private val biStems = setOf(
        "آبرو", "ابرو", "نهایت", "پایان", "فرهنگ", "ادب", "انصاف", "سواد",
        "شمار", "اندازه", "رحم", "مزه", "خبر", "نام", "نشان", "رنگ", "بو",
        "حیا", "شرم", "عقل", "احتیاط", "اختیار", "اراده", "اعتماد", "امان",
        "باک", "باور", "بهره", "پروا", "پرده", "پول", "تاب", "تجربه",
        "تردید", "تکلف", "توجه", "ثبات", "جا", "چاره", "حاصل", "حال",
        "حساب", "حس", "خانمان", "خواب", "خود", "درد", "دریغ", "دلیل",
        "دین", "رقیب", "روح", "ریا", "زبان", "سابقه", "سرپرست", "سلیقه",
        "سود", "شعور", "شک", "صاحب", "صبر", "صدا", "ضرر", "طرف", "طاقت",
        "عاطفه", "عرضه", "علاقه", "عیب", "غرض", "فایده", "قاعده", "قرار",
        "قید", "کار", "کس", "گناه", "لطف", "محابا", "مسئولیت", "معرفت",
        "معنی", "مغز", "ملاحظه", "منطق", "موقع", "نظم", "نصیب", "نقاب",
        "نظیر", "نوا", "نیاز", "هدف", "همتا", "هنر", "هوا", "هوش",
        "واسطه", "وفا", "وقفه", "سر"
    )

    val ezafeHeads = setOf(
        "همه", "خانه", "صفحه", "نامه", "سایه", "پنجره", "هفته", "لحظه",
        "نکته", "واژه", "جمله", "قصه", "خاطره", "مسئله", "بهانه", "نشانه",
        "مدرسه", "چهره", "جلوه", "زاویه", "قهوه", "میوه", "پایه", "مایه",
        "لایه", "رویه", "کوچه", "بوته", "غنچه", "جوانه", "کرانه", "ترانه",
        "افسانه", "پیمانه", "شکوفه", "حادثه", "فاجعه", "واقعه", "صحنه",
        "نغمه", "شعله", "قطره", "نمره", "نقشه", "سکه", "تکه", "شیشه",
        "ستاره", "زمینه", "پرده", "سرمایه", "جعبه", "نیمه", "کلیه", "عده",
        "دهه", "سده", "گونه", "رده", "مرحله", "ناحیه", "قاره", "جزیره"
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
        // Attached ezafe ی after a known ه-final head: همهی → همهٔ
        if (w.length > 2 && w.endsWith("ی") && !w.contains(HAMZA)) {
            val stem = w.dropLast(1)
            if (stem in ezafeHeads) w = stem + HAMZA
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
            for (ending in listOf("است", "ایم", "اید", "اند", "ام", "ای")) {
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
            if (replaceArabic) {
                // First single-word equivalent wins (the old rule needed
                // exactly one equivalent, so multi-equivalent words like
                // اتفاق never got replaced at all).
                for (cand in eq) {
                    if (!cand.contains(' ') && !cand.contains('،') && cand != w) {
                        w = cand
                        break
                    }
                }
            }
        }
        return WordFix(w, suggestions)
    }

    /** The word that ends [before], found WITHOUT destroying separators:
     *  newlines, tabs and repeated spaces stay out of the word itself
     *  (the old split(' ') could return empty/partial tokens). */
    private fun lastWord(before: String): String {
        val start = before.indexOfLast { it == ' ' || it == '\n' || it == '\t' || it == '\r' } + 1
        return before.substring(start)
    }

    /** The word before [lastStart] and whether it is separated by
     *  EXACTLY one ordinary space (the only case where the ها-merge and
     *  the ezafe fix are allowed to rewrite the separator). */
    private fun prevWord(before: String, lastStart: Int): Pair<Boolean, String> {
        val sep = lastStart - 1
        if (sep < 1 || before[sep] != ' ') return false to ""
        if (before[sep - 1] == ' ' || before[sep - 1] == '\n' ||
            before[sep - 1] == '\t' || before[sep - 1] == '\r'
        ) return false to ""
        val pStart = before.lastIndexOfAny(charArrayOf(' ', '\n', '\t', '\r'), sep - 1) + 1
        return true to before.substring(pStart, sep)
    }

    /** Leading/trailing quotes, parentheses and punctuation around a
     *  word — stripped for the dictionary/rules lookup, re-attached
     *  afterwards so «اتفاق،» and (اتفاق) keep their marks. */
    private val leadingMarks = "«\"'(‘“"
    private val trailingMarks = "»\"')’”،.؟!؛:…"
    private fun splitMarks(word: String): Triple<String, String, String> {
        var lead = ""
        var core = word
        while (core.isNotEmpty() && core.length > lead.length + 1 && leadingMarks.contains(core.first())) {
            lead = lead + core.first()
            core = core.substring(1)
        }
        var trail = ""
        while (core.length > 1 && trailingMarks.contains(core.last())) {
            trail = core.last() + trail
            core = core.dropLast(1)
        }
        return Triple(lead, core, trail)
    }

    /** Fix to apply right before the cursor when a separator is typed.
     *  Returns (charsToDelete, replacement) or null. Whitespace and
     *  punctuation are preserved exactly (owner B3). */
    fun fixBeforeSeparator(
        before: String,
        dictionary: Map<String, List<String>>,
        replaceArabic: Boolean
    ): Pair<Int, String>? {
        if (before.isEmpty()) return null
        val rawLast = lastWord(before)
        if (rawLast.isEmpty()) return null
        val lastStart = before.length - rawLast.length
        val (singleSpace, prev) = prevWord(before, lastStart)
        // Strip marks for the lookup; they are re-attached to the fix
        // («اتفاق،» used to match nothing).
        val (lead, core, trail) = splitMarks(rawLast)

        if ((core == "ها" || core == "های" || core == "هایی") && singleSpace && prev.isNotEmpty()) {
            // Delete exactly the one space + the typed word and merge it
            // with ZWNJ — repeated spaces/newlines are left untouched.
            return (rawLast.length + 1) to (ZWNJ + rawLast)
        }

        val fix = correctWord(core, dictionary, replaceArabic)
        val newLast = lead + fix.fixed + trail

        if (singleSpace && prev.isNotEmpty()) {
            val prevBare = prev.replace(HAMZA, "")
            if (prev.endsWith('ه') && prevBare in ezafeHeads && core.length >= 2) {
                return (prev.length + 1 + rawLast.length) to
                    (prev + HAMZA + " " + newLast)
            }
        }
        if (newLast != rawLast) return rawLast.length to newLast
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
