import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_gamification.dart';
import 'package:souren/data/ario_lab.dart';
import 'package:souren/data/widget_snapshot.dart';

void main() {
  group('Souren Android widget snapshot', () {
    final date = DateTime(2026, 11, 16, 12);

    test('builds a stable offline word of the day and lesson shortcut', () {
      final game = ArioGamificationState();
      final snapshot = SourenWidgetSnapshot.build(
        words: const [
          (arabic: 'كتاب', meaning: 'کتاب'),
          (arabic: 'قلم', meaning: 'قلم'),
        ],
        nextLesson: 2,
        nextLessonTitle: 'ضمیرها',
        completedLessons: 2,
        lessonCount: 10,
        knownWords: {},
        reviewWords: {},
        game: game,
        lab: ArioLabState(),
        theme: 'light',
        now: date,
      ).toJson();

      final index = (date.year * 372 + date.month * 31 + date.day) % 2;
      expect(snapshot['wordDayArabic'], index == 0 ? 'كتاب' : 'قلم');
      expect(snapshot['continueLessonNumber'], 3);
      expect(snapshot['continueLessonTitle'], 'ضمیرها');
      expect(snapshot['lessonProgress'], 20);
      expect(snapshot['theme'], 'light');
    });

    test('uses the due smart-review card as the flashcard widget content', () {
      final lab = ArioLabState();
      lab.ensureWords(['قلم', 'كتاب'], now: date.subtract(const Duration(days: 1)));
      lab.rateWord('قلم', ArioReviewRating.good, now: date);
      final snapshot = SourenWidgetSnapshot.build(
        words: const [
          (arabic: 'قلم', meaning: 'نوشت‌افزار'),
          (arabic: 'كتاب', meaning: 'کتاب'),
        ],
        nextLesson: 0,
        nextLessonTitle: 'آغاز',
        completedLessons: 0,
        lessonCount: 10,
        knownWords: {'قلم'},
        reviewWords: {'قلم', 'كتاب'},
        game: ArioGamificationState(),
        lab: lab,
        theme: 'dark',
        now: date,
      ).toJson();

      expect(snapshot['reviewDueCount'], 1);
      expect(snapshot['flashcardArabic'], 'كتاب');
      expect(snapshot['flashcardMeaning'], 'کتاب');
      expect(snapshot['theme'], 'dark');
    });

    test('derives daily goal, streak, weekly report and active offline event', () {
      final game = ArioGamificationState();
      game.recordActivity(date, lessons: 1, answers: 5, correctAnswers: 4);
      game.recordActivity(date.subtract(const Duration(days: 1)), answers: 2, correctAnswers: 2);
      game.refreshAchievements(knownWords: 50, completedLessons: 1);
      final snapshot = SourenWidgetSnapshot.build(
        words: const [(arabic: 'نور', meaning: 'روشنایی')],
        nextLesson: 0,
        nextLessonTitle: 'آغاز',
        completedLessons: 1,
        lessonCount: 4,
        knownWords: {},
        reviewWords: {},
        game: game,
        lab: ArioLabState(),
        theme: 'dark',
        now: date,
      ).toJson();

      expect(snapshot['dailyGoalProgress'], 2);
      expect(snapshot['dailyGoalTarget'], 3);
      expect(snapshot['currentStreak'], 2);
      expect(snapshot['bestStreak'], 2);
      expect(snapshot['achievementCount'], greaterThan(0));
      expect(snapshot['weeklyActiveDays'], 2);
      expect(snapshot['weeklyLessons'], 1);
      expect(snapshot['weeklyAnswers'], 7);
      expect(snapshot['weeklyCorrectAnswers'], 6);
      expect(snapshot['eventTitle'], isNotEmpty);
      expect(snapshot['eventTarget'], greaterThan(0));
      expect(snapshot['eventPercent'], inInclusiveRange(0.0, 1.0));
    });

    test('handles an empty dictionary without invalid widget content', () {
      final snapshot = SourenWidgetSnapshot.build(
        words: const [],
        nextLesson: 0,
        nextLessonTitle: 'هنوز درسی موجود نیست',
        completedLessons: 0,
        lessonCount: 0,
        knownWords: {},
        reviewWords: {},
        game: ArioGamificationState(),
        lab: ArioLabState(),
        theme: 'light',
        now: date,
      ).toJson();

      expect(snapshot['wordDayArabic'], '');
      expect(snapshot['flashcardArabic'], '');
      expect(snapshot['lessonProgress'], 0);
      expect(snapshot['dailyGoalTarget'], 3);
    });
  });
}
