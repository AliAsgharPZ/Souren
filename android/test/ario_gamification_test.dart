import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_gamification.dart';

void main() {
  group('Ario daily activity and streaks', () {
    test('multiple activities on one day count as one streak day', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 1), lessons: 1);
      state.recordActivity(DateTime(2026, 11, 1), answers: 4, correctAnswers: 3);
      state.recordActivity(DateTime(2026, 11, 2), answers: 2, correctAnswers: 2);

      expect(state.currentStreak, 2);
      expect(state.bestStreak, 2);
      expect(state.recordFor(DateTime(2026, 11, 1)).lessons, 1);
      expect(state.recordFor(DateTime(2026, 11, 1)).answers, 4);
      expect(state.recordFor(DateTime(2026, 11, 1)).correctAnswers, 3);
    });

    test('a missed calendar day restarts the current streak but keeps the record', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 1), lessons: 1);
      state.recordActivity(DateTime(2026, 11, 2), lessons: 1);
      state.recordActivity(DateTime(2026, 11, 4), lessons: 1);

      expect(state.currentStreak, 1);
      expect(state.streakOn(DateTime(2026, 11, 4)), 1);
      expect(state.streakOn(DateTime(2026, 11, 7)), 0);
      expect(state.bestStreak, 2);
    });

    test('zero-value activity cannot create a streak day', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 1));
      expect(state.currentStreak, 0);
      expect(state.lastActiveDay, isNull);
    });
  });

  group('Daily missions and offline records', () {
    test('daily missions reflect lesson, practice and Daily Boss progress', () {
      final state = ArioGamificationState();
      final today = DateTime(2026, 11, 15);
      state.recordActivity(today, lessons: 1, answers: 3, correctAnswers: 2);
      state.recordDailyBoss(today, 7);

      final missions = state.dailyMissions(today);
      expect(missions.map((item) => item.id), ['lesson', 'practice', 'boss']);
      expect(missions.map((item) => item.complete), [true, false, true]);
      expect(state.completedDailyMissionsFor(today), 2);
      expect(state.recordFor(today).dailyBossBest, 7);
    });

    test('Daily Boss keeps daily and all-time personal bests', () {
      final state = ArioGamificationState();
      state.recordDailyBoss(DateTime(2026, 11, 14), 9);
      state.recordDailyBoss(DateTime(2026, 11, 14), 6);
      state.recordDailyBoss(DateTime(2026, 11, 15), 12);

      expect(state.recordFor(DateTime(2026, 11, 14)).bossAttempts, 2);
      expect(state.recordFor(DateTime(2026, 11, 14)).dailyBossBest, 9);
      expect(state.recordFor(DateTime(2026, 11, 15)).dailyBossBest, 12);
      expect(state.bestDailyBossScore, 12);
    });

    test('ghost challenge stores only a better local personal run', () {
      final state = ArioGamificationState();
      state.recordGhostRun(DateTime(2026, 11, 14), [1, 1, 2, 3]);
      state.recordGhostRun(DateTime(2026, 11, 15), [1, 2, 2]);

      expect(state.bestGhostScore, 3);
      expect(state.ghostBestTrack, [1, 1, 2, 3]);
      expect(state.recordFor(DateTime(2026, 11, 14)).ghostAttempts, 1);
      expect(state.recordFor(DateTime(2026, 11, 15)).ghostAttempts, 1);
    });

    test('topic practice is counted separately and can unlock an achievement', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 15), answers: 15, correctAnswers: 12, topicAnswers: 15);
      state.refreshAchievements(knownWords: 0);

      expect(state.unlockedAchievements, contains('topic-fifteen'));
      expect(state.unlockedAchievements, isNot(contains('fifty-answers')));
    });
  });

  group('Reports and events', () {
    test('weekly and monthly reports aggregate only their period', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 2), lessons: 1, answers: 4, correctAnswers: 3);
      state.recordActivity(DateTime(2026, 11, 8), answers: 3, correctAnswers: 2);
      state.recordDailyBoss(DateTime(2026, 11, 8), 8);
      state.recordActivity(DateTime(2026, 10, 31), lessons: 5, answers: 8, correctAnswers: 5);

      final week = state.weeklySummary(DateTime(2026, 11, 8));
      final month = state.monthlySummary(DateTime(2026, 11, 8));

      expect(week.lessons, 1);
      expect(week.answers, 7);
      expect(week.correctAnswers, 5);
      expect(week.activeDays, 2);
      expect(week.bestBossScore, 8);
      expect(month.lessons, 1);
      expect(month.answers, 7);
      expect(month.activeDays, 2);
    });

    test('weekly offline event is deterministic and uses local history', () {
      final state = ArioGamificationState();
      final now = DateTime(2026, 11, 15);
      final before = state.offlineEvent(now);
      state.recordActivity(now, answers: 15, correctAnswers: 15);
      final after = state.offlineEvent(now);

      expect(after.id, before.id);
      expect(after.title, before.title);
      expect(after.progress, greaterThanOrEqualTo(before.progress));
      expect(after.target, greaterThan(0));
    });
  });

  group('Persistence and profile customization', () {
    test('gamification state round-trips without losing personal progress', () {
      final state = ArioGamificationState();
      state.recordActivity(DateTime(2026, 11, 14), lessons: 2, answers: 9, correctAnswers: 7, topicAnswers: 3);
      state.recordDailyBoss(DateTime(2026, 11, 14), 11);
      state.recordGhostRun(DateTime(2026, 11, 14), [1, 2, 3, 4]);
      state.setAvatar('explorer', 2);
      state.refreshAchievements(knownWords: 55);

      final restored = ArioGamificationState.fromJson(state.toJson());

      expect(restored.lastActiveDay, '2026-11-14');
      expect(restored.currentStreak, 1);
      expect(restored.bestDailyBossScore, 11);
      expect(restored.bestGhostScore, 4);
      expect(restored.ghostBestTrack, [1, 2, 3, 4]);
      expect(restored.avatarId, 'explorer');
      expect(restored.avatarTone, 2);
      expect(restored.recordFor(DateTime(2026, 11, 14)).topicAnswers, 3);
      expect(restored.unlockedAchievements, containsAll(['first-lesson', 'fifty-words', 'daily-boss-ten']));
    });

    test('unknown avatar ids fall back safely and tone is clamped', () {
      final state = ArioGamificationState.fromJson({
        'avatarId': 'remote-user-avatar',
        'avatarTone': 99,
      });
      expect(state.avatarId, 'reader');
      expect(state.avatarTone, 3);
      state.setAvatar('not-in-catalog', -4);
      expect(state.avatarId, 'reader');
      expect(state.avatarTone, 0);
    });

    test('empty or malformed saved data starts with an empty local state', () {
      expect(ArioGamificationState.fromJson(null).history, isEmpty);
      expect(ArioGamificationState.fromJson('not-json').currentStreak, 0);
    });
  });
}
