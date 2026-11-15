import 'package:material_ui/material_ui.dart';
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

  testWidgets('Daily Boss records its final local score', (tester) async {
    var recordedScore = -1;
    await tester.pumpWidget(MaterialApp(
      home: ArioSpeedChallengePage(
        entries: const [
          Entry('كتاب', ['کتاب']),
          Entry('قلم', ['خودکار']),
          Entry('بيت', ['خانه']),
          Entry('ماء', ['آب']),
        ],
        mode: ArioChallengeMode.dailyBoss,
        initialDailyBest: 4,
        onDailyBossCompleted: (score) => recordedScore = score,
      ),
    ));

    expect(find.text('Daily Boss · غول روزانه'), findsOneWidget);
    expect(find.text('بهترین امتیاز امروز: ۴'), findsOneWidget);
    await tester.tap(find.text('شروع Daily Boss'));
    await tester.pump();
    await tester.tap(find.text('کتاب'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 30));

    expect(find.text('پایان چالش'), findsOneWidget);
    expect(find.text('امتیاز: ۱'), findsOneWidget);
    expect(recordedScore, 1);
  });

  testWidgets('Ghost challenge compares only with the saved personal run', (tester) async {
    List<int>? savedTrack;
    await tester.pumpWidget(MaterialApp(
      home: ArioSpeedChallengePage(
        entries: const [
          Entry('كتاب', ['کتاب']),
          Entry('قلم', ['خودکار']),
          Entry('بيت', ['خانه']),
          Entry('ماء', ['آب']),
        ],
        mode: ArioChallengeMode.ghost,
        initialGhostTrack: const [1, 2, 3],
        onGhostRunCompleted: (track) => savedTrack = track,
      ),
    ));

    expect(find.text('چالش شبح'), findsOneWidget);
    expect(find.text('رکورد قبلی خودت: ۳'), findsOneWidget);
    expect(find.textContaining('این چالش انفرادی است و نتیجهٔ هر پرسش با همان بخش از بهترین اجرای قبلی خودت مقایسه می‌شود.'), findsOneWidget);
    await tester.tap(find.text('شروع چالش شبح'));
    await tester.pump();
    expect(find.text('رکورد قبلی در این پرسش: ۱'), findsOneWidget);

    await tester.tap(find.text('کتاب'));
    await tester.pump();
    await tester.ensureVisible(find.text('سؤال بعدی'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('سؤال بعدی'));
    await tester.pumpAndSettle();
    expect(find.text('رکورد قبلی در این پرسش: ۲'), findsOneWidget);

    await tester.pump(const Duration(seconds: 30));
    expect(find.text('پایان چالش'), findsOneWidget);
    expect(savedTrack, [1]);
    expect(find.text('این اجرا با رکورد قبلی خودت مقایسه شد.'), findsOneWidget);
  });

}
