import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('bundled dictionary matches the canonical 552-word source', () async {
    final dictionary = await Dictionary.load();

    expect(dictionary.entries, hasLength(552));
    expect(dictionary.pairCount, 552);
    expect(dictionary.entries.every((entry) => entry.level >= 1 && entry.level <= 100), isTrue);
    expect(dictionary.entries.map((entry) => entry.ar).toSet(), hasLength(552));

    final byWord = {for (final entry in dictionary.entries) entry.ar: entry};
    expect(byWord['كتاب']?.fa, ['کتاب', 'دفتر']);
    expect(byWord['مدرسة']?.fa, ['مدرسه', 'آموزشگاه']);
    expect(byWord['طالب']?.fa, ['دانش‌آموز', 'محصل', 'طلب‌کننده']);
    expect(byWord['معلم']?.fa, ['معلم', 'آموزگار']);
    expect(byWord['سلام']?.fa, ['سلام', 'درود', 'صلح']);
    expect(byWord['طیاره']?.fa, ['هواپیما']);
    expect(byWord['حرکت']?.fa, ['جنبش']);
    expect(byWord['كتاب']?.concept, isNotEmpty);
  });
}
