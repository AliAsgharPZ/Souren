package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CorrectorTest {
    private val dict = mapOf(
        "سوال" to listOf("پرسش"),
        "جواب" to listOf("پاسخ"),
        "احترام" to listOf("گرامیداشت", "ارج")
    )

    @Test fun ownerExamples() {
        assertEquals("می‌خوام", Corrector.correctWord("میخام").fixed)
        assertEquals("می‌خوام", Corrector.correctWord("میخوام").fixed)
        assertEquals(9 to "همهٔ افراد",
            Corrector.fixBeforeSeparator("همه افراد", emptyMap(), true))
        assertEquals("پرسش", Corrector.correctWord("سوال", dict).fixed)
        assertEquals("پاسخ", Corrector.correctWord("جواب", dict).fixed)
    }

    @Test fun suffixRules() {
        assertEquals("عالی‌ترین", Corrector.correctWord("عالیترین").fixed)
        assertEquals("بزرگ‌ترین", Corrector.correctWord("بزرگترین").fixed)
        assertEquals("گرم‌تر", Corrector.correctWord("گرمتر").fixed)
        assertEquals("بهترین", Corrector.correctWord("بهترین").fixed)
        assertEquals("بیشتر", Corrector.correctWord("بیشتر").fixed)
        assertEquals("دختر", Corrector.correctWord("دختر").fixed)
        assertEquals("کتاب‌ها", Corrector.correctWord("کتابها").fixed)
        assertEquals("تنها", Corrector.correctWord("تنها").fixed)
        assertEquals("رفته‌ام", Corrector.correctWord("رفتهام").fixed)
        assertEquals("خانه‌اش", Corrector.correctWord("خانهاش").fixed)
        assertEquals("کشتی‌شان", Corrector.correctWord("کشتیشان").fixed)
        assertEquals("گم‌شده", Corrector.correctWord("گمشده").fixed)
        assertEquals("بی‌نهایت", Corrector.correctWord("بینهایت").fixed)
    }

    @Test fun miGuard() {
        assertEquals("میدان", Corrector.correctWord("میدان").fixed)
        assertEquals("میراث", Corrector.correctWord("میراث").fixed)
        assertEquals("می‌رم", Corrector.correctWord("میرم").fixed)
        assertEquals("نمی‌شه", Corrector.correctWord("نمیشه").fixed)
    }

    @Test fun haMerge() {
        val fix = Corrector.fixBeforeSeparator("کتاب ها", emptyMap(), true)
        assertEquals(3, fix?.first)
        assertEquals("‌ها", fix?.second)
    }

    @Test fun arabicLettersAndMulti() {
        assertEquals("یک", Corrector.correctWord("يك").fixed)
        // Owner order 2026-10-25: with several equivalents, the FIRST
        // single-word one replaces; the rest stay as suggestions.
        val f = Corrector.correctWord("احترام", dict)
        assertEquals("گرامیداشت", f.fixed)
        assertEquals(listOf("گرامیداشت", "ارج"), f.suggestions)
    }

    @Test fun expandedLists() {
        assertEquals("می‌ترسم", Corrector.correctWord("میترسم").fixed)
        assertEquals("می‌نشینم", Corrector.correctWord("مینشینم").fixed)
        assertEquals("بی‌قرار", Corrector.correctWord("بیقرار").fixed)
        assertEquals("بی‌گناه", Corrector.correctWord("بیگناه").fixed)
        assertEquals("کبوتر", Corrector.correctWord("کبوتر").fixed)
        assertEquals("آنها", Corrector.correctWord("آنها").fixed)
        assertEquals("خانه‌م", Corrector.correctWord("خانهم").fixed)
        assertEquals("همهٔ", Corrector.correctWord("همهی").fixed)
        assertEquals("رفته‌است", Corrector.correctWord("رفتهاست").fixed)
        assertEquals("میدان", Corrector.correctWord("میدان").fixed)
        assertEquals("بیمار", Corrector.correctWord("بیمار").fixed)
        assertEquals("بیان", Corrector.correctWord("بیان").fixed)
    }

    @Test fun punctuationDoesNotBlockReplacement() {
        val d2 = mapOf("اتفاق" to listOf("رویداد", "پیشامد"))
        assertEquals(6 to "رویداد،",
            Corrector.fixBeforeSeparator("اتفاق،", d2, true))
        assertEquals("رویداد",
            Corrector.correctWord("اتفاق", d2).fixed)
    }

    @Test fun noChangeNoFix() {
        assertNull(Corrector.fixBeforeSeparator("سلام", emptyMap(), true))
    }

    // ---------- B3 regression: whitespace, quotes, parentheses ----------

    @Test fun multilineBefore_keepsWorking() {
        // last word after a newline is still corrected
        val f = Corrector.fixBeforeSeparator("یک خط\nسوال", dict, true)
        assertEquals("پرسش", f?.second)
        assertEquals(4, f?.first)
        // ezafe must NOT fire across a newline
        assertNull(Corrector.fixBeforeSeparator("همه\nافراد", emptyMap(), true))
    }

    @Test fun repeatedSpaces_neverMergeNorCrash() {
        // two spaces before ها: not a single-space merge
        assertNull(Corrector.fixBeforeSeparator("کتاب  ها", emptyMap(), true))
        // trailing empty token (space right before the separator) is safe
        assertNull(Corrector.fixBeforeSeparator("کتاب ", emptyMap(), true))
    }

    @Test fun quotedWord_isCorrectedInsideTheQuotes() {
        val d2 = mapOf("اتفاق" to listOf("رویداد", "پیشامد"))
        val f = Corrector.fixBeforeSeparator("«اتفاق»", d2, true)
        assertEquals(7, f?.first)
        assertEquals("«رویداد»", f?.second)
    }

    @Test fun parenthesizedWord_isCorrectedInsideTheParens() {
        val d2 = mapOf("اتفاق" to listOf("رویداد", "پیشامد"))
        val f = Corrector.fixBeforeSeparator("(اتفاق)", d2, true)
        assertEquals("(رویداد)", f?.second)
    }

    @Test fun punctuationPlusQuotes_reattach() {
        val d2 = mapOf("اتفاق" to listOf("رویداد", "پیشامد"))
        val f = Corrector.fixBeforeSeparator("«اتفاق».", d2, true)
        assertEquals("«رویداد».", f?.second)
    }

    @Test fun singleSpaceHaMerge_stillWorks() {
        val fix = Corrector.fixBeforeSeparator("کتاب ها", emptyMap(), true)
        assertEquals(3, fix?.first)
        assertEquals("‌ها", fix?.second)
        // quoted variant keeps the marks
        val q = Corrector.fixBeforeSeparator("«کتاب ها»", emptyMap(), true)
        assertEquals("\u200Cها»", q?.second)
    }

    @Test fun ezafeStillWorksAcrossSingleSpace() {
        assertEquals(
            9 to "همهٔ افراد",
            Corrector.fixBeforeSeparator("همه افراد", emptyMap(), true)
        )
    }

    @Test fun correctWordKeepsMarksUntouched() {
        // correctWord never strips marks — fixBeforeSeparator (and the
        // Dart correctText) strip them before the lookup.
        assertEquals("«میخام»", Corrector.correctWord("«میخام»").fixed)
        assertEquals("(میخام)", Corrector.correctWord("(میخام)").fixed)
        // single-char and bare marks stay intact
        assertEquals("س", Corrector.correctWord("س").fixed)
        assertEquals("«", Corrector.correctWord("«").fixed)
    }
}
