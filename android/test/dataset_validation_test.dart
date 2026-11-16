import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';

void main() {
  group('dataset structure validation', () {
    test('valid dataset passes', () {
      final check = validateDatasetMap({
        'version': 4,
        'entries': [
          {'ar': 'اتفاق', 'fa': ['رویداد'], 'level': 4},
        ],
      });
      expect(check.ok, isTrue);
    });

    test('non-object entries, empty Arabic keys and malformed meanings fail', () {
      expect(validateDatasetMap({'entries': ['bad']}).ok, isFalse);
      expect(validateDatasetMap({'entries': [{'ar': '', 'fa': []}]}).ok, isFalse);
      expect(validateDatasetMap({'entries': [{'ar': 'اتفاق', 'fa': [3]}]}).ok, isFalse);
      expect(validateDatasetMap({'entries': [{'ar': 'اتفاق', 'fa': []}, {'ar': 'اتفاق', 'fa': []}]}).ok, isFalse);
      expect(validateDatasetMap({'entries': [{'ar': 'اتفاق', 'fa': [], 'level': 'easy'}]}).ok, isFalse);
    });

    test('invalid version and empty entries fail', () {
      for (final version in ['x', 0, -1, 1.5]) {
        expect(validateDatasetMap({
          'version': version,
          'entries': [{'ar': 'اتفاق', 'fa': []}],
        }).ok, isFalse);
      }
      expect(validateDatasetMap({'entries': <Object>[]}).ok, isFalse);
    });

    test('raw malformed JSON and top-level arrays fail', () {
      expect(validateDatasetText('{"entries": [').ok, isFalse);
      expect(validateDatasetText('[1,2,3]').ok, isFalse);
    });
  });

  group('quoted CSV import', () {
    test('commas and escaped quotes inside quoted fields are preserved', () {
      final check = validateDatasetText('"واژه، پیچیده","معنی اول، دوم ""نقل"""\nآب,آب\n');
      expect(check.ok, isTrue);
      final entries = (check.data!['entries'] as List).cast<Map>();
      expect(entries.first['ar'], 'واژه، پیچیده');
      expect(entries.first['fa'], ['معنی اول، دوم "نقل"']);
    });

    test('quoted fields can contain line breaks', () {
      final check = validateDatasetText('"واژه","معنی خط اول\nمعنی خط دوم"\n');
      expect(check.ok, isTrue);
      final entries = (check.data!['entries'] as List).cast<Map>();
      expect(entries.single['fa'], ['معنی خط اول\nمعنی خط دوم']);
    });

    test('header, semicolon and tab delimiters are supported', () {
      final header = validateDatasetText('ar,fa\nآب,آب\n');
      expect(header.ok, isTrue);
      expect((header.data!['entries'] as List), hasLength(1));
      expect(validateDatasetText('کتاب;جوامع\n').ok, isTrue);
      expect(validateDatasetText('کتاب\tجوامع\n').ok, isTrue);
    });

    test('unclosed quotes, duplicate words and one-column rows fail', () {
      expect(validateDatasetText('"واژه,معنی').ok, isFalse);
      expect(validateDatasetText('آب,آب\nآب,دریا\n').ok, isFalse);
      expect(validateDatasetText('فقط یک ستون\n').ok, isFalse);
    });
  });
}
