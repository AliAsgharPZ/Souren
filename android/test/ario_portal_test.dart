import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';
import 'package:souren/main.dart';

void main() {
  testWidgets('Ario speed challenge starts, scores, and finishes a timed round', (tester) async {
    var bestStreak = 0;
    await tester.pumpWidget(MaterialApp(
      home: ArioSpeedChallengePage(
        entries: const [
          Entry('كتاب', ['کتاب']),
          Entry('قلم', ['خودکار']),
          Entry('بيت', ['خانه']),
          Entry('ماء', ['آب']),
        ],
        onBestStreak: (value) => bestStreak = value,
      ),
    ));

    expect(find.text('چالش سرعتی'), findsOneWidget);
    await tester.tap(find.text('شروع چالش'));
    await tester.pump();
    expect(find.text('معنی درست این واژه کدام است؟'), findsOneWidget);

    await tester.tap(find.text('کتاب'));
    await tester.pump();
    expect(find.text('درست بود!'), findsOneWidget);
    expect(bestStreak, 1);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('پایان چالش'), findsOneWidget);
    expect(find.text('امتیاز: ۱'), findsOneWidget);
  });
}
