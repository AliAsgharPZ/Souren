import 'package:material_symbols_icons/symbols.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/main.dart';

void main() {
  test('capsule radius is 90 percent of its height', () {
    expect(capR(40), 18);
    expect(capR(48), 21.6);
  });

  test('saved filters follow physical swipe direction in RTL', () {
    expect(nextRtlSwipeFilterIndex(0, -240, 5), 1);
    expect(nextRtlSwipeFilterIndex(0, 240, 5), 4);
    expect(nextRtlSwipeFilterIndex(4, -240, 5), 0);
    expect(nextRtlSwipeFilterIndex(2, 100, 5), 2);
    expect(nextRtlSwipeFilterIndex(2, double.infinity, 5), 2);
    expect(nextRtlSwipeFilterIndex(2, -240, 0), 2);
  });

  testWidgets('shell bootstrap can be disposed before local loading completes', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Shell()));
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });

  testWidgets('like stays on the RTL leading side before bookmark', (tester) async {
    var likes = 0;
    var bookmarks = 0;
    await tester.pumpWidget(MaterialApp(
      home: Directionality(
        textDirection: TextDirection.rtl,
        child: LikeBookmarkButtons(
          liked: false,
          bookmarked: false,
          onToggleLike: () => likes++,
          onToggleBookmark: () => bookmarks++,
        ),
      ),
    ));

    final like = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Symbols.favorite_rounded,
    );
    final bookmark = find.byWidgetPredicate(
      (widget) => widget is Icon && widget.icon == Symbols.bookmark_rounded,
    );
    expect(tester.getCenter(like).dx, greaterThan(tester.getCenter(bookmark).dx));

    await tester.tap(like);
    await tester.pumpAndSettle();
    await tester.tap(bookmark);
    await tester.pumpAndSettle();
    expect(likes, 1);
    expect(bookmarks, 1);
  });
}
