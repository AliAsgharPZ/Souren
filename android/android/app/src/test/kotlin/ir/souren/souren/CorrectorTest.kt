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
        val f = Corrector.correctWord("احترام", dict)
        assertEquals("احترام", f.fixed)
        assertEquals(listOf("گرامیداشت", "ارج"), f.suggestions)
    }

    @Test fun noChangeNoFix() {
        assertNull(Corrector.fixBeforeSeparator("سلام", emptyMap(), true))
    }
}
