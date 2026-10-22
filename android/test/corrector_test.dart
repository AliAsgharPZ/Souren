import 'package:flutter_test/flutter_test.dart';
import 'package:souren/engine/corrector.dart';

void main() {
  const dict = {
    'سوال': ['پرسش'],
    'جواب': ['پاسخ'],
    'احترام': ['گرامیداشت', 'ارج'],
    'ابتدا': ['آغاز'],
  };
  group('owner examples', () {
    test('میخام/میخوام → می‌خوام', () {
      expect(correctWord('میخام').fixed, 'می‌خوام');
      expect(correctWord('میخوام').fixed, 'می‌خوام');
    });
    test('همه افراد → همهٔ افراد', () {
      expect(correctText('همه افراد'), 'همهٔ افراد');
    });
    test('سوال → پرسش (جایگزینی عربی)', () {
      expect(correctWord('سوال', dictionary: dict).fixed, 'پرسش');
      expect(correctWord('جواب', dictionary: dict).fixed, 'پاسخ');
    });
  });
  group('v2 suffix rules', () {
    test('ترین/تر با نیم‌فاصله، به‌جز چسبیده‌ها', () {
      expect(correctWord('عالیترین').fixed, 'عالی‌ترین');
      expect(correctWord('بزرگترین').fixed, 'بزرگ‌ترین');
      expect(correctWord('گرمتر').fixed, 'گرم‌تر');
      expect(correctWord('بهترین').fixed, 'بهترین');
      expect(correctWord('بیشتر').fixed, 'بیشتر');
      expect(correctWord('دختر').fixed, 'دختر');
    });
    test('ها و پایان‌های صرفی', () {
      expect(correctWord('کتابها').fixed, 'کتاب‌ها');
      expect(correctWord('تنها').fixed, 'تنها');
      expect(correctWord('رفتهام').fixed, 'رفته‌ام');
      expect(correctWord('خانهاش').fixed, 'خانه‌اش');
      expect(correctWord('کشتیشان').fixed, 'کشتی‌شان');
      expect(correctWord('گمشده').fixed, 'گم‌شده');
      expect(correctWord('بینهایت').fixed, 'بی‌نهایت');
    });
    test('گارد اسم‌ها در برابر پیشوند می', () {
      expect(correctWord('میدان').fixed, 'میدان');
      expect(correctWord('میراث').fixed, 'میراث');
      expect(correctWord('میرم').fixed, 'می‌رم');
      expect(correctWord('نمیشه').fixed, 'نمی‌شه');
    });
  });
}
