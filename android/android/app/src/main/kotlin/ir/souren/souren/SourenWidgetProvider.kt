package ir.souren.souren

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.view.View
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File

abstract class SourenWidgetProvider : AppWidgetProvider() {
    protected abstract val widgetKind: String

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        appWidgetIds.forEach { render(context, appWidgetManager, it, widgetKind) }
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        render(context, appWidgetManager, appWidgetId, widgetKind)
    }

    companion object {
        private val providers = listOf(
            SourenWordDayWidget::class.java to "word_day",
            SourenFlashcardWidget::class.java to "flashcard",
            SourenContinueLessonWidget::class.java to "continue_lesson",
            SourenSmartReviewWidget::class.java to "smart_review",
            SourenDailyGoalWidget::class.java to "daily_goal",
            SourenQuickChallengeWidget::class.java to "quick_challenge",
            SourenRecordsWidget::class.java to "records",
            SourenWeeklyReportWidget::class.java to "weekly_report",
            SourenActiveEventWidget::class.java to "active_event",
        )

        fun refreshAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            providers.forEach { (provider, kind) ->
                val component = ComponentName(context, provider)
                val ids = manager.getAppWidgetIds(component)
                ids.forEach { render(context, manager, it, kind) }
            }
        }

        private fun readSnapshot(context: Context): Map<String, Any?> {
            return try {
                val file = File(context.filesDir, "souren_widgets.json")
                if (!file.isFile) return emptyMap()
                val json = JSONObject(file.readText(Charsets.UTF_8))
                json.keys().asSequence().associateWith { key ->
                    json.opt(key).let { if (it == JSONObject.NULL) null else it }
                }
            } catch (_: Exception) {
                emptyMap()
            }
        }

        private fun render(
            context: Context,
            manager: AppWidgetManager,
            widgetId: Int,
            kind: String,
        ) {
            val copy = SourenWidgetContent.build(kind, readSnapshot(context))
            val options = manager.getAppWidgetOptions(widgetId)
            val width = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 110)
            val height = options.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 80)
            val expanded = SourenWidgetContent.supportsExpandedDetails(width, height)
            val views = RemoteViews(context.packageName, R.layout.souren_widget)

            views.setTextViewText(R.id.widget_title, copy.title)
            views.setTextViewText(R.id.widget_body, copy.body)
            views.setTextViewText(R.id.widget_detail, copy.detail)
            views.setTextViewText(R.id.widget_footer, copy.footer)
            views.setTextColor(R.id.widget_title, context.getColor(R.color.widget_title))
            views.setTextColor(R.id.widget_body, context.getColor(R.color.widget_text))
            views.setTextColor(R.id.widget_detail, context.getColor(R.color.widget_muted))
            views.setTextColor(R.id.widget_footer, context.getColor(R.color.widget_accent))
            views.setInt(R.id.widget_root, "setBackgroundResource", R.drawable.souren_widget_background)
            views.setViewVisibility(
                R.id.widget_detail,
                if (expanded) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_footer,
                if (height >= 100) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_progress,
                if (copy.progress >= 0 && height >= 100) View.VISIBLE else View.GONE,
            )
            if (copy.progress >= 0) {
                views.setProgressBar(
                    R.id.widget_progress,
                    100,
                    SourenWidgetContent.compactProgress(copy.progress),
                    false,
                )
            }
            views.setTextViewTextSize(R.id.widget_title, 0, if (width < 150) 12f else 13f)
            views.setTextViewTextSize(R.id.widget_body, 0, if (width < 150) 17f else 20f)
            views.setTextViewTextSize(R.id.widget_detail, 0, 11f)

            val intent = Intent(context, ArioActivity::class.java).apply {
                action = "ir.souren.souren.WIDGET_OPEN"
                putExtra("souren_widget_action", copy.action)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            val pendingIntent = PendingIntent.getActivity(
                context,
                widgetId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            views.setOnClickPendingIntent(R.id.widget_root, pendingIntent)
            manager.updateAppWidget(widgetId, views)
        }
    }
}

class SourenWordDayWidget : SourenWidgetProvider() { override val widgetKind = "word_day" }
class SourenFlashcardWidget : SourenWidgetProvider() { override val widgetKind = "flashcard" }
class SourenContinueLessonWidget : SourenWidgetProvider() { override val widgetKind = "continue_lesson" }
class SourenSmartReviewWidget : SourenWidgetProvider() { override val widgetKind = "smart_review" }
class SourenDailyGoalWidget : SourenWidgetProvider() { override val widgetKind = "daily_goal" }
class SourenQuickChallengeWidget : SourenWidgetProvider() { override val widgetKind = "quick_challenge" }
class SourenRecordsWidget : SourenWidgetProvider() { override val widgetKind = "records" }
class SourenWeeklyReportWidget : SourenWidgetProvider() { override val widgetKind = "weekly_report" }
class SourenActiveEventWidget : SourenWidgetProvider() { override val widgetKind = "active_event" }
