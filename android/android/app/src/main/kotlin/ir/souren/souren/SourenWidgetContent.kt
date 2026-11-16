package ir.souren.souren

import java.util.Calendar
import java.util.Locale

internal data class SourenWidgetCopy(
    val title: String,
    val body: String,
    val detail: String,
    val footer: String,
    val progress: Int = -1,
    val action: String,
)

internal object SourenWidgetContent {
    private fun Map<String, Any?>.text(key: String, fallback: String = ""): String =
        this[key]?.toString()?.takeIf { it.isNotBlank() } ?: fallback

    private fun Map<String, Any?>.number(key: String): Int =
        (this[key] as? Number)?.toInt() ?: 0

    private fun digits(value: String): String {
        val western = "0123456789"
        val persian = "۰۱۲۳۴۵۶۷۸۹"
        return value.map { char ->
            val index = western.indexOf(char)
            if (index >= 0) persian[index] else char
        }.joinToString("")
    }

    private fun n(value: Int): String = digits(value.coerceAtLeast(0).toString())

    private fun dateKey(calendar: Calendar): String =
        String.format(
            Locale.US,
            "%04d-%02d-%02d",
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )

    private fun todayKey(): String = dateKey(Calendar.getInstance())

    private fun weekStartKey(): String {
        val calendar = Calendar.getInstance()
        val mondayOffset = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7
        calendar.add(Calendar.DAY_OF_MONTH, -mondayOffset)
        return dateKey(calendar)
    }

    private fun isToday(values: Map<String, Any?>): Boolean =
        values.text("snapshotDate") == todayKey()

    private fun isThisWeek(values: Map<String, Any?>): Boolean =
        values.text("snapshotWeekStart") == weekStartKey()

    private fun hasRecentActivity(values: Map<String, Any?>): Boolean {
        val calendar = Calendar.getInstance()
        val today = dateKey(calendar)
        calendar.add(Calendar.DAY_OF_MONTH, -1)
        val yesterday = dateKey(calendar)
        val last = values.text("lastActiveDay")
        return last == today || last == yesterday
    }

    internal fun wordDayIndex(size: Int, year: Int, month: Int, day: Int): Int {
        if (size <= 0) return -1
        return Math.floorMod(year * 372 + month * 31 + day, size)
    }

    private fun wordOfDay(values: Map<String, Any?>): Pair<String, String>? {
        val catalog = values["wordCatalog"] as? List<*> ?: return null
        if (catalog.isEmpty()) return null
        val calendar = Calendar.getInstance()
        val index = wordDayIndex(
            catalog.size,
            calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1,
            calendar.get(Calendar.DAY_OF_MONTH),
        )
        val item = catalog.getOrNull(index) as? Map<*, *> ?: return null
        val arabic = item["arabic"]?.toString().orEmpty()
        val meaning = item["meaning"]?.toString().orEmpty()
        return if (arabic.isNotBlank()) arabic to meaning else null
    }

    private data class EventDefinition(
        val title: String,
        val description: String,
        val metricLabel: String,
        val target: Int,
        val metricKey: String,
    )

    private fun currentEvent(values: Map<String, Any?>): Pair<EventDefinition, Int> {
        val calendar = Calendar.getInstance()
        val mondayOffset = (calendar.get(Calendar.DAY_OF_WEEK) + 5) % 7
        val weekStartDay = calendar.get(Calendar.DAY_OF_YEAR) - mondayOffset
        val weekIndex = (weekStartDay - 1) / 7
        val definitions = listOf(
            EventDefinition("هفتهٔ دقت", "در طول هفته ۱۵ پاسخ درست ثبت کن.", "پاسخ درست", 15, "weeklyCorrectAnswers"),
            EventDefinition("هفتهٔ پیوستگی", "در چهار روز متفاوت فعالیت آموزشی داشته باش.", "روز فعال", 4, "weeklyActiveDays"),
            EventDefinition("هفتهٔ مرحله‌ها", "سه درس را در همین هفته کامل کن.", "درس", 3, "weeklyLessons"),
            EventDefinition("هفتهٔ کاوش", "۱۵ تمرین از گروه‌های موضوعی انجام بده.", "تمرین موضوعی", 15, "weeklyTopicAnswers"),
        )
        val definition = definitions[Math.abs(weekIndex) % definitions.size]
        val progress = if (isThisWeek(values)) values.number(definition.metricKey) else 0
        return definition to progress
    }

