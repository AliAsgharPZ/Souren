import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shared on-device storage. The dictionary app and the keyboard (IME)
/// live in the same Android package, so both read/write the same
/// filesDir — that is how the keyboard learns and the app shows it.
class SharedFiles {
  static String? _dir;
  static const _channel = MethodChannel('souren/files');
  static const _arioChannel = MethodChannel('souren/ario');

  static Future<bool> isArioLauncherEnabled() async {
    try {
      return await _arioChannel.invokeMethod<bool>('launcherEnabled') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> setArioLauncherEnabled(bool enabled) async {
    final result = await _arioChannel.invokeMethod<bool>(
      'setLauncherEnabled',
      {'enabled': enabled},
    );
    return result ?? false;
  }

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

  /// App theme: 'light' (cream) | 'dark'
  String theme;

  /// Text size: 'small' | 'normal' | 'large'
  String textSize;

  /// Layout direction: 'rtl' | 'ltr'
  String direction;
  Settings({
    this.replaceArabic = true,
    this.autoCorrect = true,
    this.kbHeight = 'tall',
    this.theme = 'light',
    this.textSize = 'normal',
    this.direction = 'rtl',
  });

  bool get dark => theme == 'dark';
  double get textScale =>
      textSize == 'small' ? 0.92 : (textSize == 'large' ? 1.13 : 1.0);

  static Future<Settings> load() async {
    final j = await SharedFiles.readJson('souren_settings.json');
    if (j == null) return Settings();
    return Settings(
      replaceArabic: j['replaceArabic'] != false,
      autoCorrect: j['autoCorrect'] != false,
      kbHeight: (j['kbHeight'] as String?) ?? 'tall',
      theme: (j['theme'] as String?) ?? 'light',
      textSize: (j['textSize'] as String?) ?? 'normal',
      direction: (j['direction'] as String?) ?? 'rtl',
    );
  }

  Future<void> save() => SharedFiles.writeJson('souren_settings.json', {
        'replaceArabic': replaceArabic,
        'autoCorrect': autoCorrect,
        'kbHeight': kbHeight,
        'theme': theme,
        'textSize': textSize,
        'direction': direction,
      });
}

/// Shared settings instance + revision bus so the app chrome (theme,
/// direction) rebuilds when the settings page changes a value.
class SettingsStore {
  static Settings current = Settings();
  static final revision = ValueNotifier<int>(0);
  static bool _loaded = false;

  static Future<Settings> ensureLoaded() async {
    if (!_loaded) {
      current = await Settings.load();
      _loaded = true;
    }
    return current;
  }

  static Future<void> update(Settings s) async {
    current = s;
    await s.save();
    revision.value++;
  }
}

/// Word categories (زمینه‌ها و پیشه‌ها), bundled as assets/db/categories.json.
/// Words not listed anywhere belong to the computed «همگانی» category.
class Categories {
  final Map<String, List<String>> cats;
  const Categories(this.cats);

  static const generalId = 'general';

  static Future<Categories> load() async {
    try {
      final raw = await rootBundle.loadString('assets/db/categories.json');
      final j = jsonDecode(raw) as Map<String, dynamic>;
      final m = (j['cats'] as Map<String, dynamic>).map((k, v) => MapEntry(
          k, (v as List).map((e) => e.toString()).toList()));
      return Categories(m);
    } catch (_) {
      return const Categories({});
    }
  }

  String? categoryOf(String ar) {
    for (final e in cats.entries) {
      if (e.value.contains(ar)) return e.key;
    }
    return null;
  }

  List<Entry> inCategory(Dictionary d, String id) {
    if (id == generalId) {
      final assigned = cats.values.expand((v) => v).toSet();
      return d.entries.where((e) => !assigned.contains(e.ar)).toList();
    }
    final words = cats[id] ?? const [];
    final byAr = {for (final e in d.entries) e.ar: e};
    return [for (final w in words) if (byAr[w] != null) byAr[w]!];
  }
}

/// Structured proverb content shared by the home collection, detail
/// cards, saved-items views, and the unified dataset builder.
class Proverbs {
  static Future<List<(String, String)>> load() async {
    try {
      final raw = await rootBundle.loadString('assets/db/proverbs.json');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rows = (data['proverbs'] as List? ?? const [])
          .whereType<Map>()
          .map((row) => (
                row['title']?.toString() ?? '',
                row['meaning']?.toString() ?? '',
              ))
          .where((row) => row.$1.isNotEmpty && row.$2.isNotEmpty)
          .toList(growable: false);
      return rows;
    } catch (_) {
      return const [];
    }
  }
}

// The bundled dictionary and optional user-imported file are local-only.
// ---------------- Profile score & badges (pure logic) ----------------

int profileScore({
  required int favorites,
  required int likes,
  required int learnedWords,
  required int corrections,
}) =>
    favorites * 3 + likes * 2 + learnedWords * 2 + corrections;

const levelThresholds = <(int, String)>[
  (0, 'تازه‌وارد'),
  (25, 'واژه‌جو'),
  (75, 'واژه‌آموز'),
  (150, 'درست‌نویس'),
  (300, 'استاد واژه'),
];

String levelFor(int score) {
  var name = levelThresholds.first.$2;
  for (final t in levelThresholds) {
    if (score >= t.$1) name = t.$2;
  }
  return name;
}

/// Score needed for the next level, or null at the top level.
int? nextLevelAt(int score) {
  for (final t in levelThresholds) {
    if (score < t.$1) return t.$1;
  }
  return null;
}

/// Badge ids in display order; earned-ness is computed by [badgeEarned].
const badgeIds = <String>[
  'member',
  'firstBookmark',
  'liker',
  'keyboardStudent',
  'hundred',
  'collector',
];

bool badgeEarned(
  String id, {
  required bool loggedIn,
  required int favorites,
  required int likes,
  required int corrections,
  required int score,
}) {
  switch (id) {
    case 'member':
      return loggedIn;
    case 'firstBookmark':
      return favorites >= 1;
    case 'liker':
      return likes >= 10;
    case 'keyboardStudent':
      return corrections >= 20;
    case 'hundred':
      return score >= 100;
    case 'collector':
      return favorites >= 25;
    default:
      return false;
  }
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
