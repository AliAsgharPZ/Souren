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

  /// Clears the cached filesDir so a later call re-resolves it. Used by
  /// tests that point the channel at a fresh temp directory.
  @visibleForTesting
  static void resetDirCache() {
    _dir = null;
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

  /// Writes JSON atomically: the data lands in a temp file first and is
  /// renamed over the target, so a crash/interrupt can never leave a
  /// half-written dataset or settings file behind.
  static Future<void> writeJsonAtomic(String name, Object data) async {
    final target = await file(name);
    final tmp = File('${target.path}.tmp');
    await tmp.writeAsString(jsonEncode(data), flush: true);
    try {
      await tmp.rename(target.path);
    } catch (_) {
      await target.writeAsString(jsonEncode(data));
      try {
        if (await tmp.exists()) await tmp.delete();
      } catch (_) {}
    }
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

/// Native share/save/copy support (owner A10) — implemented over the
/// existing 'souren/files' channel in MainActivity, so no share package
/// is needed.
class SharePlatform {
  static const _channel = MethodChannel('souren/files');

  static Future<void> shareText(String text) async {
    try {
      await _channel.invokeMethod('shareText', {'text': text});
    } catch (_) {}
  }

  static Future<void> shareImage(Uint8List png, {String? text}) async {
    try {
      await _channel.invokeMethod('shareImage', {'png': png, 'text': text});
    } catch (_) {}
  }

  /// Saves the PNG to the phone gallery; returns the path or null.
  static Future<String?> saveImage(Uint8List png) async {
    try {
      return await _channel.invokeMethod<String>('saveImage', {'png': png});
    } catch (_) {
      return null;
    }
  }

  /// Copies the PNG to the clipboard (as an image URI clip).
  static Future<bool> copyImage(Uint8List png) async {
    try {
      return await _channel.invokeMethod<bool>('copyImage', {'png': png}) ??
          false;
    } catch (_) {
      return false;
    }
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

  /// Updated dataset in filesDir wins over the bundled asset — but ONLY
  /// after strict validation (owner B2/B6): a malformed, corrupt or
  /// half-written dataset_updated.json is ignored and the bundled
  /// dataset keeps the app (and the keyboard) working.
  static Future<Dictionary> load() async {
    final updated = await SharedFiles.readJson('dataset_updated.json');
    if (updated != null) {
      final check = validateDatasetMap(updated);
      if (check.ok) {
        try {
          return _parse(updated, true);
        } catch (_) {}
      }
    }
    final raw = await rootBundle.loadString('assets/db/dataset.json');
    return _parse(jsonDecode(raw) as Map<String, dynamic>, false);
  }
}

// ---------------- Dataset validation (import + load safety) ----------------

/// Result of validating an imported/updated dataset (owner B6).
class DatasetCheck {
  final bool ok;
  final String? error;
  final Map<String, dynamic>? data;
  const DatasetCheck(this.ok, {this.error, this.data});
}

/// Validates a decoded dataset map: top-level object, `entries` array,
/// every entry needs a non-empty `ar` string and a `fa` string array,
/// and the version metadata must be a positive integer. Duplicate
/// Arabic keys are reported as errors, never silently dropped.
DatasetCheck validateDatasetMap(Map<String, dynamic>? j) {
  if (j == null) {
    return const DatasetCheck(false, error: 'فایل، یک شیء JSON نیست');
  }
  final entries = j['entries'];
  if (entries is! List) {
    return const DatasetCheck(false, error: '«entries» یک فهرست نیست');
  }
  final version = j['version'];
  if (version is! num || version <= 0 || version % 1 != 0) {
    return const DatasetCheck(
      false,
      error: '«version» باید یک عدد صحیح مثبت باشد',
    );
  }
  final seen = <String>{};
  for (var i = 0; i < entries.length; i++) {
    final e = entries[i];
    if (e is! Map) {
      return DatasetCheck(false, error: 'مدخل ${i + 1} یک شیء نیست');
    }
    final ar = e['ar'];
    if (ar is! String || ar.trim().isEmpty) {
      return DatasetCheck(
        false,
        error: 'مدخل ${i + 1} واژهٔ عربی ندارد یا خالی است',
      );
    }
    final fa = e['fa'];
    if (fa is! List) {
      return DatasetCheck(
        false,
        error: '«fa» در مدخل «${ar.trim()}» یک فهرست نیست',
      );
    }
    for (final f in fa) {
      if (f is! String) {
        return DatasetCheck(
          false,
          error: 'برابرهای «${ar.trim()}» باید رشته باشند',
        );
      }
    }
    if (!seen.add(ar.trim())) {
      return DatasetCheck(
        false,
        error: 'واژهٔ تکراری: «${ar.trim()}»',
      );
    }
  }
  return DatasetCheck(true, data: j);
}

/// Minimal RFC-4180-style CSV record reader: quoted fields may hold
/// separators, newlines and escaped ("") quotes, which the old
/// split-on-comma destroyed.
List<List<String>> parseCsvRecords(String content) {
  final rows = <List<String>>[];
  final field = StringBuffer();
  var row = <String>[];
  var inQuotes = false;
  var i = 0;

  void endField() {
    row.add(field.toString());
    field.clear();
  }

  void endRow() {
    endField();
    rows.add(row);
    row = <String>[];
  }

  while (i < content.length) {
    final c = content[i];
    if (inQuotes) {
      if (c == '"') {
        if (i + 1 < content.length && content[i + 1] == '"') {
          field.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      field.write(c);
      i++;
      continue;
    }
    if (c == '"' && field.isEmpty) {
      inQuotes = true;
      i++;
      continue;
    }
    if (c == '\r') {
      i++;
      continue;
    }
    if (c == '\n') {
      endRow();
      i++;
      continue;
    }
    if (c == ',' || c == ';' || c == '\t') {
      endField();
      i++;
      continue;
    }
    field.write(c);
    i++;
  }
  if (field.isNotEmpty || row.isNotEmpty) endRow();
  return rows;
}

/// Validates raw imported TEXT (JSON or CSV) into a dataset map. Never
/// writes anything: the caller replaces the live dataset only when
/// [DatasetCheck.ok] is true.
DatasetCheck validateDatasetText(String content) {
  final trimmed = content.trimLeft();
  if (trimmed.startsWith('{') || trimmed.startsWith('[')) {
    Map<String, dynamic> decoded;
    try {
      final j = jsonDecode(content);
      if (j is! Map<String, dynamic>) {
        return const DatasetCheck(
          false,
          error: 'بالای فایل باید یک شیء JSON باشد',
        );
      }
      decoded = j;
    } catch (_) {
      return const DatasetCheck(false, error: 'JSON درست خوانده نشد');
    }
    return validateDatasetMap(decoded);
  }
  // CSV: ar,fa[,fa…]
  final rows = parseCsvRecords(content);
  final entries = <Map<String, dynamic>>[];
  final seen = <String>{};
  for (var r = 0; r < rows.length; r++) {
    final cells = rows[r].map((c) => c.trim()).toList();
    if (cells.every((c) => c.isEmpty)) continue;
    // A leading «ar,fa» header row is metadata, not a word.
    if (r == 0 && cells.first.toLowerCase() == 'ar' && cells.length > 1) {
      continue;
    }
    if (cells.length < 2) {
      return DatasetCheck(
        false,
        error: 'سطر ${r + 1} دست‌کم دو ستون (واژه، برابر) دارد؟',
      );
    }
    final ar = cells.first;
    if (ar.isEmpty) {
      return DatasetCheck(
        false,
        error: 'سطر ${r + 1} واژهٔ عربی ندارد یا خالی است',
      );
    }
    final fa = cells.sublist(1).where((c) => c.isNotEmpty).toList();
    if (!seen.add(ar)) {
      return DatasetCheck(false, error: 'واژهٔ تکراری: «$ar»');
    }
    entries.add({'ar': ar, 'fa': fa});
  }
  if (entries.isEmpty) {
    return const DatasetCheck(false, error: 'هیچ مدخلی در فایل نیست');
  }
  return DatasetCheck(true, data: {
    'version': 0, // caller fills the real next version
    'entries': entries,
  });
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
  /// Overridable (instead of const) so tests can point it at a dead
  /// local port and prove the app works fully offline.
  static String base = 'https://souren.aliasgharpanahizare.workers.dev';
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
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 10);
    final req = await client
        .openUrl(method, Uri.parse('$base$path'))
        .timeout(const Duration(seconds: 15));
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
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client
          .getUrl(Uri.parse('$base/api/likes'))
          .timeout(const Duration(seconds: 15));
      final res = await req.close().timeout(const Duration(seconds: 15));
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

// ---------------- Dictionary auto-update (Worker) ----------------

/// Keeps the on-device dictionary in sync with the Worker dataset.
/// Online: fetch /api/dictionary, transform the server shape
/// ({dictionary: [{arabic, meanings}]}) into the app shape
/// ({version, entries: [{ar, fa}]}) and, when the content differs,
/// store it as dataset_updated.json (the archive Dictionary.load and
/// the keyboard both prefer). Offline: nothing changes — the last
/// downloaded archive (or the bundled dataset) keeps working.
class DictionarySync {
  static bool _running = false;

  /// Returns true when a newer dataset was downloaded and stored.
  static Future<bool> syncFromServer(Dictionary current) async {
    if (_running) return false;
    _running = true;
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 10);
      final req = await client
          .getUrl(Uri.parse('${AuthService.base}/api/dictionary'))
          .timeout(const Duration(seconds: 15));
      final res = await req.close().timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) return false;
      final text = await res.transform(utf8.decoder).join();
      final j = jsonDecode(text) as Map<String, dynamic>;
      final list = (j['dictionary'] as List?) ?? const [];
      final entries = <Map<String, dynamic>>[
        for (final e in list)
          if (e is Map && e['arabic'] != null)
            {
              'ar': e['arabic'].toString(),
              'fa': ((e['meanings'] as List?) ?? const [])
                  .map((x) => x.toString())
                  .toList(),
            },
      ];
      if (entries.isEmpty) return false;
      if (_sameAs(entries, current)) return false;
      final candidate = {
        'version': current.version + 1,
        'entries': entries,
      };
      // Validate before replacing a working dataset (owner B2).
      final check = validateDatasetMap(candidate);
      if (!check.ok) return false;
      await SharedFiles.writeJsonAtomic('dataset_updated.json', candidate);
      return true;
    } catch (_) {
      return false; // offline: keep the archive on the device
    } finally {
      _running = false;
    }
  }

  static bool _sameAs(List<Map<String, dynamic>> entries, Dictionary d) {
    if (entries.length != d.entries.length) return false;
    for (var i = 0; i < entries.length; i++) {
      final a = entries[i];
      final b = d.entries[i];
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
