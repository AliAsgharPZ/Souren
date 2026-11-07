import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Arabic roots asset is valid and contains the attributed index', () async {
    final raw = await rootBundle.loadString('assets/db/arabic_roots.json');
    final data = jsonDecode(raw) as Map<String, dynamic>;
    final entries = data['entries'] as List;

    expect(data['license'], 'CC BY 4.0');
    expect(entries.length, greaterThan(1000));
    expect(entries.first, contains('word'));
    expect(entries.first, contains('roots'));
  });
}
