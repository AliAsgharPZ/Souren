import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Shared on-device storage. The dictionary app and the keyboard (IME)
/// live in the same Android package, so both read/write the same
/// filesDir — that is how the keyboard learns and the app shows it.
class SharedFiles {
  static String? _dir;
  static const _channel = MethodChannel('souren/files');
  static const _arioChannel = MethodChannel('souren/ario');

  static Future<bool> consumeArioLaunch() async {
    try {
      return await _arioChannel.invokeMethod<bool>('consumeArioLaunch') ?? false;
    } catch (_) {
      return false;
    }
  }

  static void setArioLaunchHandler(VoidCallback onOpen) {
    _arioChannel.setMethodCallHandler((call) async {
      if (call.method == 'openArio') onOpen();
    });
  }

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
  final String concept;
  const Entry(this.ar, this.fa, {this.concept = ''});
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
      return Entry(
        m['ar'] as String,
        ((m['fa'] as List?) ?? const []).map((x) => x.toString()).toList(),
        concept: (m['concept'] as String?) ?? '',
      );
    }).toList();
    return Dictionary(list, (j['version'] as num?)?.toInt() ?? 1, fromUpdate);
  }

  /// Updated dataset in filesDir wins over the bundled asset.
  static Future<Dictionary> load() async {
    final raw = await rootBundle.loadString('assets/db/dataset.json');
    final bundled = _parse(jsonDecode(raw) as Map<String, dynamic>, false);
    final updated = await SharedFiles.readJson('dataset_updated.json');
    if (updated != null) {
      try {
        final candidate = _parse(updated, true);
        // A previously imported v1/v2 dataset must not hide the newer
        // canonical 552-word v3 bundle after the app is upgraded.
        if (candidate.version > bundled.version ||
            (candidate.version == bundled.version &&
                candidate.entries.length >= bundled.entries.length)) {
          return candidate;
        }
      } catch (_) {}
    }
    return bundled;
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
// Read-only dictionary pull. It never uploads profile, keyboard or learning data.
class DictionarySync {
  static const base = 'https://souren.aliasgharpanahizare.workers.dev';
  static bool _running = false;
  static const _weeklyStateFile = 'dictionary_sync.json';
  static const _weekMs = 7 * 24 * 60 * 60 * 1000;

  /// One conditional dictionary check per randomized weekly window.
  /// Persist the next attempt before networking to prevent duplicate requests.
  static Future<bool> syncWeekly(Dictionary current) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final state = await SharedFiles.readJson(_weeklyStateFile);
    final nextAt = (state?['nextAt'] as num?)?.toInt();
    final random = Random.secure();
    if (nextAt == null) {
      final firstDelay = random.nextInt(_weekMs);
      await SharedFiles.writeJson(_weeklyStateFile, {
        'nextAt': now + firstDelay,
        'lastScheduledAt': now,
      });
      if (firstDelay > 0) return false;
    } else if (now < nextAt) {
      return false;
    }

    final nextDelay = _weekMs + random.nextInt(24 * 60 * 60 * 1000);
    await SharedFiles.writeJson(_weeklyStateFile, {
      'nextAt': now + nextDelay,
      'lastScheduledAt': now,
    });
    return syncFromServer(current);
  }

  static Future<bool> syncFromServer(Dictionary current) async {
    if (_running) return false;
    _running = true;
    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
      final req = await client.getUrl(Uri.parse('$base/api/dictionary')).timeout(const Duration(seconds: 15));
      req.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final text = await res.transform(utf8.decoder).join();
      final json = jsonDecode(text) as Map<String, dynamic>;
      final list = (json['dictionary'] as List?) ?? const [];
      final entries = <Map<String, dynamic>>[
        for (final item in list)
          if (item is Map && item['arabic'] != null)
            {
              'ar': item['arabic'].toString(),
              'fa': ((item['meanings'] as List?) ?? const []).map((x) => x.toString()).toList(),
            },
      ];
      if (entries.isEmpty || _sameAs(entries, current)) return false;
      await SharedFiles.writeJson('dataset_updated.json', {
        'version': current.version + 1,
        'entries': entries,
      });
      return true;
    } catch (_) {
      return false;
    } finally {
      client?.close(force: true);
      _running = false;
    }
  }

  static bool _sameAs(List<Map<String, dynamic>> entries, Dictionary dictionary) {
    if (entries.length != dictionary.entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      final a = entries[i];
      final b = dictionary.entries[i];
      if (a['ar'] != b.ar) return false;
      final fa = (a['fa'] as List).map((x) => x.toString()).toList();
      if (fa.length != b.fa.length) return false;
      for (var k = 0; k < fa.length; k++) {
        if (fa[k] != b.fa[k]) return false;
      }
    }
    return true;
  }
}

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
