import 'package:flutter_test/flutter_test.dart';
import 'package:souren/engine/corrector.dart';

void main() {
  const dictionary = <String, List<String>>{
    'اتفاق': ['رویداد', 'پیشامد'],
    'سوال': ['پرسش'],
  };

  group('separator preservation', () {
    test('tabs and newlines survive', () {
      expect(correctText('کتاب\tها'), 'کتاب\tها');
      expect(correctText('عالیترین کتابها\nسوال', dictionary: dictionary),
          'عالی‌ترین کتاب‌ها\nپرسش');
    });

    test('repeated spaces and edge whitespace survive', () {
      expect(correctText('یک  دو   سه'), 'یک  دو   سه');
      expect(correctText('  کتابها  '), '  کتاب‌ها  ');
    });

    test('whitespace before punctuation is preserved', () {
      expect(correctText('سلام ،'), 'سلام ،');
      expect(correctText('سلام\t،'), 'سلام\t،');
      expect(correctText('سلام \n،'), 'سلام \n،');
    });

    test('quoted and parenthesized words are corrected', () {
      expect(correctText('«اتفاق»', dictionary: dictionary), '«رویداد»');
      expect(correctText('(اتفاق)', dictionary: dictionary), '(رویداد)');
      expect(correctText('«اتفاق».', dictionary: dictionary), '«رویداد».');
    });
  });

  group('separator-sensitive Persian rules', () {
    test('ha merge only uses one ordinary space', () {
      expect(correctText('کتاب ها'), 'کتاب‌ها');
      expect(correctText('کتاب  ها'), 'کتاب  ها');
      expect(correctText('کتاب\nها'), 'کتاب\nها');
    });

    test('ezafe only uses one ordinary space', () {
      expect(correctText('همه افراد'), 'همهٔ افراد');
      expect(correctText('همه\tافراد'), 'همه\tافراد');
      expect(correctText('همه\nافراد'), 'همه\nافراد');
    });

    test('mixed separators and punctuation stay in place', () {
      const source = '  کتابها:\n\tعالیتر  ها ، سوال';
      expect(correctText(source, dictionary: dictionary),
          '  کتاب‌ها:\n\tعالی‌تر  ها ، پرسش');
    });
  });
}
