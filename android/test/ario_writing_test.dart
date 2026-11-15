import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/ario_writing.dart';
import 'package:souren/data/ario_curriculum.dart';

void main() {
  testWidgets('writing lesson runs learn, recall and practice in order and returns missed items',
      (tester) async {
    ArioWritingLessonResult? result;
    const lesson = ArioWritingLessonPlan(
      id: 'spelling-demo',
      title: 'املای درست',
      summary: 'آموزش نمونه برای آزمون جریان درس',
      sections: [
        ArioWritingSectionPlan(
          id: 'learn',
          title: 'آموزش',
          type: 'learn',
          content: 'قاعدهٔ املایی را با دقت بخوان.',
          examples: ['صدا', 'صبر'],
          exercises: [],
        ),
        ArioWritingSectionPlan(
          id: 'recall',
          title: 'یادآوری',
          type: 'recall',
          content: 'قاعده را از حافظه بازیابی کن.',
          examples: [],
          exercises: [
            ArioWritingExercisePlan(
              id: 'recall-1',
              prompt: 'املای درست کدام است؟',
              options: ['صدا', 'سدا', 'ثدا'],
              answer: 'صدا',
              explanation: 'این واژه با ص نوشته می‌شود.',
            ),
            ArioWritingExercisePlan(
              id: 'recall-2',
              prompt: 'کدام صورت معیار است؟',
              options: ['صبر', 'سبر', 'ثبر'],
              answer: 'صبر',
              explanation: 'این واژه با ص نوشته می‌شود.',
            ),
          ],
        ),
        ArioWritingSectionPlan(
          id: 'practice',
          title: 'تمرین',
          type: 'practice',
          content: 'قاعده را در جمله به کار ببر.',
          examples: [],
          exercises: [
            ArioWritingExercisePlan(
              id: 'practice-1',
              prompt: 'واژهٔ درست را انتخاب کن.',
              options: ['ضروری', 'زروری', 'ذروری'],
              answer: 'ضروری',
              explanation: 'این واژه با ض نوشته می‌شود.',
            ),
            ArioWritingExercisePlan(
              id: 'practice-2',
              prompt: 'صورت درست را مشخص کن.',
              options: ['ظاهر', 'ضاهر', 'زاهر'],
              answer: 'ظاهر',
              explanation: 'این واژه با ظ نوشته می‌شود.',
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await Navigator.of(context).push<ArioWritingLessonResult>(
                MaterialPageRoute(
                  builder: (_) => const ArioWritingLessonPage(
                    courseTitle: 'املای درست',
                    unitTitle: 'نویسه‌های هم‌آوا',
                    lesson: lesson,
                    backgroundColor: Colors.white,
                    cardColor: const Color(0xffeeeeee),
                    pillColor: const Color(0xffdddddd),
                    textColor: Colors.black,
                    mutedColor: Colors.grey,
                    selectedColor: Colors.blue,
                    accentColor: Colors.red,
                    dividerColor: Colors.black12,
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
    expect(find.text('قاعدهٔ املایی را با دقت بخوان.'), findsOneWidget);
    expect(find.text('صدا'), findsOneWidget);

    await tester.tap(find.text('رفتن به یادآوری'));
    await tester.pumpAndSettle();
    expect(find.text('یادآوری از حافظه'), findsOneWidget);

    await tester.tap(find.text('صدا').last);
    await tester.pump();
    await tester.tap(find.text('سؤال بعدی'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('سبر'));
    await tester.pump();
    await tester.tap(find.text('رفتن به تمرین'));
    await tester.pumpAndSettle();
    expect(find.text('به‌کارگیری آموخته'), findsOneWidget);

    await tester.tap(find.text('ضروری'));
    await tester.pump();
    await tester.tap(find.text('سؤال بعدی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ضاهر'));
    await tester.pump();
    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();

    expect(result, isNotNull);
    expect(result!.totalQuestions, 4);
    expect(result!.correctAnswers, 2);
    expect(result!.reviewedExerciseIds, {'recall-1', 'recall-2', 'practice-1', 'practice-2'});
    expect(result!.missedExerciseIds, {'recall-2', 'practice-2'});
  });
}
