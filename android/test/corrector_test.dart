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
  group('v3 expansions (owner 2026-10-25)', () {
    test('جایگزینی با چند برابر: نخستین تک‌واژه‌ای', () {
      // احترام has two equivalents; old rule never replaced it.
      expect(correctWord('احترام', dictionary: dict).fixed, 'گرامیداشت');
      expect(correctWord('احترام', dictionary: dict).suggestions,
          ['گرامیداشت', 'ارج']);
    });
    test('نشانهٔ پایانی جلوی جایگزینی را نمی‌گیرد', () {
      const d2 = {
        'اتفاق': ['رویداد', 'پیشامد']
      };
      expect(correctText('اتفاق، آمد', dictionary: d2), 'رویداد، آمد');
    });
    test('فهرست‌های گسترش‌یافته', () {
      expect(correctWord('میترسم').fixed, 'می‌ترسم');
      expect(correctWord('مینشینم').fixed, 'می‌نشینم');
      expect(correctWord('بیقرار').fixed, 'بی‌قرار');
      expect(correctWord('بیگناه').fixed, 'بی‌گناه');
      expect(correctWord('کبوتر').fixed, 'کبوتر');
      expect(correctWord('آنها').fixed, 'آنها');
      expect(correctWord('خانهم').fixed, 'خانه‌م');
      expect(correctWord('همهی').fixed, 'همهٔ');
      expect(correctWord('رفتهاست').fixed, 'رفته‌است');
      expect(correctWord('بیمار').fixed, 'بیمار');
      expect(correctWord('بیان').fixed, 'بیان');
    });
  });
}
