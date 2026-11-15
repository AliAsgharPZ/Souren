import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:souren/ario_writing.dart';
import 'package:souren/data/ario_curriculum.dart';

void main() {
  testWidgets('a missed lesson answer enters review and a correct review clears it',
      (tester) async {
    final lesson = const ArioWritingLessonPlan(
      id: 'review-demo',
      title: 'درس آزمایشی',
      summary: 'آزمون چرخهٔ مرور',
      sections: [
        ArioWritingSectionPlan(
          id: 'learn',
          title: 'آموزش',
          type: 'learn',
          content: 'قاعده را بخوان.',
          examples: ['نمونه'],
          exercises: [],
        ),
        ArioWritingSectionPlan(
          id: 'recall',
          title: 'یادآوری',
          type: 'recall',
          content: 'قاعده را به یاد بیاور.',
          examples: [],
          exercises: [
            ArioWritingExercisePlan(
              id: 'missed-question',
              prompt: 'پاسخ این سؤال چیست؟',
              options: ['جواب درست', 'گزینهٔ غلط', 'گزینهٔ سوم'],
              answer: 'جواب درست',
              explanation: 'توضیح پاسخ درست.',
            ),
          ],
        ),
        ArioWritingSectionPlan(
          id: 'practice',
          title: 'تمرین',
          type: 'practice',
          content: 'قاعده را به کار ببر.',
          examples: [],
          exercises: [
            ArioWritingExercisePlan(
              id: 'passed-question',
              prompt: 'پاسخ تمرین چیست؟',
              options: ['پاسخ صحیح تمرین', 'پاسخ نادرست', 'گزینهٔ دیگر'],
              answer: 'پاسخ صحیح تمرین',
              explanation: 'توضیح تمرین.',
            ),
          ],
        ),
      ],
    );
    const courses = [
      ArioWritingCoursePlan(
        id: 'review-course',
        title: 'املای درست',
        description: 'آزمون چرخهٔ یادگیری',
        units: [
          ArioWritingUnitPlan(
            id: 'review-unit',
            title: 'نویسه‌های هم‌آوا',
            lessons: [lesson],
          ),
        ],
      ),
    ];

    final lessonReviewed = <String>{};
    final lessonMissed = <String>{};
    final reviewReviewed = <String>{};
    final reviewMissed = <String>{};

    await tester.pumpWidget(MaterialApp(
      home: ArioWritingPage(
        courses: courses,
        completedLessonIds: const {},
        reviewDue: const {},
        onLessonCompleted: (id, reviewed, missed) async {
          lessonReviewed.addAll(reviewed);
          lessonMissed.addAll(missed);
        },
        onReviewCompleted: (reviewed, missed) async {
          reviewReviewed.addAll(reviewed);
          reviewMissed.addAll(missed);
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

    await tester.tap(find.text('املای درست'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('نویسه‌های هم‌آوا'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('درس آزمایشی'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('رفتن به یادآوری'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('گزینهٔ غلط'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('رفتن به تمرین'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پاسخ صحیح تمرین'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پایان درس'));
    await tester.pumpAndSettle();

    expect(lessonReviewed, {'missed-question', 'passed-question'});
    expect(lessonMissed, {'missed-question'});
    expect(find.text('1 تمرین برای مرور ذخیره شده است.'), findsOneWidget);

    await tester.tap(find.text('مرور پاسخ‌های دشوار'));
    await tester.pumpAndSettle();
    expect(find.text('پاسخ این سؤال چیست؟'), findsOneWidget);
    await tester.tap(find.text('جواب درست'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('پایان مرور'));
    await tester.pumpAndSettle();

    expect(reviewReviewed, {'missed-question'});
    expect(reviewMissed, isEmpty);
    expect(find.text('پاسخ نادرستی در صف مرور نیست.'), findsOneWidget);
  });
}
