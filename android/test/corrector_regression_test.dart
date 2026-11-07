import 'package:flutter_test/flutter_test.dart';
import 'package:souren/engine/corrector.dart';

/// Regression tests for owner B3/B8: whitespace (newlines, tabs,
/// repeated spaces), quotation marks, parentheses and punctuation must
/// survive correction — and the fixed words around them must still be
/// corrected. The Kotlin mirror (CorrectorTest.kt) asserts the same
/// behaviour for the keyboard-side engine.
void main() {
  const dict = {
    'اتفاق': ['رویداد', 'پیشامد'],
    'سوال': ['پرسش'],
  };

  group('whitespace is preserved exactly', () {
    test('newline between words survives', () {
      const src = 'یک خط\nدوم خط';
      expect(correctText(src), src);
    });
    test('multiline Persian text keeps its line breaks', () {
      // same-line pairs still get the ezafe; the newline itself survives
      expect(
        correctText('عالیترین کتابها\nهمه individuals'),
        'عالی‌ترین کتاب‌ها\nهمهٔ individuals',
      );
    });
    test('tabs survive untouched', () {
      const src = 'کتاب\tها';
      // tab is NOT merged: the ها-merge needs a single ordinary space
      expect(correctText(src), 'کتاب\tها');
    });
    test('repeated spaces are not collapsed', () {
      expect(correctText('یک  دو   سه'), 'یک  دو   سه');
    });
    test('leading and trailing whitespace survive', () {
      expect(correctText('  کتابها  '), '  کتاب‌ها  ');
    });
  });

  group('quotes and parentheses', () {
    test('quoted word is corrected inside the quotes', () {
      expect(correctText('«اتفاق»', dictionary: dict), '«رویداد»');
    });
    test('parenthesized word is corrected inside the parens', () {
      expect(correctText('(اتفاق)', dictionary: dict), '(رویداد)');
    });
    test('quote + punctuation both reattach', () {
      expect(correctText('«اتفاق».', dictionary: dict), '«رویداد».');
    });
    test('plain word with trailing comma', () {
      expect(correctText('اتفاق، آمد', dictionary: dict), 'رویداد، آمد');
    });
    test('short cores are never stripped to empty', () {
      expect(correctText('«»'), '«»');
      expect(correctText('«ا»'), '«ا»');
    });
  });

  group('ha-merge and ezafe across separators', () {
    test('ها merges across a single space', () {
      expect(correctText('کتاب ها'), 'کتاب‌ها');
    });
    test('ها does NOT merge across repeated spaces', () {
      expect(correctText('کتاب  ها'), 'کتاب  ها');
    });
    test('ها does NOT merge across a newline', () {
      expect(correctText('کتاب\nها'), 'کتاب\nها');
    });
    test('ezafe applies across a single space', () {
      expect(correctText('همه افراد'), 'همهٔ افراد');
    });
    test('ezafe does NOT apply across a newline', () {
      expect(correctText('همه\nافراد'), 'همه\nافراد');
    });
  });

  group('word fixes still apply around preserved separators', () {
    test('dictionary replacement with punctuation', () {
      expect(correctWord('سوال', dictionary: dict).fixed, 'پرسش');
    });
    test('می/نمی fix in a sentence with punctuation', () {
      expect(correctText('میخام بروم.'), 'می‌خوام بروم.');
    });
    test('mixed separators in one text', () {
      const src = 'کتابها:\n\tعالیتر  ها';
      expect(correctText(src), 'کتاب‌ها:\n\tعالی‌تر  ها');
    });
  });
}
