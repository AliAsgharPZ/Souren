package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Regression tests for owner B1 (cursor trackpad absolute
 *  positioning), B2 (dataset reload/fallback), B3 (whitespace +
 *  punctuation in correction) and B5 (settings rebuilds). */
class CursorMathTest {
    private fun move(
        selStart: Int,
        selEnd: Int,
        len: Int,
        delta: Int,
        startOffset: Int = 0
    ) = CursorMath.newSelection(startOffset, selStart, selEnd, len, delta)

    @Test fun nearTheBeginning_neverGoesNegative() {
        assertEquals(0, move(0, 0, 1000, -1))
        assertEquals(0, move(0, 0, 1000, -50))
        assertEquals(0, move(3, 3, 1000, -3))
        assertEquals(0, move(2, 2, 1000, -3))
    }

    @Test fun beyondCharacter200_usesAbsoluteOffsets() {
        // The old bug: a window-relative position (before.length + delta)
        // was passed to setSelection, so past the 200-char window the
        // cursor jumped backwards into the window.
        val len = 2000
        assertEquals(260, move(261, 261, len, -1))
        assertEquals(262, move(261, 261, len, 1))
        assertEquals(510, move(500, 500, len, 10))
    }

    @Test fun partialExtractedWindow_usesAbsoluteStartOffset() {
        // ExtractedText.selectionStart/End are relative to its window;
        // setSelection needs the corresponding document-absolute offset.
        assertEquals(10_160, move(150, 150, 200, 10, startOffset = 10_000))
        assertEquals(10_000, move(2, 2, 200, -5, startOffset = 10_000))
        assertEquals(10_200, move(195, 195, 200, 20, startOffset = 10_000))
    }

    @Test fun beyondCharacter500() {
        assertEquals(599, move(600, 600, 5000, -1))
        assertEquals(730, move(700, 700, 5000, 30))
    }

    @Test fun nearTheEndOfLongDocument_clamps() {
        val len = 100_000
        assertEquals(len, move(len - 1, len - 1, len, 1))
        assertEquals(len, move(len, len, len, 20))
        assertEquals(len - 7, move(len, len, len, -7))
    }

    @Test fun withSelection_forwardCollapsesToSelectionEnd() {
        assertEquals(120, move(100, 120, 1000, 0))
        assertEquals(121, move(100, 120, 1000, 1))
        // moving backward collapses to the selection START: 100 - 19 = 81
        assertEquals(81, move(100, 120, 1000, -19))
    }

    @Test fun withSelection_backwardCollapsesToSelectionStart() {
        assertEquals(99, move(100, 120, 1000, -1))
    }

    @Test fun multilineContent_usesTotalLength() {
        val text = "خط اول\nخط دوم\nخط سوم"
        assertEquals(text.length, move(0, 0, text.length, 999))
        assertEquals(1, move(2, 2, text.length, -1))
    }

    @Test fun unknownSelectionTreatedAsZero() {
        assertEquals(5, move(-1, -1, 100, 5))
        assertEquals(0, move(-1, -1, 100, -5))
    }

    @Test fun emptyDocument() {
        assertEquals(0, move(0, 0, 0, 1))
        assertEquals(0, move(0, 0, 0, -1))
    }
}

class DatasetValidatorTest {
    private val valid = """
        {"version": 2, "entries": [
            {"ar": "ابتدا", "fa": ["آغاز"]},
            {"ar": "اتفاق", "fa": ["رویداد", "پیشامد"]}
        ]}
    """.trimIndent()

    @Test fun validDatasetPasses() {
        val r = DatasetValidator.validate(valid)
        assertTrue(r is DatasetValidator.Result.Valid)
    }

    @Test fun malformedJsonIsInvalid() {
        assertTrue(DatasetValidator.validate("{entries: [") is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("not json at all") is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("") is DatasetValidator.Result.Invalid)
    }

    @Test fun entriesMustBeAnArray() {
        val r = DatasetValidator.validate("""{"entries": "nope"}""")
        assertTrue(r is DatasetValidator.Result.Invalid)
    }

    @Test fun emptyArabicWordIsInvalid() {
        val r = DatasetValidator.validate(
            """{"entries": [{"ar": "", "fa": []}]}"""
        )
        assertTrue(r is DatasetValidator.Result.Invalid)
    }

    @Test fun nonStringArabicWordIsInvalid() {
        val r = DatasetValidator.validate(
            """{"entries": [{"ar": 42}]}"""
        )
        assertTrue(r is DatasetValidator.Result.Invalid)
    }

