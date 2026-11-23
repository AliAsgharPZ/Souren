package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DatasetValidatorTest {
    private val valid = """{"version":2,"entries":[{"ar":"ابتدا","fa":["آغاز"]},{"ar":"اتفاق","fa":["رویداد"]}]}"""

    @Test fun validDatasetParses() {
        assertTrue(DatasetValidator.validate(valid, strictFa = true) is DatasetValidator.Result.Valid)
        val (dictionary, vocab) = DatasetValidator.parse(valid)
        assertEquals(listOf("آغاز"), dictionary["ابتدا"])
        assertTrue(vocab.contains("رویداد"))
    }

    @Test fun malformedOrStructurallyInvalidUpdatesAreRejected() {
        assertTrue(DatasetValidator.validate("{broken", strictFa = true) is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("""{"entries":"wrong"}""", strictFa = true) is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("""{"entries":[]}""", strictFa = true) is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("""{"entries":[{"ar":"اتفاق","fa":[3]}]}""", strictFa = true) is DatasetValidator.Result.Invalid)
        assertTrue(DatasetValidator.validate("""{"entries":[{"ar":"اتفاق","fa":[]},{"ar":"اتفاق","fa":[]}]}""", strictFa = true) is DatasetValidator.Result.Invalid)
    }

    @Test fun contentSignatureDetectsSameLengthReplacement() {
        val first = """{"entries":[{"ar":"باد"}]}"""
        val second = """{"entries":[{"ar":"نان"}]}"""
        assertEquals(first.length, second.length)
        assertFalse(DatasetValidator.signature(first) == DatasetValidator.signature(second))
    }

    @Test fun unchangedUpdateKeepsCachedDataset() {
        val signature = DatasetValidator.signature(valid)
        assertEquals(DatasetValidator.Source.KEEP, DatasetValidator.decide(signature, true, signature, false))
    }

    @Test fun changedUpdateAndForcedReloadAreSelected() {
        assertEquals(DatasetValidator.Source.UPDATED, DatasetValidator.decide("new", true, "old", false))
        assertEquals(DatasetValidator.Source.UPDATED, DatasetValidator.decide("same", true, "same", true))
    }

    @Test fun corruptUpdateFallsBackToBundled() {
        assertEquals(DatasetValidator.Source.BUNDLED, DatasetValidator.decide("bad", false, "old", false))
        assertEquals(DatasetValidator.Source.KEEP, DatasetValidator.decide("bad", false, DatasetValidator.BUNDLED_SIG, false))
    }

    @Test fun removedUpdateReturnsToBundledDataset() {
        assertEquals(DatasetValidator.Source.BUNDLED, DatasetValidator.decide(null, false, "u|sha256|old", false))
        assertEquals(DatasetValidator.Source.KEEP, DatasetValidator.decide(null, false, DatasetValidator.BUNDLED_SIG, false))
    }
}
