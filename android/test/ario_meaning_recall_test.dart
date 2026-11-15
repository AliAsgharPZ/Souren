import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_curriculum.dart';
import 'package:souren/data/store.dart';
import 'package:souren/main.dart' as app;

void main() {
  testWidgets('meaning recall asks for the Arabic word matching its definition',
      (tester) async {
    var completed = false;
    final entries = [
      const Entry('كتاب', ['کتاب'], concept: 'مجموعه‌ای از برگه‌های نوشته‌شده که به هم صحافی شده‌اند.'),
      const Entry('مدرسة', ['مدرسه'], concept: 'محلی برای آموزش و یادگیری دانش‌آموزان.'),
    ];

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () {
              Navigator.of(context).push<void>(MaterialPageRoute(
                builder: (_) => app.ArioLessonPage(
                  lesson: 1,
                  stageTitle: 'مرحلهٔ یک',
                  unitTitle: 'واحد یک',
                  words: [entries.first],
                  exercisePool: entries,
                  exercises: const [
                    ArioExercisePlan(
                      id: 'meaning-1',
                      type: 'meaning_recall',
                      entryId: 'كتاب',
                    ),
                  ],
                  onComplete: () async => completed = true,
                ),
              ));
            },
            child: const Text('شروع'),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('شروع'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نمایش پاسخ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رفتن به یادآوری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نمایش پاسخ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('یادم بود'));
    await tester.pumpAndSettle();

    expect(find.text('این تعریف به کدام واژه مربوط است؟'), findsOneWidget);
    expect(find.text(entries.first.concept), findsOneWidget);
    expect(find.text('کتاب'), findsNothing);
    expect(find.text('كتاب'), findsOneWidget);

    await tester.tap(find.text('كتاب'));
    await tester.pumpAndSettle();
    expect(find.text('پاسخ درست است.'), findsOneWidget);
    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
  });
}
