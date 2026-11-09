import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';
import 'package:souren/data/persian_roots.dart';

void main() {
  test('Persian morphology index is built from Persian equivalents only', () {
    const dictionary = Dictionary([
      Entry('مدخل۱', ['کتاب‌ها', 'دانش']),
      Entry('مدخل۲', ['کتاب', 'آگاهی']),
    ], 1, false);

    final rows = PersianRoots.index(dictionary);
    expect(rows.map((e) => e.word), ['کتابها']);
    expect(rows.single.base, 'کتاب');
    expect(PersianRoots.baseOf('دانش'), 'دانش');
    expect(rows.any((e) => e.word == 'دانش' || e.word == 'آگاهی'), isFalse);
  });

  test('Persian search finds both a word and its structural base', () {
    const dictionary = Dictionary([
      Entry('واژه۱', ['کتاب‌ها']),
      Entry('واژه۲', ['کتاب']),
    ], 1, false);
    final rows = PersianRoots.index(dictionary);
    final matches = PersianRoots.search(rows, 'کتاب');
    expect(matches.length, 1);
    expect(matches.single.word, 'کتابها');
  });
}
