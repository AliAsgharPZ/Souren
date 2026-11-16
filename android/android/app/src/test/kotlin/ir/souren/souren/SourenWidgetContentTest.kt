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

    @Test fun wordDayIndexIsStableForLocalCalendarDate() {
        val size = 7
        val expected = Math.floorMod(2026 * 372 + 11 * 31 + 16, size)
        assertEquals(expected, SourenWidgetContent.wordDayIndex(size, 2026, 11, 16))
        assertEquals(-1, SourenWidgetContent.wordDayIndex(0, 2026, 11, 16))
    }

    @Test fun wordDayWidgetSelectsFromTheCachedLocalDictionary() {
        val calendar = java.util.Calendar.getInstance()
        val index = SourenWidgetContent.wordDayIndex(
            2,
            calendar.get(java.util.Calendar.YEAR),
            calendar.get(java.util.Calendar.MONTH) + 1,
            calendar.get(java.util.Calendar.DAY_OF_MONTH)
        )
        val words = listOf(
            mapOf("arabic" to "كتاب", "meaning" to "کتاب"),
            mapOf("arabic" to "قلم", "meaning" to "قلم")
        )
        val copy = SourenWidgetContent.build("word_day", mapOf("wordCatalog" to words))
        assertEquals(words[index]["arabic"], copy.body)
        assertEquals(words[index]["meaning"], copy.detail)
    }

    @Test fun dailyAndWeeklyWidgetsResetWhenTheSavedPeriodIsOld() {
        val goal = SourenWidgetContent.build(
            "daily_goal",
            mapOf(
                "snapshotDate" to "1900-01-01",
                "dailyGoalProgress" to 3,
                "dailyGoalTarget" to 3,
                "dailyGoalNext" to "همه کامل شدند"
            )
        )
        assertEquals("۰ از ۳ مأموریت", goal.body)
        assertEquals("یک قدم دیگر بردار", goal.footer)

        val weekly = SourenWidgetContent.build(
            "weekly_report",
            mapOf(
                "snapshotWeekStart" to "1900-01-01",
                "weeklyActiveDays" to 6,
                "weeklyLessons" to 9,
                "weeklyAnswers" to 80,
                "weeklyCorrectAnswers" to 70
            )
        )
        assertEquals("۰ روز فعال · ۰ درس", weekly.body)
        assertEquals("۰ پاسخ · ۰ پاسخ درست", weekly.detail)
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

    @Test fun recordsWidgetIncludesBothStreakTypesAndAchievements() {
        val copy = SourenWidgetContent.build(
            "records",
            mapOf(
                "currentStreak" to 3,
                "bestStreak" to 8,
                "bestAnswerStreak" to 14,
                "bestDailyBossScore" to 20,
                "bestGhostScore" to 17,
                "achievementCount" to 4
            )
        )
        assertTrue(copy.body.contains("۳ روز"))
        assertTrue(copy.body.contains("۸"))
        assertTrue(copy.detail.contains("۱۴"))
        assertTrue(copy.detail.contains("۲۰"))
        assertTrue(copy.footer.contains("۴"))
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
