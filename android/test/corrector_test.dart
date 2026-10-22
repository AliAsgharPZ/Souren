import 'package:flutter_test/flutter_test.dart';
import 'package:souren/engine/corrector.dart';

void main() {
  const dict = {
    'سوال': ['پرسش'],
    'احترام': ['گرامیداشت', 'ارج'],
    'ابتدا': ['آغاز'],
  };
  group('owner examples', () {
    test('میخام → می‌خوام', () {
      expect(correctWord('میخام').fixed, 'می‌خوام');
    });
    test('میخوام → می‌خوام', () {
      expect(correctWord('میخوام').fixed, 'می‌خوام');
    });
    test('همه افراد → همهٔ افراد', () {
      expect(correctText('همه افراد'), 'همهٔ افراد');
    });
  });
  group('rules', () {
    test('میرم → می‌رم و نمیدونم → نمی‌دونم', () {
      expect(correctWord('میرم').fixed, 'می‌رم');
      expect(correctWord('نمیدونم').fixed, 'نمی‌دونم');
    });
    test('کتاب ها → کتاب‌ها', () {
      expect(correctText('کتاب ها را خواندم'), 'کتاب‌ها را خواندم');
    });
    test('arabic letters: يك → یک', () {
      expect(correctWord('يك').fixed, 'یک');
    });
    test('single-word equivalent auto-replaces', () {
      expect(correctWord('سوال', dictionary: dict).fixed, 'پرسش');
    });
    test('multi equivalents only suggest', () {
      final f = correctWord('احترام', dictionary: dict);
      expect(f.fixed, 'احترام');
      expect(f.suggestions, ['گرامیداشت', 'ارج']);
    });
    test('punctuation spacing', () {
      expect(correctText('سلام ، خوبی ؟'), 'سلام، خوبی؟');
    });
  });
}
