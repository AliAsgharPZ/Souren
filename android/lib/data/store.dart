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

  /// App font: 'arad' | 'system'
  String font;

  /// Text size: 'small' | 'normal' | 'large'
  String textSize;

  /// Layout direction: 'rtl' | 'ltr'
  String direction;
  Settings({
    this.replaceArabic = true,
    this.autoCorrect = true,
    this.kbHeight = 'tall',
    this.theme = 'light',
    this.font = 'arad',
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
      font: (j['font'] as String?) ?? 'arad',
      textSize: (j['textSize'] as String?) ?? 'normal',
      direction: (j['direction'] as String?) ?? 'rtl',
    );
  }

  Future<void> save() => SharedFiles.writeJson('souren_settings.json', {
        'replaceArabic': replaceArabic,
        'autoCorrect': autoCorrect,
        'kbHeight': kbHeight,
        'theme': theme,
        'font': font,
        'textSize': textSize,
        'direction': direction,
      });
}

/// Shared settings instance + revision bus so the app chrome (theme,
/// font, direction) rebuilds when the settings page changes a value.
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

// ---------------- Auth + likes (Worker API) ----------------

class AuthUser {
  final String username;
  final String displayName;
  const AuthUser(this.username, this.displayName);
}

/// Talks to the Souren Worker (same backend as the website login).
/// The session cookie is kept only in the app's private filesDir.
class AuthService {
  static const base = 'https://souren.aliasgharpanahizare.workers.dev';
  static String? _cookie;
  static AuthUser? user;

  static Future<void> restore() async {
    final j = await SharedFiles.readJson('auth.json');
    if (j == null) return;
    _cookie = j['cookie'] as String?;
    final u = j['username'] as String?;
    if (_cookie != null && u != null) {
      user = AuthUser(u, (j['displayName'] as String?) ?? u);
    }
  }

  static Future<void> _persist() async {
    if (_cookie == null || user == null) {
      final f = await SharedFiles.file('auth.json');
      if (await f.exists()) await f.delete();
      return;
    }
    await SharedFiles.writeJson('auth.json', {
      'cookie': _cookie,
      'username': user!.username,
      'displayName': user!.displayName,
    });
  }

  static Future<HttpClientResponse> _send(
      String method, String path, Map<String, dynamic>? body) async {
    final client = HttpClient();
    final req = await client.openUrl(method, Uri.parse('$base$path'));
    req.headers.contentType = ContentType.json;
    if (_cookie != null) req.headers.add('Cookie', _cookie!);
    if (body != null) req.write(jsonEncode(body));
    final res = await req.close();
    final setCookie = res.headers['set-cookie'];
    if (setCookie != null) {
      for (final sc in setCookie) {
        final pair = sc.split(';').first.trim();
        if (pair.startsWith('souren_session=')) {
          final v = pair.substring('souren_session='.length);
          _cookie = v.isEmpty ? null : 'souren_session=$v';
        }
      }
    }
    return res;
  }

  static Future<Map<String, dynamic>> _json(HttpClientResponse res) async {
    final text = await res.transform(utf8.decoder).join();
    try {
      return jsonDecode(text) as Map<String, dynamic>;
    } catch (_) {
      return {'error': 'پاسخ سرور خوانا نیست'};
    }
  }

  static AuthUser _userFrom(Map<String, dynamic> j) {
    final u = j['user'] as Map<String, dynamic>;
    return AuthUser(u['username'] as String,
        (u['displayName'] as String?) ?? u['username'] as String);
  }

  /// Returns (user, null) on success or (null, errorMessage).
  static Future<(AuthUser?, String?)> register(
      String username, String password, String displayName) async {
    try {
      final res = await _send('POST', '/api/auth/register', {
        'username': username,
        'password': password,
        'displayName': displayName,
      });
      final j = await _json(res);
      if (res.statusCode >= 400) return (null, j['error']?.toString() ?? 'خطا رخ داد');
      user = _userFrom(j);
      // register does not start a session on the server; log in right away.
      return await login(username, password);
    } catch (_) {
      return (null, 'ارتباط با سرور برقرار نشد');
    }
  }

  static Future<(AuthUser?, String?)> login(
      String username, String password) async {
    try {
      final res = await _send(
          'POST', '/api/auth/login', {'username': username, 'password': password});
      final j = await _json(res);
      if (res.statusCode >= 400) return (null, j['error']?.toString() ?? 'خطا رخ داد');
      user = _userFrom(j);
      await _persist();
      return (user, null);
    } catch (_) {
      return (null, 'ارتباط با سرور برقرار نشد');
    }
  }

  static Future<void> logout() async {
    try {
      await _send('POST', '/api/auth/logout', null);
    } catch (_) {}
    _cookie = null;
    user = null;
    await _persist();
  }

  /// Fetches the server profile: (favorites, likes) or null when offline.
  static Future<(Set<String>, Set<String>)?> fetchProfile() async {
    if (_cookie == null) return null;
    try {
      final res = await _send('GET', '/api/auth/me', null);
      if (res.statusCode >= 400) return null;
      final j = await _json(res);
      final u = j['user'] as Map<String, dynamic>;
      user = AuthUser(u['username'] as String,
          (u['displayName'] as String?) ?? u['username'] as String);
      await _persist();
      Set<String> pick(String k) =>
          ((u[k] as List?) ?? const []).map((e) => e.toString()).toSet();
      return (pick('favorites'), pick('likes'));
    } catch (_) {
      return null;
    }
  }

  static Future<void> pushProfile(Set<String> favorites, Set<String> likes) async {
    if (_cookie == null) return;
    try {
      await _send('PUT', '/api/auth/profile',
          {'favorites': favorites.toList(), 'likes': likes.toList()});
    } catch (_) {}
  }

  /// Public like counts for all words: {arabicWord: count}.
  static Future<Map<String, int>> fetchLikeCounts() async {
    try {
      final client = HttpClient();
      final req = await client.getUrl(Uri.parse('$base/api/likes'));
      final res = await req.close();
      final j = await _json(res);
      final counts = (j['counts'] as Map<String, dynamic>?) ?? {};
      return counts.map((k, v) => MapEntry(k, (v as num).toInt()));
    } catch (_) {
      return {};
    }
  }

  /// Sets the user's like for [ar]; returns the new global count or null.
  static Future<int?> setLike(String ar, bool liked) async {
    if (_cookie == null) return null;
    try {
      final res = await _send('POST', '/api/likes', {'ar': ar, 'liked': liked});
      if (res.statusCode >= 400) return null;
      final j = await _json(res);
      return (j['count'] as num?)?.toInt();
    } catch (_) {
      return null;
    }
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
