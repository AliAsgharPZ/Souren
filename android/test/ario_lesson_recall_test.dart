import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/ario_curriculum.dart';
import 'package:souren/data/store.dart';
import 'package:souren/main.dart' as app;

void main() {
  testWidgets('Persian-to-Arabic recall accepts normalized typed Arabic and records progress',
      (tester) async {
    var completed = false;
    Set<String> reviewed = {};
    Set<String> missed = {};
    final words = [const Entry('سلام', ['درود'])];
    final pool = [...words, const Entry('کتاب', ['دفتر'])];

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              await Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => app.ArioLessonPage(
                    lesson: 1,
                    stageTitle: 'مرحلهٔ یک',
                    unitTitle: 'واحد یک',
                    words: words,
                    exercisePool: pool,
                    exercises: const [
                      ArioExercisePlan(
                        id: 'typed-recall',
                        type: 'persian_to_arabic_recall',
                        entryId: 'سلام',
                      ),
                    ],
                    onResult: (seen, wrong) async {
                      reviewed = {...seen};
                      missed = {...wrong};
                    },
                    onComplete: () async => completed = true,
                  ),
                ),
              );
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

    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'سَلام');
    await tester.tap(find.text('بررسی پاسخ'));
    await tester.pumpAndSettle();
    expect(find.text('پاسخ درست است.'), findsOneWidget);

    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();
    expect(completed, isTrue);
    expect(reviewed, {'سلام'});
    expect(missed, isEmpty);
  });
}