    fun build(kind: String, values: Map<String, Any?>): SourenWidgetCopy {
        return when (kind) {
            "word_day" -> {
                val word = wordOfDay(values)
                SourenWidgetCopy(
                    "واژهٔ روز",
                    word?.first ?: values.text("wordDayArabic", "سورن"),
                    word?.second ?: values.text("wordDayMeaning", "برای دریافت واژه، برنامه را باز کن"),
                    "واژهٔ امروز · تمرین",
                    action = "word_day",
                )
            }
            "flashcard" -> SourenWidgetCopy(
                "فلش‌کارت واژگان",
                values.text("flashcardArabic", "فلش‌کارت آماده نیست"),
                values.text("flashcardMeaning", "پس از ثبت واژه‌ها، کارت‌ها اینجا نمایش داده می‌شوند"),
                "نمایش کارت و ثبت مرور",
                action = "flashcard",
            )
            "continue_lesson" -> {
                val completed = values.number("completedLessons")
                val total = values.number("lessonCount")
                SourenWidgetCopy(
                    "ادامهٔ درس",
                    values.text("continueLessonTitle", "مسیر یادگیری"),
                    "درس ${n(values.number("continueLessonNumber"))} · ${n(completed)} از ${n(total)} درس",
                    "بازگشت به مسیر یادگیری",
                    values.number("lessonProgress").coerceIn(0, 100),
                    "continue_lesson",
                )
            }
            "smart_review" -> {
                val due = values.number("reviewDueCount")
                SourenWidgetCopy(
                    "مرور هوشمند",
                    if (due == 0) "مروری سررسید نشده" else "${n(due)} واژه برای مرور",
                    "مرور فاصله‌دار بر اساس زمان‌بندی شخصی",
                    "باز کردن مرور هوشمند",
                    if (due == 0) 0 else 100,
                    "smart_review",
                )
            }
            "daily_goal" -> {
                val today = isToday(values)
                val done = if (today) values.number("dailyGoalProgress") else 0
                val target = values.number("dailyGoalTarget").coerceAtLeast(1)
                SourenWidgetCopy(
                    "هدف روزانه",
                    "${n(done)} از ${n(target)} مأموریت",
                    if (today) values.text("dailyGoalNext", "هدف‌های امروز") else "یک درس کامل کن",
                    if (done >= target) "همهٔ مأموریت‌ها کامل شدند" else "یک قدم دیگر بردار",
                    (done * 100 / target).coerceIn(0, 100),
                    "daily_goal",
                )
            }
            "quick_challenge" -> SourenWidgetCopy(
                "چالش سریع",
                "Daily Boss",
                "بهترین امتیاز امروز: ${n(if (isToday(values)) values.number("quickChallengeBestToday") else 0)}",
                "شروع چالش ۳۰ ثانیه‌ای",
                action = "quick_challenge",
            )
            "records" -> SourenWidgetCopy(
                "رکوردها و دستاوردها",
                "استریک: ${n(if (hasRecentActivity(values)) values.number("currentStreak") else 0)} روز · بهترین: ${n(values.number("bestStreak"))}",
                "زنجیرهٔ پاسخ ${n(values.number("bestAnswerStreak"))} · غول روزانه ${n(values.number("bestDailyBossScore"))} · شبح ${n(values.number("bestGhostScore"))}",
                "${n(values.number("achievementCount"))} دستاورد بازشده",
                action = "records",
            )
            "weekly_report" -> {
                val currentWeek = isThisWeek(values)
                SourenWidgetCopy(
                    "گزارش هفتگی",
                    "${n(if (currentWeek) values.number("weeklyActiveDays") else 0)} روز فعال · ${n(if (currentWeek) values.number("weeklyLessons") else 0)} درس",
                    "${n(if (currentWeek) values.number("weeklyAnswers") else 0)} پاسخ · ${n(if (currentWeek) values.number("weeklyCorrectAnswers") else 0)} پاسخ درست",
                    "گزارش این هفته",
                    action = "weekly_report",
                )
            }
            "active_event" -> {
                val currentWeek = isThisWeek(values)
                val (definition, currentProgress) = currentEvent(values)
                val progress = if (currentWeek) values.number("eventProgress") else currentProgress
                val target = if (currentWeek) values.number("eventTarget") else definition.target
                val title = if (currentWeek) values.text("eventTitle", definition.title) else definition.title
                val description = if (currentWeek) values.text("eventDescription", definition.description) else definition.description
                val metric = if (currentWeek) values.text("eventMetricLabel", definition.metricLabel) else definition.metricLabel
                val percent = if (currentWeek) {
                    (values["eventPercent"] as? Number)?.toDouble()?.times(100)?.toInt()?.coerceIn(0, 100)
                        ?: if (target > 0) (progress * 100 / target).coerceIn(0, 100) else 0
                } else if (target > 0) (progress * 100 / target).coerceIn(0, 100) else 0
                SourenWidgetCopy(
                    "رویداد فعال",
                    title,
                    description,
                    "${n(progress)} از ${n(target)} · $metric",
                    percent,
                    "active_event",
                )
            }
            else -> SourenWidgetCopy(
                "سورن",
                "ویجت آماده نیست",
                "برای تازه‌سازی، برنامه را باز کن",
                "اطلاعات محلی",
                action = "home",
            )
        }
    }

    fun compactProgress(value: Int): Int = value.coerceIn(0, 100)
    fun supportsExpandedDetails(widthDp: Int, heightDp: Int): Boolean =
        widthDp >= 180 && heightDp >= 120
}
