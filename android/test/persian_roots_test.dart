import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';
import 'package:souren/data/persian_roots.dart';

void main() {
  test('Persian morphology index is built from Persian equivalents only', () {
    final dictionary = Dictionary(const [
      const Entry('مدخل۱', ['کتاب‌ها', 'دانش']),
      const Entry('مدخل۲', ['کتاب', 'آگاهی']),
    ], 1, false);

    final rows = PersianRoots.index(dictionary);
    expect(rows.map((e) => e.word), containsAll(['کتاب', 'کتابها', 'دانش', 'آگاهی']));
    expect(PersianRoots.baseOf('کتاب‌ها'), 'کتاب');
    expect(PersianRoots.baseOf('دانش'), 'دانش');
  });

  test('Persian search finds both a word and its structural base', () {
    final dictionary = Dictionary(const [
      const Entry('واژه۱', ['کتاب‌ها']),
      const Entry('واژه۲', ['کتاب']),
    ], 1, false);
    final rows = PersianRoots.index(dictionary);
    expect(PersianRoots.search(rows, 'کتاب').length, 2);
  });
}
