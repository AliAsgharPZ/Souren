import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

/// Shared on-device storage. The dictionary app and the keyboard (IME)
/// live in the same Android package, so both read/write the same
/// filesDir — that is how the keyboard learns and the app shows it.
class SharedFiles {
  static String? _dir;
  static const _channel = MethodChannel('souren/files');

  static Future<String> dir() async {
    if (_dir != null) return _dir!;
    try {
      _dir = await _channel.invokeMethod<String>('filesDir');
    } catch (_) {
      _dir = Directory.systemTemp.path;
    }
    return _dir!;
  }

  static Future<File> file(String name) async =>
      File('${await dir()}/$name');

  static Future<Map<String, dynamic>?> readJson(String name) async {
    try {
      final f = await file(name);
      if (await f.exists()) {
        return jsonDecode(await f.readAsString()) as Map<String, dynamic>;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> writeJson(String name, Object data) async {
    final f = await file(name);
    await f.writeAsString(jsonEncode(data));
  }

  static Future<void> openInputSettings() async {
    try {
      await _channel.invokeMethod('openInputSettings');
    } catch (_) {}
  }

  static Future<void> showKeyboardPicker() async {
    try {
      await _channel.invokeMethod('showKeyboardPicker');
    } catch (_) {}
  }
}

class Entry {
  final String ar;
  final List<String> fa;
  const Entry(this.ar, this.fa);
  bool get hasFa => fa.isNotEmpty;
}

class Dictionary {
  final List<Entry> entries;
  final int version;
  final bool fromUpdate;
  const Dictionary(this.entries, this.version, this.fromUpdate);

  Map<String, List<String>> get map =>
      {for (final e in entries) if (e.hasFa) e.ar: e.fa};

  int get pairCount => entries.where((e) => e.hasFa).length;

  static Dictionary _parse(Map<String, dynamic> j, bool fromUpdate) {
    final list = (j['entries'] as List).map((e) {
      final m = e as Map<String, dynamic>;
      return Entry(m['ar'] as String,
          ((m['fa'] as List?) ?? const []).map((x) => x.toString()).toList());
    }).toList();
    return Dictionary(list, (j['version'] as num?)?.toInt() ?? 1, fromUpdate);
  }

  /// Updated dataset in filesDir wins over the bundled asset.
  static Future<Dictionary> load() async {
    final updated = await SharedFiles.readJson('dataset_updated.json');
    if (updated != null) {
      try {
        return _parse(updated, true);
      } catch (_) {}
    }
    final raw = await rootBundle.loadString('assets/db/dataset.json');
    return _parse(jsonDecode(raw) as Map<String, dynamic>, false);
  }
}

class Settings {
  bool replaceArabic;
  bool autoCorrect;

  /// Keyboard height: 'short' | 'normal' | 'tall'
  String kbHeight;
  Settings({
    this.replaceArabic = true,
    this.autoCorrect = true,
    this.kbHeight = 'tall',
  });

  static Future<Settings> load() async {
    final j = await SharedFiles.readJson('souren_settings.json');
    if (j == null) return Settings();
    return Settings(
      replaceArabic: j['replaceArabic'] != false,
      autoCorrect: j['autoCorrect'] != false,
      kbHeight: (j['kbHeight'] as String?) ?? 'tall',
    );
  }

  Future<void> save() => SharedFiles.writeJson('souren_settings.json', {
        'replaceArabic': replaceArabic,
        'autoCorrect': autoCorrect,
        'kbHeight': kbHeight,
      });
}

extension PickFile on SharedFiles {
  static Future<String?> pickTextFile() async {
    try {
      return await SharedFiles._channel.invokeMethod<String>('pickTextFile');
    } catch (_) {
      return null;
    }
  }
}