    @Test fun malformedFaArrayIsInvalid() {
        val r = DatasetValidator.validate(
            """{"entries": [{"ar": "اتفاق", "fa": "رویداد"}]}"""
        )
        assertTrue(r is DatasetValidator.Result.Invalid)
    }

    @Test fun nonStringMeaningIsInvalidInStrictMode() {
        val r = DatasetValidator.validate(
            """{"entries": [{"ar": "اتفاق", "fa": [3]}]}""",
            strictFa = true
        )
        assertTrue(r is DatasetValidator.Result.Invalid)
        // lenient mode (keyboard fallback) tolerates it — the word keys
        // still work for suggestions
        assertTrue(
            DatasetValidator.validate(
                """{"entries": [{"ar": "اتفاق", "fa": [3]}]}"""
            ) is DatasetValidator.Result.Valid
        )
    }

    @Test fun duplicateArabicKeysAreInvalid() {
        val r = DatasetValidator.validate(
            """{"entries": [{"ar": "اتفاق"}, {"ar": "اتفاق"}]}"""
        )
        assertTrue(r is DatasetValidator.Result.Invalid)
    }

    @Test fun badVersionMetadataIsInvalid() {
        for (bad in listOf(""""version": "x"""", """"version": 0""", """"version": -1""", """"version": 1.5""")) {
            val r = DatasetValidator.validate(
                """{$bad, "entries": [{"ar": "اتفاق"}]}"""
            )
            assertTrue("version $bad must fail", r is DatasetValidator.Result.Invalid)
        }
    }

    @Test fun parseProducesDictionaryAndVocab() {
        val (dict, vocab) = DatasetValidator.parse(valid)
        assertEquals(listOf("آغاز"), dict["ابتدا"])
        assertEquals(listOf("رویداد", "پیشامد"), dict["اتفاق"])
        assertTrue(vocab.contains("ابتدا"))
        assertTrue(vocab.contains("رویداد"))
    }

    @Test fun reloadDecision_keepsUnchangedDataset() {
        // Same signature already in memory: KEEP (no per-keystroke reload)
        assertEquals(
            DatasetValidator.Source.KEEP,
            DatasetValidator.decide("u|123|456", true, "u|123|456", false)
        )
        // New signature: reload the updated file
        assertEquals(
            DatasetValidator.Source.UPDATED,
            DatasetValidator.decide("u|999|456", true, "u|123|456", false)
        )
    }

    @Test fun reloadDecision_corruptUpdateFallsBackToBundled() {
        assertEquals(
            DatasetValidator.Source.BUNDLED,
            DatasetValidator.decide("u|1|1", false, "u|123|456", false)
        )
        // already on the bundled asset: nothing to do
        assertEquals(
            DatasetValidator.Source.KEEP,
            DatasetValidator.decide("u|1|1", false, DatasetValidator.BUNDLED_SIG, false)
        )
    }

    @Test fun reloadDecision_noUpdatedFile() {
        assertEquals(
            DatasetValidator.Source.KEEP,
            DatasetValidator.decide(null, false, DatasetValidator.BUNDLED_SIG, false)
        )
        assertEquals(
            DatasetValidator.Source.BUNDLED,
            DatasetValidator.decide(null, false, null, false)
        )
    }

    @Test fun reloadDecision_forceReloads() {
        assertEquals(
            DatasetValidator.Source.UPDATED,
            DatasetValidator.decide("u|123|456", true, "u|123|456", true)
        )
        assertEquals(
            DatasetValidator.Source.BUNDLED,
            DatasetValidator.decide(null, false, DatasetValidator.BUNDLED_SIG, true)
        )
    }
}

class ImeSettingsTest {
    @Test fun heightChangeNeedsRebuild() {
        val old = ImeSettings.Snapshot("tall", true, true)
        val new = ImeSettings.Snapshot("short", true, true)
        assertTrue(ImeSettings.needsRebuild(old, new))
    }

    @Test fun correctionToggleNeedsRebuild() {
        val old = ImeSettings.Snapshot("tall", true, true)
        val new = ImeSettings.Snapshot("tall", false, true)
        assertTrue(ImeSettings.needsRebuild(old, new))
    }

    @Test fun unchangedSettingsNeedNoRebuild() {
        val s = ImeSettings.Snapshot("normal", false, false)
        assertFalse(ImeSettings.needsRebuild(s, s))
    }

    @Test fun firstActivationAlwaysRebuilds() {
        val s = ImeSettings.Snapshot("normal", true, true)
        assertTrue(ImeSettings.needsRebuild(null, s))
    }
}
