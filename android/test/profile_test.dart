import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('profile score & levels', () {
    test('score weights', () {
      expect(
          profileScore(
              favorites: 2, likes: 3, learnedWords: 4, corrections: 5),
          2 * 3 + 3 * 2 + 4 * 2 + 5);
    });
    test('levels by threshold', () {
      expect(levelFor(0), 'تازه‌وارد');
      expect(levelFor(24), 'تازه‌وارد');
      expect(levelFor(25), 'واژه‌جو');
      expect(levelFor(80), 'واژه‌آموز');
      expect(levelFor(160), 'درست‌نویس');
      expect(levelFor(999), 'استاد واژه');
      expect(nextLevelAt(0), 25);
      expect(nextLevelAt(299), 300);
      expect(nextLevelAt(300), isNull);
    });
    test('badges', () {
      expect(
          badgeEarned('member',
              loggedIn: false,
              favorites: 0,
              likes: 0,
              corrections: 0,
              score: 0),
          isFalse);
      expect(
          badgeEarned('member',
              loggedIn: true,
              favorites: 0,
              likes: 0,
              corrections: 0,
              score: 0),
          isTrue);
      expect(
          badgeEarned('liker',
              loggedIn: false,
              favorites: 0,
              likes: 10,
              corrections: 0,
              score: 20),
          isTrue);
      expect(
          badgeEarned('collector',
              loggedIn: false,
              favorites: 24,
              likes: 0,
              corrections: 0,
              score: 72),
          isFalse);
    });
  });

  group('categories integrity', () {
    test('every categorized word exists in the dataset, no duplicates',
        () async {
      final cats = await Categories.load();
      final dict = await Dictionary.load();
      final arSet = dict.entries.map((e) => e.ar).toSet();
      expect(cats.cats.length, greaterThanOrEqualTo(10));
      final seen = <String>{};
      for (final words in cats.cats.values) {
        for (final w in words) {
          expect(arSet.contains(w), isTrue, reason: '«$w» در دیتاست نیست');
          expect(seen.add(w), isTrue, reason: '«$w» در دو دسته آمده');
        }
      }
      // همگانی = complement, non-empty and disjoint
      final general = cats.inCategory(dict, Categories.generalId);
      expect(general, isNotEmpty);
      expect(general.any((e) => seen.contains(e.ar)), isFalse);
      // a known word lands in its category
      expect(cats.categoryOf('طبیب'), 'health');
      expect(cats.categoryOf('تجارت'), 'money');
    });
  });
}
