package ir.souren.souren

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class SourenWidgetContentTest {
    @Test fun wordOfDayUsesLocalSnapshotAndPersianNumbers() {
        val copy = SourenWidgetContent.build(
            "word_day",
            mapOf("wordDayArabic" to "كتاب", "wordDayMeaning" to "کتاب")
        )
        assertEquals("واژهٔ روز", copy.title)
        assertEquals("كتاب", copy.body)
        assertEquals("کتاب", copy.detail)
        assertEquals("word_day", copy.action)
    }

    @Test fun lessonWidgetShowsProgressAndPersianDigits() {
        val copy = SourenWidgetContent.build(
            "continue_lesson",
            mapOf(
                "continueLessonTitle" to "ضمیرها",
                "continueLessonNumber" to 12,
                "completedLessons" to 4,
                "lessonCount" to 20,
                "lessonProgress" to 20
            )
        )
        assertEquals("ضمیرها", copy.body)
        assertEquals("درس ۱۲ · ۴ از ۲۰ درس", copy.detail)
        assertEquals(20, copy.progress)
    }

    @Test fun dailyGoalAndActiveEventClampProgress() {
        val goal = SourenWidgetContent.build(
            "daily_goal",
            mapOf("dailyGoalProgress" to 4, "dailyGoalTarget" to 3, "dailyGoalNext" to "همه کامل شدند")
        )
        assertEquals(100, goal.progress)
        assertEquals("۴ از ۳ مأموریت", goal.body)

        val event = SourenWidgetContent.build(
            "active_event",
            mapOf("eventTitle" to "هفتهٔ دقت", "eventProgress" to 7, "eventTarget" to 5, "eventPercent" to 1.4)
        )
        assertEquals(100, event.progress)
        assertEquals("هفتهٔ دقت", event.body)
    }

    @Test fun unknownWidgetHasSafeFallbackAndSizingIsResponsive() {
        val copy = SourenWidgetContent.build("unknown", emptyMap())
        assertEquals("سورن", copy.title)
        assertEquals("home", copy.action)
        assertTrue(SourenWidgetContent.supportsExpandedDetails(200, 140))
        assertFalse(SourenWidgetContent.supportsExpandedDetails(150, 140))
        assertFalse(SourenWidgetContent.supportsExpandedDetails(200, 100))
        assertEquals(100, SourenWidgetContent.compactProgress(140))
        assertEquals(0, SourenWidgetContent.compactProgress(-1))
    }
}
