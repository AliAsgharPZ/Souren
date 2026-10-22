package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class CorrectorTest {
    private val dict = mapOf(
        "سوال" to listOf("پرسش"),
        "احترام" to listOf("گرامیداشت", "ارج")
    )

    @Test fun ownerExamples() {
        assertEquals("می‌خوام", Corrector.correctWord("میخام").fixed)
        assertEquals("می‌خوام", Corrector.correctWord("میخوام").fixed)
        val fix = Corrector.fixBeforeSeparator("همه افراد", emptyMap(), true)
        assertEquals(9 to "همهٔ افراد", fix)
    }

    @Test fun prefixJoin() {
        assertEquals("می‌رم", Corrector.correctWord("میرم").fixed)
        assertEquals("نمی‌دونم", Corrector.correctWord("نمیدونم").fixed)
    }

    @Test fun haMerge() {
        val fix = Corrector.fixBeforeSeparator("کتاب ها", emptyMap(), true)
        assertEquals("‌ها", fix?.second)
        assertEquals(3, fix?.first)
    }

    @Test fun arabicLetters() {
        assertEquals("یک", Corrector.correctWord("يك").fixed)
    }

    @Test fun singleEquivalentReplaces() {
        assertEquals("پرسش", Corrector.correctWord("سوال", dict).fixed)
    }

    @Test fun multiEquivalentOnlySuggests() {
        val f = Corrector.correctWord("احترام", dict)
        assertEquals("احترام", f.fixed)
        assertEquals(listOf("گرامیداشت", "ارج"), f.suggestions)
    }

    @Test fun noChangeNoFix() {
        assertNull(Corrector.fixBeforeSeparator("سلام", emptyMap(), true))
    }
}
