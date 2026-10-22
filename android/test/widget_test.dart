import 'package:flutter_test/flutter_test.dart';
import 'package:souren/main.dart';

void main() {
  testWidgets('app boots to a loading shell', (tester) async {
    await tester.pumpWidget(const SourenApp());
    expect(find.byType(SourenApp), findsOneWidget);
  });
}
