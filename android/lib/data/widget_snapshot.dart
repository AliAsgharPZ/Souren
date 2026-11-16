import 'ario_gamification.dart';
import 'ario_lab.dart';

/// Compact, local-only materialized view consumed by Android home-screen widgets.
class SourenWidgetSnapshot {
  final Map<String, dynamic> values;

  const SourenWidgetSnapshot._(this.values);

  Map<String, dynamic> toJson() => Map<String, dynamic>.unmodifiable(values);

  static SourenWidgetSnapshot build({
    required List<({String arabic, String meaning})> words,
    required int nextLesson,
    required String nextLessonTitle,
    required int completedLessons,
    required int lessonCount,
    required int bestAnswerStreak,
    required Set<String> knownWords,
    required Set<String> reviewWords,
    required ArioGamificationState game,
    required ArioLabState lab,
    required String theme,
    DateTime? now,
  }) {
    final date = now ?? DateTime.now();
    final dailyWord = words.isEmpty
        ? null
        : words[(date.year * 372 + date.month * 31 + date.day) % words.length];
    final reviewPool = <String>{...knownWords, ...reviewWords, ...lab.cards.keys};
    final dueIds = lab.dueWordIds(reviewPool, now: date);
    final byId = {for (final word in words) word.arabic: word};
    final flashcardId = dueIds.isNotEmpty
        ? dueIds.first
        : reviewPool.isNotEmpty
            ? (reviewPool.toList()..sort()).first
            : null;
    final flashcard = flashcardId == null ? null : byId[flashcardId];
    final missions = game.dailyMissions(date);
    final completedMissions = missions.where((mission) => mission.complete).length;
    final weekly = game.weeklySummary(date);
    final event = game.offlineEvent(date);
    final progress = lessonCount <= 0
        ? 0
        : (completedLessons * 100 / lessonCount).round().clamp(0, 100);
    return SourenWidgetSnapshot._({
      'schemaVersion': 1,
      'updatedAt': date.millisecondsSinceEpoch,
      'theme': theme == 'dark' ? 'dark' : 'light',
      'wordDayArabic': dailyWord?.arabic ?? '',
      'wordDayMeaning': dailyWord?.meaning ?? '',
      'flashcardArabic': flashcard?.arabic ?? '',
      'flashcardMeaning': flashcard?.meaning ?? '',
      'continueLessonNumber': nextLesson + 1,
      'continueLessonTitle': nextLessonTitle,
      'lessonProgress': progress,
      'completedLessons': completedLessons,
      'lessonCount': lessonCount,
      'reviewDueCount': dueIds.length,
      'dailyGoalProgress': completedMissions,
      'dailyGoalTarget': missions.length,
      'dailyGoalNext': missions.firstWhere(
        (mission) => !mission.complete,
        orElse: () => missions.last,
      ).title,
      'quickChallengeBestToday': game.dailyRecord(date).dailyBossBest,
      'currentStreak': game.streakOn(date),
      'bestStreak': game.bestStreak,
      'bestAnswerStreak': bestAnswerStreak,
      'bestDailyBossScore': game.bestDailyBossScore,
      'bestGhostScore': game.bestGhostScore,
      'achievementCount': game.unlockedAchievements.length,
      'weeklyActiveDays': weekly.activeDays,
      'weeklyLessons': weekly.lessons,
      'weeklyAnswers': weekly.answers,
      'weeklyCorrectAnswers': weekly.correctAnswers,
      'eventTitle': event.title,
      'eventDescription': event.description,
      'eventMetricLabel': event.metricLabel,
      'eventProgress': event.progress,
      'eventTarget': event.target,
      'eventPercent': event.fraction,
    });
  }
}
