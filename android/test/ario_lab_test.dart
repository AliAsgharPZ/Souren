import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/ario_lab.dart';
import 'package:souren/data/ario_lab.dart';
import 'package:souren/data/store.dart';

void main() {
  group('Ario spaced review', () {
    final now = DateTime(2026, 11, 16, 9);

    test('new words are due immediately and a good answer schedules the next day', () {
      final state = ArioLabState();
      state.ensureWords(['كتاب', 'مدرسة'], now: now);

      expect(state.dueWordIds(['كتاب', 'مدرسة'], now: now), ['كتاب', 'مدرسة']);

      state.rateWord('كتاب', ArioReviewRating.good, now: now);

      expect(state.dueWordIds(['كتاب', 'مدرسة'], now: now), ['مدرسة']);
      expect(
        state.dueWordIds(['كتاب'], now: now.add(const Duration(hours: 23))),
        isEmpty,
      );
      expect(
        state.dueWordIds(['كتاب'], now: now.add(const Duration(days: 1))),
        ['كتاب'],
      );
      expect(state.cards['كتاب']!.intervalMinutes, 1440);
      expect(state.cards['كتاب']!.repetitions, 1);
    });

    test('again schedules a short retry and tracks a lapse', () {
      final state = ArioLabState();
      state.ensureWords(['قلم'], now: now);
      state.rateWord('قلم', ArioReviewRating.again, now: now);

      final card = state.cards['قلم']!;
      expect(card.intervalMinutes, 10);
      expect(card.lapses, 1);
      expect(card.repetitions, 0);
      expect(state.dueWordIds(['قلم'], now: now), isEmpty);
      expect(
        state.dueWordIds(['قلم'], now: now.add(const Duration(minutes: 10))),
        ['قلم'],
      );
    });

    test('hard and easy ratings adjust the ease factor in opposite directions', () {
      final state = ArioLabState();
      state.ensureWords(['باب', 'بيت'], now: now);
      state.rateWord('باب', ArioReviewRating.hard, now: now);
      state.rateWord('بيت', ArioReviewRating.easy, now: now);

      expect(state.cards['باب']!.easeFactor, lessThan(2.5));
      expect(state.cards['بيت']!.easeFactor, greaterThan(2.5));
      expect(state.cards['باب']!.intervalMinutes, 720);
      expect(state.cards['بيت']!.intervalMinutes, 5760);
    });

    test('review schedules and laboratory counters survive JSON round-trip', () {
      final state = ArioLabState();
      state.ensureWords(['نور'], now: now);
      state.rateWord('نور', ArioReviewRating.easy, now: now);
      state.recordQuiz(answers: 10, correct: 7, mixed: false);
      state.recordQuiz(answers: 12, correct: 9, mixed: true);
      state.recordQuiz(answers: 12, correct: 8, mixed: true);
      state.recordFlashcardReview();
      state.recordExplorerSearch();

      final restored = ArioLabState.fromJson(state.toJson());

      expect(restored.cards['نور']!.dueAt, state.cards['نور']!.dueAt);
      expect(restored.cards['نور']!.reviews, 1);
      expect(restored.freePracticeSessions, 1);
      expect(restored.mixedChallengeAttempts, 2);
      expect(restored.bestMixedScore, 75);
      expect(restored.flashcardsReviewed, 1);
      expect(restored.explorerSearches, 1);
    });

    test('malformed saved state falls back safely', () {
      final state = ArioLabState.fromJson({
        'cards': {'broken': 'not a card'},
        'bestMixedScore': 900,
        'freePracticeSessions': -4,
      });

      expect(state.cards['broken']!.wordId, 'broken');
      expect(state.bestMixedScore, 100);
      expect(state.freePracticeSessions, 0);
    });
  });

  testWidgets('free practice completes a local round and reports its answers', (tester) async {
    final entries = [
      const Entry('كتاب', ['کتاب']),
      const Entry('مدرسة', ['مدرسه']),
      const Entry('قلم', ['قلم']),
    ];
    var answered = 0;
    var finishedAnswers = 0;
    var finishedCorrect = -1;
    var mixed = true;

    await tester.pumpWidget(MaterialApp(
      home: ArioLabQuizPage(
        entries: entries,
        title: 'تمرین آزاد واژگان',
        onAnswered: (_, __) => answered++,
        onFinished: (answers, correct, isMixed) async {
          finishedAnswers = answers;
          finishedCorrect = correct;
          mixed = isMixed;
        },
        backgroundColor: Colors.white,
        cardColor: const Color(0xffeeeeee),
        pillColor: const Color(0xffdddddd),
        textColor: Colors.black,
        mutedColor: Colors.grey,
        selectedColor: Colors.blue,
        accentColor: Colors.red,
        dividerColor: Colors.black12,
      ),
    ));

    await tester.tap(find.text('شروع تمرین'));
    await tester.pumpAndSettle();

    for (var index = 0; index < entries.length; index++) {
      await tester.tap(find.byType(OutlinedButton).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text(index + 1 == entries.length ? 'دیدن نتیجه' : 'پرسش بعدی'));
      await tester.pumpAndSettle();
    }

    expect(answered, entries.length);
    expect(finishedAnswers, entries.length);
    expect(finishedCorrect, inInclusiveRange(0, entries.length));
    expect(mixed, isFalse);
    expect(find.text('نتیجهٔ دور'), findsOneWidget);
  });

  testWidgets('smart review reveals the local card and applies the selected rating', (tester) async {
    final now = DateTime.now();
    final state = ArioLabState()..ensureWords(['كتاب'], now: now);
    ArioReviewRating? selectedRating;

    await tester.pumpWidget(MaterialApp(
      home: ArioLabReviewPage(
        entries: const [Entry('كتاب', ['کتاب'], concept: 'مجموعه‌ای از برگه‌های نوشته‌شده.')],
        reviewState: state,
        onRated: (wordId, rating) async {
          expect(wordId, 'كتاب');
          selectedRating = rating;
          state.rateWord(wordId, rating, now: now);
        },
        backgroundColor: Colors.white,
        cardColor: const Color(0xffeeeeee),
        textColor: Colors.black,
        mutedColor: Colors.grey,
        selectedColor: Colors.blue,
        accentColor: Colors.red,
        dividerColor: Colors.black12,
      ),
    ));

    expect(find.text('كتاب'), findsOneWidget);
    expect(find.text('کتاب'), findsNothing);
    await tester.tap(find.text('نمایش پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('کتاب'), findsOneWidget);

    await tester.tap(find.text('خوب'));
    await tester.pumpAndSettle();

    expect(selectedRating, ArioReviewRating.good);
    expect(find.text('مرور این نوبت تمام شد.'), findsOneWidget);
  });
}
