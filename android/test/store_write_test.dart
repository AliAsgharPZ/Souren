import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:souren/data/store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('concurrent JSON saves keep the last complete document', () async {
    const name = 'souren_store_write_regression.json';
    final destination = await SharedFiles.file(name);
    final temporary = File('${destination.path}.tmp');
    if (await destination.exists()) await destination.delete();
    if (await temporary.exists()) await temporary.delete();

    await Future.wait([
      for (var index = 0; index < 40; index++)
        SharedFiles.writeJson(name, {
          'sequence': index,
          'payload': [for (var item = 0; item < 128; item++) '$index:$item'],
        }),
    ]);

    final saved = await SharedFiles.readJson(name);
    expect(saved, isNotNull);
    expect(saved!['sequence'], 39);
    expect(saved['payload'], hasLength(128));
    expect(await temporary.exists(), isFalse);

    await destination.delete();
  });
}
