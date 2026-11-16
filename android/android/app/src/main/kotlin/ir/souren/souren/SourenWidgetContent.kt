package ir.souren.souren

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

    fun build(kind: String, values: Map<String, Any?>): SourenWidgetCopy {
        return when (kind) {
            "word_day" -> SourenWidgetCopy(
                "واژهٔ روز",
                values.text("wordDayArabic", "سورن"),
                values.text("wordDayMeaning", "برای دریافت واژه، برنامه را باز کن"),
                "واژهٔ امروز · تمرین",
                action = "word_day",
            )
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
                val done = values.number("dailyGoalProgress")
                val target = values.number("dailyGoalTarget").coerceAtLeast(1)
                SourenWidgetCopy(
                    "هدف روزانه",
                    "${n(done)} از ${n(target)} مأموریت",
                    values.text("dailyGoalNext", "هدف‌های امروز"),
                    if (done >= target) "همهٔ مأموریت‌ها کامل شدند" else "یک قدم دیگر بردار",
                    (done * 100 / target).coerceIn(0, 100),
                    "daily_goal",
                )
            }
            "quick_challenge" -> SourenWidgetCopy(
                "چالش سریع",
                "Daily Boss",
                "بهترین امتیاز امروز: ${n(values.number("quickChallengeBestToday"))}",
                "شروع چالش ۳۰ ثانیه‌ای",
                action = "quick_challenge",
            )
            "records" -> SourenWidgetCopy(
                "رکوردها و دستاوردها",
                "استریک: ${n(values.number("currentStreak"))} روز · بهترین: ${n(values.number("bestStreak"))}",
                "زنجیرهٔ پاسخ ${n(values.number("bestAnswerStreak"))} · غول روزانه ${n(values.number("bestDailyBossScore"))} · شبح ${n(values.number("bestGhostScore"))}",
                "${n(values.number("achievementCount"))} دستاورد بازشده",
                action = "records",
            )
            "weekly_report" -> SourenWidgetCopy(
                "گزارش هفتگی",
                "${n(values.number("weeklyActiveDays"))} روز فعال · ${n(values.number("weeklyLessons"))} درس",
                "${n(values.number("weeklyAnswers"))} پاسخ · ${n(values.number("weeklyCorrectAnswers"))} پاسخ درست",
                "گزارش این هفته",
                action = "weekly_report",
            )
            "active_event" -> {
                val progress = values.number("eventProgress")
                val target = values.number("eventTarget")
                SourenWidgetCopy(
                    "رویداد فعال",
                    values.text("eventTitle", "رویداد هفتگی"),
                    values.text("eventDescription", "پیشرفت رویداد روی همین دستگاه ثبت می‌شود"),
                    "${n(progress)} از ${n(target)} · ${values.text("eventMetricLabel", "پیشرفت")}",
                    (values["eventPercent"] as? Number)?.toDouble()?.times(100)?.toInt()?.coerceIn(0, 100)
                        ?: if (target > 0) (progress * 100 / target).coerceIn(0, 100) else 0,
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
