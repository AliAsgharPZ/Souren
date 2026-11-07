import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';
import 'package:souren/main.dart';

/// Regression test for owner B4/B8: the app must open and render from
/// LOCAL data only, without waiting for the network — likes/profile
/// requests happen in the background and a dead network never blocks
/// startup.
///
/// All HTTP is forced to fail synchronously via HttpOverrides (real
/// sockets cannot complete inside the test's fake-async zone), which
/// also proves the bounded timeouts never leave a hanging startup.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    HttpOverrides.global = _DeadNetworkOverrides();
  });

  tearDown(() {
    HttpOverrides.global = null;
  });

  /// Creates the temp dir and points the platform channel at it. The
  /// real file IO runs via [tester.runAsync] — inside fake async it
  /// would never complete.
  Future<Directory> mockStorage(WidgetTester tester) async {
    late final Directory tmp;
    await tester.runAsync(() async {
      tmp = await Directory.systemTemp.createTemp('souren-boot');
    });
    SharedFiles.resetDirCache();
    const ch = MethodChannel('souren/files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, (call) async {
      if (call.method == 'filesDir') return tmp.path;
      return null;
    });
    return tmp;
  }

  void unmockStorage() {
    const ch = MethodChannel('souren/files');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ch, null);
  }

  testWidgets('app renders the shell fully offline', (tester) async {
    final tmp = await mockStorage(tester);
    addTearDown(() => tmp.delete(recursive: true).ignore());
    addTearDown(unmockStorage);

    await tester.pumpWidget(const SourenApp());
    // Loading shell first…
    await tester.pump();

    // Give the widget's real file IO time to finish (outside fake
    // async), then process its completions — several hops cover the
    // storage reads and the local-state setState.
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }

    expect(find.byType(Shell), findsOneWidget);
    expect(find.text('واژه‌ای را جستجو کنید'), findsOneWidget);
  });

  testWidgets('background timeouts never block or leak timers', (tester) async {
    final tmp = await mockStorage(tester);
    addTearDown(() => tmp.delete(recursive: true).ignore());
    addTearDown(unmockStorage);

    await tester.pumpWidget(const SourenApp());
    await tester.pump();
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await tester.pump();
    }
    // Enough FAKE time for the 10s background timeouts to fire and be
    // cancelled cleanly (no pending-timer errors at teardown).
    await tester.pump(const Duration(seconds: 11));
    expect(find.byType(Shell), findsOneWidget);
  });
}

/// Every HttpClient call fails instantly — the machine is "offline".
class _DeadNetworkOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) => _DeadClient();
}

class _DeadClient implements HttpClient {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const SocketException('offline (Souren startup test)');
}
