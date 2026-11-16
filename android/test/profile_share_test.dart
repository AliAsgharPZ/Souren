import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/share.dart';

void main() {
  group('offline profile share card', () {
    test('keeps the shared Ario avatar in the profile card model', () {
      const card = ShareCardData(
        title: 'نمایهٔ شخصی من',
        lines: ['امتیاز کل: ۴۲'],
        caption: 'نمایهٔ آفلاین سورن و آریو',
        isProfile: true,
        profileScore: 42,
        profileLevel: 'واژه‌جو',
        profileAvatarIcon: Icons.school,
        profileAvatarColor: Colors.teal,
      );

      expect(card.isProfile, isTrue);
      expect(card.profileScore, 42);
      expect(card.profileLevel, 'واژه‌جو');
      expect(card.profileAvatarIcon, Icons.school);
      expect(card.profileAvatarColor, Colors.teal);
    });

    test('exports local profile details without account identity', () {
      const card = ShareCardData(
        title: 'نمایهٔ شخصی من',
        lines: ['امتیاز کل: ۴۲', 'رکورد شخصی: ۱۲'],
        caption: 'داده‌های ذخیره‌شده روی همین دستگاه',
        isProfile: true,
      );

      final text = buildShareText(card);

      expect(text, contains('امتیاز کل: ۴۲'));
      expect(text, contains('رکورد شخصی: ۱۲'));
      expect(text, contains('داده‌های ذخیره‌شده روی همین دستگاه'));
      expect(text, endsWith('— سورن'));
      expect(text, isNot(contains('@')));
      expect(text, isNot(contains('ایمیل')));
    });
  });
}
