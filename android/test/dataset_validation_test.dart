import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';

/// Regression tests for owner B2/B6: dataset validation on import, the
/// safe load fallback when dataset_updated.json is corrupt, and the
/// quoted-field CSV parser.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const ch = MethodChannel('souren/files');
  late Directory tmp;

  setUp(() async {
    SharedFiles.resetDirCache();
    tmp = await Directory.systemTemp.createTemp('souren-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      if (call.method == 'filesDir') return tmp.path;
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  group('validateDatasetMap (JSON import)', () {
    test('valid dataset passes', () {
      final check = validateDatasetMap(const {
        'version': 3,
        'entries': [
          {'ar': 'اتفاق', 'fa': ['رویداد']},
        ],
      });
      expect(check.ok, isTrue);
    });
    test('entries must be a list', () {
      final check = validateDatasetMap(const {
        'version': 3,
        'entries': 'nope',
      });
      expect(check.ok, isFalse);
    });
    test('entry without Arabic word is rejected', () {
      final check = validateDatasetMap(const {
        'version': 3,
        'entries': [
          {'ar': '', 'fa': <String>[]},
        ],
      });
      expect(check.ok, isFalse);
      expect(check.error, contains('عربی'));
    });
    test('fa must be a string array', () {
      final check = validateDatasetMap(const {
        'version': 3,
        'entries': [
          {'ar': 'اتفاق', 'fa': [1, 2]},
        ],
      });
      expect(check.ok, isFalse);
    });
    test('duplicate Arabic keys are rejected', () {
      final check = validateDatasetMap(const {
        'version': 3,
        'entries': [
          {'ar': 'اتفاق', 'fa': <String>[]},
          {'ar': 'اتفاق', 'fa': <String>[]},
        ],
      });
      expect(check.ok, isFalse);
      expect(check.error, contains('تکراری'));
    });
    test('version metadata must be a positive integer', () {
      for (final bad in ['x', 0, -2, 1.5]) {
        final check = validateDatasetMap({
          'version': bad,
          'entries': [
            {'ar': 'اتفاق', 'fa': <String>[]},
          ],
        });
        expect(check.ok, isFalse, reason: 'version=$bad must fail');
      }
    });
  });

  group('validateDatasetText (raw file)', () {
    test('broken JSON is rejected, never written', () {
      final check = validateDatasetText('{"entries": [');
      expect(check.ok, isFalse);
    });
    test('top level must be an object', () {
      final check = validateDatasetText('[1,2,3]');
      expect(check.ok, isFalse);
    });
    test('valid JSON passes with data attached', () {
      final check = validateDatasetText(
        jsonEncode({
          'version': 9,
          'entries': [
            {'ar': 'ابتدا', 'fa': ['آغاز']},
          ],
        }),
      );
      expect(check.ok, isTrue);
      expect(check.data!['version'], 9);
    });
  });

  group('CSV with quoted fields (owner B6)', () {
    test('quoted field containing comma and quotes parses correctly', () {
      final check = validateDatasetText(
        '"کلمه، عجیب","معنی اول، دوم ""نقل"""\nآب,آب\n',
      );
      expect(check.ok, isTrue);
      final entries = (check.data!['entries'] as List).cast<Map>();
      expect(entries[0]['ar'], 'کلمه، عجیب');
      expect(entries[0]['fa'], ['معنی اول، دوم "نقل"']);
      expect(entries[1]['ar'], 'آب');
    });
    test('an ar,fa header row is skipped, not imported', () {
      final check = validateDatasetText('ar,fa\nآب,آب\n');
      expect(check.ok, isTrue);
      final entries = (check.data!['entries'] as List).cast<Map>();
      expect(entries, hasLength(1));
      expect(entries.single['ar'], 'آب');
    });
    test('semicolon and tab separated files parse', () async {
      expect(validateDatasetText('abc\n').ok, isFalse); // 1 column
      final semi = validateDatasetText('کتاب;جوامع\n');
      expect(semi.ok, isTrue);
      final tab = validateDatasetText('کتاب\tجوامع\n');
      expect(tab.ok, isTrue);
    });
    test('single-column rows are rejected with a row number', () {
      final check = validateDatasetText('فقط یک ستون\n');
      expect(check.ok, isFalse);
      expect(check.error, contains('دو ستون'));
    });
  });

  group('Dictionary.load fallback (owner B2)', () {
    test('corrupt dataset_updated.json falls back to the bundled asset',
        () async {
      await File('${tmp.path}/dataset_updated.json')
          .writeAsString('{"entries": [ BROKEN');
      final d = await Dictionary.load();
      expect(d.fromUpdate, isFalse, reason: 'corrupt update must be ignored');
      expect(d.entries, isNotEmpty);
    });
    test('a VALID updated dataset wins over the bundled asset', () async {
      await File('${tmp.path}/dataset_updated.json').writeAsString(jsonEncode({
        'version': 41,
        'entries': [
          {'ar': 'اتفاق', 'fa': ['رویداد']},
        ],
      }));
      final d = await Dictionary.load();
      expect(d.fromUpdate, isTrue);
      expect(d.version, 41);
      expect(d.entries.single.ar, 'اتفاق');
    });
    test('a well-formed but INVALID dataset (duplicates) falls back',
        () async {
      await File('${tmp.path}/dataset_updated.json').writeAsString(jsonEncode({
        'version': 7,
        'entries': [
          {'ar': 'اتفاق', 'fa': <String>[]},
          {'ar': 'اتفاق', 'fa': <String>[]},
        ],
      }));
      final d = await Dictionary.load();
      expect(d.fromUpdate, isFalse);
    });
    test('atomic write replaces the file cleanly', () async {
      final f = await SharedFiles.file('dataset_updated.json');
      await f.writeAsString('old');
      await SharedFiles.writeJsonAtomic('dataset_updated.json', {
        'version': 2,
        'entries': <Map<String, dynamic>>[],
      });
      final j = await SharedFiles.readJson('dataset_updated.json');
      expect(j, isNotNull);
      expect(j!['version'], 2);
      expect(await f.exists(), isTrue);
    });
  });
}
