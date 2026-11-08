import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';
import 'package:souren/lucide.dart';
import 'package:souren/main.dart';
import 'package:souren/share.dart';

void main() {
  test('buildShareText joins title, lines, caption and sign-off', () {
    const card = ShareCardData(
      title: 'سوال',
      lines: ['برابر فارسی: پرسش'],
      caption: 'دسته: سخن و نوشتار',
    );
    expect(
      buildShareText(card),
      'سوال\nبرابر فارسی: پرسش\nدسته: سخن و نوشتار\n— سورن',
    );
    const noCaption = ShareCardData(
      title: 'سوال',
      lines: ['برابر فارسی: پرسش'],
    );
    expect(buildShareText(noCaption), 'سوال\nبرابر فارسی: پرسش\n— سورن');
  });

  test('capR is 45 percent of the height (90% of max roundness)', () {
    expect(capR(58), closeTo(26.1, 0.001));
    expect(capR(100), 45);
    expect(capR(42), closeTo(18.9, 0.001));
  });

  test('meaningText shows only the first meaning when single', () {
    const e = Entry('سوال', ['پرسش', 'سئوال']);
    expect(meaningText(e, single: true), 'پرسش');
    expect(meaningText(e), 'پرسش، سئوال');
    expect(meaningText(const Entry('بی‌برابر', [])), 'برابر فارسی ثبت نشده');
    expect(
      meaningText(const Entry('بی‌برابر', []), single: true),
      'برابر فارسی ثبت نشده',
    );
  });

  testWidgets('Pressable calls onTap', (tester) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Pressable(
            onTap: () => tapped = true,
            child: const Text('tap me'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('tap me'));
    expect(tapped, isTrue);
  });

  testWidgets('LikeBookmarkButtons: inactive faded, active like red, '
      'active bookmark black', (tester) async {
    Future<void> noop() async {}
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LikeBookmarkButtons(
            liked: false,
            bookmarked: false,
            onToggleLike: noop,
            onToggleBookmark: noop,
          ),
        ),
      ),
    );
    final faded = pal.muted.withValues(alpha: 0.55);
    expect(tester.widget<Icon>(find.byIcon(LucideIcons.heart)).color, faded);
    expect(tester.widget<Icon>(find.byIcon(LucideIcons.bookmark)).color, faded);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: LikeBookmarkButtons(
            liked: true,
            bookmarked: true,
            onToggleLike: noop,
            onToggleBookmark: noop,
          ),
        ),
      ),
    );
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.heart)).color,
      pal.accent,
    );
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.bookmark)).color,
      pal.ink,
    );
  });

  testWidgets('DetailSheet shows the same options for a word and '
      'toggles like in place', (tester) async {
    var toggled = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DetailSheet(
            card: const ShareCardData(
              title: 'سوال',
              lines: ['برابر فارسی: پرسش'],
              caption: 'دسته: سخن و نوشتار',
            ),
            initialLiked: false,
            initialBookmarked: false,
            onToggleLike: () async {
              toggled++;
            },
            onToggleBookmark: () async {},
          ),
        ),
      ),
    );
    expect(find.text('سوال'), findsOneWidget);
    expect(find.text('برابر فارسی: پرسش'), findsOneWidget);
    expect(find.text('دسته: سخن و نوشتار'), findsOneWidget);
    expect(find.text('اشتراک‌گذاری'), findsOneWidget);
    expect(find.text('کپی'), findsOneWidget);
    expect(find.byIcon(LucideIcons.heart), findsOneWidget);
    expect(find.byIcon(LucideIcons.bookmark), findsOneWidget);

    await tester.tap(find.byIcon(LucideIcons.heart));
    await tester.pump();
    expect(toggled, 1);
    // The sheet stays open and the heart turns red in place —
    // no pop + reopen, no second card.
    expect(find.text('سوال'), findsOneWidget);
    expect(
      tester.widget<Icon>(find.byIcon(LucideIcons.heart)).color,
      pal.accent,
    );
  });
}
