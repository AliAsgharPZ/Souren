package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Test

class CursorMathTest {
    private fun move(
        start: Int,
        end: Int,
        length: Int,
        delta: Int,
        offset: Int = 0
    ) = CursorMath.newSelection(offset, start, end, length, delta)

    @Test fun longDocumentUsesAbsoluteEditorOffsets() {
        assertEquals(260, move(261, 261, 2_000, -1))
        assertEquals(262, move(261, 261, 2_000, 1))
        assertEquals(510, move(500, 500, 2_000, 10))
    }

    @Test fun partialExtractedWindowAddsItsAbsoluteStart() {
        assertEquals(10_160, move(150, 150, 200, 10, 10_000))
        assertEquals(10_000, move(2, 2, 200, -5, 10_000))
    }

    @Test fun movementClampsToExtractedWindow() {
        assertEquals(10_200, move(195, 195, 200, 20, 10_000))
        assertEquals(10_000, move(0, 0, 200, -1, 10_000))
    }

    @Test fun selectionsCollapseTowardMovementDirection() {
        assertEquals(121, move(100, 120, 1_000, 1))
        assertEquals(99, move(100, 120, 1_000, -1))
        assertEquals(120, move(100, 120, 1_000, 0))
    }

    @Test fun endOfLongDocumentIsClamped() {
        assertEquals(100_000, move(99_999, 99_999, 100_000, 5))
        assertEquals(99_993, move(100_000, 100_000, 100_000, -7))
    }

    @Test fun unknownSelectionAndEmptyDocumentAreSafe() {
        assertEquals(5, move(-1, -1, 100, 5))
        assertEquals(0, move(-1, -1, 100, -5))
        assertEquals(0, move(0, 0, 0, 1))
    }
}
