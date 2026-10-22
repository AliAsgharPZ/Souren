import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'engine/corrector.dart';

const cream = Color(0xFFF7F1E3);
const card = Color(0xFFEFE7D4);
const pill = Color(0xFFEEE6D2);
const ink = Color(0xFF2B2620);
const muted = Color(0xFF8A8172);
const darkPill = Color(0xFF2E2A24);

String faNum(Object n) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i == null ? (c == ',' ? '٬' : c) : d[i];
  }).join();
}

void main() => runApp(const SourenApp());

class SourenApp extends StatelessWidget {
  const SourenApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'سورن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Arad',
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(seedColor: ink, surface: cream),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: ink, fontSize: 15),
          bodySmall: TextStyle(color: muted, fontSize: 13),
        ),
      ),
      home: const Directionality(
          textDirection: TextDirection.rtl, child: Shell()),
    );
  }
}

class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  Dictionary? dict;
  Settings settings = Settings();
  Set<String> favorites = {};
  int tab = 0;
  String query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Dictionary.load();
    final s = await Settings.load();
    final fav = await SharedFiles.readJson('favorites.json');
    setState(() {
      dict = d;
      settings = s;
      if (fav != null && fav['words'] is List) {
        favorites = (fav['words'] as List).map((e) => e.toString()).toSet();
      }
    });
  }

  Future<void> _toggleFav(String word) async {
    setState(() {
      favorites.contains(word) ? favorites.remove(word) : favorites.add(word);
    });
    await SharedFiles.writeJson('favorites.json', {'words': favorites.toList()});
  }

  void _go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final d = dict;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = <Widget>[
      _home(d),
      _favoritesPage(d),
      _sectionsPage(d),
      _dailyPage(d),
      _learningPage(),
      _settingsPage(d),
    ];
    return Scaffold(
      body: SafeArea(child: pages[tab]),
      bottomNavigationBar: _navBar(),
    );
  }

  Widget _navBar() {
    final items = <(IconData, String)>[
      (Icons.home_rounded, 'پیشگاه'),
      (Icons.bookmark_rounded, 'نشان‌شده‌ها'),
      (Icons.grid_view_rounded, 'بخش‌ها'),
      (Icons.star_rounded, 'واژهٔ روز'),
      (Icons.person_rounded, 'یادگیری من'),
      (Icons.settings_rounded, 'تنظیمات'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(40),
        boxShadow: const [
          BoxShadow(color: Color(0x1A000000), blurRadius: 12, offset: Offset(0, 3))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => _go(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: EdgeInsets.symmetric(
                    horizontal: tab == i ? 16 : 11, vertical: 9),
                decoration: BoxDecoration(
                  color: tab == i ? darkPill : Colors.transparent,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Row(children: [
                  Icon(items[i].$1,
                      size: 21,
                      color: tab == i ? cream : ink.withValues(alpha: .75)),
                  if (tab == i) ...[
                    const SizedBox(width: 7),
                    Text(items[i].$2,
                        style: const TextStyle(
                            color: cream, fontWeight: FontWeight.w700, fontSize: 14)),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- پیشگاه (home, exactly the reference layout) ----------
  Widget _home(Dictionary d) {
    final frequent = d.entries.where((e) => e.hasFa).take(60).toList();
    final results = query.isEmpty
        ? frequent
        : d.entries
            .where((e) =>
                e.ar.contains(query) || e.fa.any((f) => f.contains(query)))
            .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 4),
      child: Column(children: [
        TextField(
          onChanged: (v) => setState(() => query = v.trim()),
          decoration: InputDecoration(
            hintText: 'واژه‌ای را جستجو کنید',
            hintStyle: const TextStyle(color: muted, fontSize: 14),
            prefixIcon: const Icon(Icons.search, color: muted, size: 21),
            filled: true,
            fillColor: card,
            contentPadding: const EdgeInsets.symmetric(vertical: 13),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                        query.isEmpty
                            ? 'پرکاربردترین واژگان فارسی'
                            : 'نتیجه‌های جستجو',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16.5)),
                    const SizedBox(height: 6),
                    Expanded(child: _pairList(results, d)),
                  ]),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 118,
              child: Column(children: [
                _sidePill('گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d))),
                _sidePill('درست‌نویسی', () => _open(CorrectorPage(dict: d))),
                _sidePill('پندواژهٔ نیم‌فاصله',
                    () => _open(const PandPage()), small: true),
                _sidePill('واژه‌های تازه', () => _open(const FreshPage())),
                _sidePill('ریشه‌شناسی', () => _open(EtymologyPage(dict: d))),
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                      color: pill, borderRadius: BorderRadius.circular(18)),
                  child: Column(children: [
                    const Text('شمار همهٔ واژه‌ها',
                        style: TextStyle(fontSize: 12.5, color: ink)),
                    const SizedBox(height: 3),
                    Text(faNum(d.entries.length),
                        style: const TextStyle(
                            fontSize: 21, fontWeight: FontWeight.w700)),
                    Text('(${faNum(d.pairCount)} با برابر فارسی)',
                        style: const TextStyle(fontSize: 10.5, color: muted)),
                  ]),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sidePill(String label, VoidCallback onTap, {bool small = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 9),
        padding: EdgeInsets.symmetric(vertical: small ? 9 : 12),
        decoration: BoxDecoration(
            color: pill, borderRadius: BorderRadius.circular(18)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: small ? 12 : 13.5, color: ink)),
      ),
    );
  }

  Widget _pairList(List<Entry> items, Dictionary d) {
    if (items.isEmpty) {
      return const Center(
          child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: muted)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, color: Color(0xFFE2D8C2)),
      itemBuilder: (_, i) => _pairRow(items[i]),
    );
  }

  Widget _pairRow(Entry e) {
    return InkWell(
      onTap: () => _showEntry(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(children: [
          SizedBox(
            width: 92,
            child: Text(e.ar,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 15)),
          ),
          Expanded(
            child: Text(
              e.hasFa ? e.fa.join('، ') : 'برابر فارسی ثبت نشده',
              textAlign: TextAlign.left,
              style: TextStyle(
                  color: e.hasFa ? muted : const Color(0xFFB4A888),
                  fontSize: 13.5),
            ),
          ),
        ]),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          Directionality(textDirection: TextDirection.rtl, child: page),
    ));
  }

  void _showEntry(Entry e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: cream,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26))),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(e.ar,
                style:
                    const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
            IconButton(
              icon: Icon(
                  favorites.contains(e.ar)
                      ? Icons.star_rounded
                      : Icons.star_border_rounded,
                  color: ink),
              onPressed: () {
                _toggleFav(e.ar);
                Navigator.pop(context);
                _showEntry(e);
              },
            ),
          ]),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                e.hasFa
                    ? 'برابر فارسی: ${e.fa.join('، ')}'
                    : 'برای این واژه هنوز برابر فارسی ثبت نشده است.',
                style: const TextStyle(fontSize: 16, height: 1.7)),
          ),
          const SizedBox(height: 8),
          const Align(
            alignment: Alignment.centerRight,
            child: Text('ریشه: عربی — از پایگاه واژه‌های سورن',
                style: TextStyle(color: muted, fontSize: 12.5)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(backgroundColor: darkPill),
              onPressed: () {
                Clipboard.setData(ClipboardData(
                    text: e.hasFa ? e.fa.first : e.ar));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('کپی شد')));
              },
              child: const Text('کپی برابر فارسی'),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------- نشان‌شده‌ها ----------
  Widget _favoritesPage(Dictionary d) {
    final favs = d.entries.where((e) => favorites.contains(e.ar)).toList();
    return _pageShell('نشان‌شده‌ها',
        favs.isEmpty
            ? const Center(
                child: Text('هنوز واژه‌ای را نشان نکرده‌اید.\nروی ستارهٔ هر واژه بزنید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.8)))
            : _pairList(favs, d));
  }

  // ---------- بخش‌ها ----------
  Widget _sectionsPage(Dictionary d) {
    final tiles = <(IconData, String, VoidCallback)>[
      (Icons.menu_book_rounded, 'گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d))),
      (Icons.spellcheck_rounded, 'درست‌نویسی', () => _open(CorrectorPage(dict: d))),
      (Icons.lightbulb_outline_rounded, 'پندواژهٔ نیم‌فاصله', () => _open(const PandPage())),
      (Icons.new_releases_rounded, 'واژه‌های تازه', () => _open(const FreshPage())),
      (Icons.account_tree_rounded, 'ریشه‌شناسی', () => _open(EtymologyPage(dict: d))),
      (Icons.keyboard_rounded, 'کیبورد سورن', () => _open(const KeyboardGuidePage())),
    ];
    return _pageShell(
      'بخش‌ها',
      GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        padding: const EdgeInsets.all(18),
        children: [
          for (final t in tiles)
            GestureDetector(
              onTap: t.$3,
              child: Container(
                decoration: BoxDecoration(
                    color: pill, borderRadius: BorderRadius.circular(22)),
                child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(t.$1, size: 30, color: ink),
                      const SizedBox(height: 10),
                      Text(t.$2, style: const TextStyle(fontSize: 14.5)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- واژهٔ روز ----------
  Widget _dailyPage(Dictionary d) {
    final withFa = d.entries.where((e) => e.hasFa).toList();
    final now = DateTime.now();
    final idx = (now.year * 372 + now.month * 31 + now.day) % withFa.length;
    final e = withFa[idx];
    return _pageShell(
      'واژهٔ روز',
      Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e.ar,
                style: const TextStyle(
                    fontSize: 38, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            Text('به فارسی: ${e.fa.join('، ')}',
                style: const TextStyle(fontSize: 19, height: 1.7),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => _showEntry(e),
              child: const Text('دیدن واژه'),
            ),
          ]),
        ),
      ),
    );
  }

  // ---------- یادگیری من ----------
  Widget _learningPage() {
    return _pageShell(
      'یادگیری من',
      FutureBuilder<Map<String, dynamic>?>(
        future: SharedFiles.readJson('learned.json'),
        builder: (_, snap) {
          final j = snap.data;
          if (j == null) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(28),
                child: Text(
                    'کیبورد سورن از انتخاب‌ها و اصلاح‌های شما روی همین دستگاه یاد می‌گیرد.\nهنوز چیزی نیاموخته است؛ با کیبورد سورن بنویسید تا اینجا ببینید چه یاد گرفته.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.9)),
              ),
            );
          }
          final counts = (j['counts'] as Map?) ?? {};
          final history = (j['history'] as List?) ?? [];
          final top = counts.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          return ListView(padding: const EdgeInsets.all(20), children: [
            Text('شمار اصلاح‌های پذیرفته‌شده: ${faNum(history.length)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text('واژه‌های آموخته‌شده: ${faNum(counts.length)}',
                style: const TextStyle(fontSize: 16)),
            const Divider(height: 28),
            const Text('پرکاربردترین‌ها نزد شما',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            for (final t in top.take(15))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text('${t.key} — ${faNum(t.value)} بار',
                    style: const TextStyle(color: muted)),
              ),
            const SizedBox(height: 18),
            OutlinedButton(
              onPressed: () async {
                final f = await SharedFiles.file('learned.json');
                if (await f.exists()) await f.delete();
                setState(() {});
              },
              child: const Text('پاک‌کردن آموخته‌ها'),
            ),
          ]);
        },
      ),
    );
  }

  // ---------- تنظیمات ----------
  Widget _settingsPage(Dictionary d) {
    return _pageShell(
      'تنظیمات',
      ListView(padding: const EdgeInsets.all(18), children: [
        SwitchListTile(
          title: const Text('جایگزینی خودکار واژه‌های عربی با فارسی'),
          subtitle: const Text(
              'در کیبورد، واژهٔ عربیِ دارای برابرِ تک‌واژه‌ای، خودکار فارسی می‌شود'),
          value: settings.replaceArabic,
          onChanged: (v) async {
            setState(() => settings.replaceArabic = v);
            await settings.save();
          },
        ),
        SwitchListTile(
          title: const Text('اصلاح خودکار املایی'),
          subtitle: const Text('نیم‌فاصله، همزهٔ اضافه و مانند آن هنگام زدن فاصله'),
          value: settings.autoCorrect,
          onChanged: (v) async {
            setState(() => settings.autoCorrect = v);
            await settings.save();
          },
        ),
        const Divider(height: 30),
        ListTile(
          leading: const Icon(Icons.keyboard_rounded),
          title: const Text('فعال‌کردن کیبورد سورن'),
          subtitle: const Text('تنظیمات کیبورد اندروید باز می‌شود'),
          onTap: () => SharedFiles.openInputSettings(),
        ),
        ListTile(
          leading: const Icon(Icons.swap_horiz_rounded),
          title: const Text('برگزیدن کیبورد سورن به‌عنوان کیبورد کنونی'),
          onTap: () => SharedFiles.showKeyboardPicker(),
        ),
        const Divider(height: 30),
        ListTile(
          leading: const Icon(Icons.system_update_rounded),
          title: const Text('به‌روزرسانی پایگاه واژه‌ها'),
          subtitle: Text(
              'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — فایل JSON یا CSV برگزینید'),
          onTap: () => _importDb(),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_rounded),
          title: const Text('خروجی از پایگاه واژه‌ها'),
          subtitle: const Text('JSON پایگاه در حافظهٔ برنامه ذخیره و مسیرش نشان داده می‌شود'),
          onTap: () => _exportDb(d),
        ),
        const Divider(height: 30),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
              'درباره: سورن دیکشنری عربی به فارسی است با کیبوردی که درست‌نویسی فارسی را رعایت می‌کند. فونت برنامه: آراد. یادگیری کیبورد فقط روی همین دستگاه انجام می‌شود و داده‌ای بیرون نمی‌رود.',
              style: TextStyle(color: muted, height: 1.9, fontSize: 13)),
        ),
      ]),
    );
  }

  Future<void> _importDb() async {
    final content = await PickFile.pickTextFile();
    if (content == null || content.trim().isEmpty) return;
    try {
      Map<String, dynamic> data;
      if (content.trimLeft().startsWith('{')) {
        data = jsonDecode(content) as Map<String, dynamic>;
      } else {
        final entries = <Map<String, dynamic>>[];
        for (final line in const LineSplitter().convert(content)) {
          final parts = line.split(RegExp(r'[,;\t]'));
          if (parts.length >= 2 && parts[0].trim().isNotEmpty) {
            entries.add({
              'ar': parts[0].trim(),
              'fa': parts.sublist(1).map((e) => e.trim()).where((e) => e.isNotEmpty).toList(),
            });
          }
        }
        data = {'version': (dict?.version ?? 1) + 1, 'entries': entries};
      }
      await SharedFiles.writeJson('dataset_updated.json', data);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('پایگاه واژه‌ها به‌روز شد')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('این فایل خوانا نیست؛ JSON یا CSV درست برگزینید')));
      }
    }
  }

  Future<void> _exportDb(Dictionary d) async {
    final f = await SharedFiles.file('dataset_export.json');
    await f.writeAsString(jsonEncode({
      'version': d.version,
      'entries': [
        for (final e in d.entries) {'ar': e.ar, 'fa': e.fa}
      ],
    }));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('ذخیره شد: ${f.path}')));
    }
  }

  Widget _pageShell(String title, Widget body) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(title,
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        ),
      ),
      Expanded(child: body),
    ]);
  }
}

// ================= گنجینهٔ واژه‌ها =================
class LexiconPage extends StatefulWidget {
  final Dictionary dict;
  const LexiconPage({super.key, required this.dict});
  @override
  State<LexiconPage> createState() => _LexiconPageState();
}

class _LexiconPageState extends State<LexiconPage> {
  final _scroll = ScrollController();
  final Map<String, GlobalKey> _keys = {};

  @override
  Widget build(BuildContext context) {
    final entries = [...widget.dict.entries]
      ..sort((a, b) => a.ar.compareTo(b.ar));
    final letters = <String>[];
    for (final e in entries) {
      final c = e.ar.isEmpty ? '' : e.ar[0];
      if (c.isNotEmpty && !letters.contains(c)) letters.add(c);
    }
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        foregroundColor: ink,
        title: const Text('گنجینهٔ واژه‌ها',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: Row(children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: const EdgeInsets.symmetric(horizontal: 18),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              final first = i == 0 || entries[i - 1].ar[0] != e.ar[0];
              return Column(
                key: first ? (_keys[e.ar[0]] ??= GlobalKey()) : null,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (first)
                    Padding(
                      padding: const EdgeInsets.only(top: 12, bottom: 2),
                      child: Text(e.ar[0],
                          style: const TextStyle(
                              color: muted,
                              fontWeight: FontWeight.w700,
                              fontSize: 13)),
                    ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(children: [
                      SizedBox(
                          width: 96,
                          child: Text(e.ar,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600))),
                      Expanded(
                        child: Text(
                          e.hasFa ? e.fa.join('، ') : '—',
                          textAlign: TextAlign.left,
                          style: const TextStyle(color: muted, fontSize: 13.5),
                        ),
                      ),
                    ]),
                  ),
                  const Divider(height: 1, color: Color(0xFFE2D8C2)),
                ],
              );
            },
          ),
        ),
        // نمایهٔ الفبا در لبهٔ راست (مانند ویدیو)
        SizedBox(
          width: 22,
          child: ListView(
            children: [
              for (final l in letters)
                GestureDetector(
                  onTap: () {
                    final k = _keys[l];
                    if (k?.currentContext != null) {
                      Scrollable.ensureVisible(k!.currentContext!,
                          duration: const Duration(milliseconds: 300));
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2.5),
                    child: Text(l,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 10.5, color: muted)),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ================= درست‌نویسی =================
class CorrectorPage extends StatefulWidget {
  final Dictionary dict;
  const CorrectorPage({super.key, required this.dict});
  @override
  State<CorrectorPage> createState() => _CorrectorPageState();
}

class _CorrectorPageState extends State<CorrectorPage> {
  final _ctrl = TextEditingController();
  String _out = '';

  void _run(String v) {
    setState(() => _out =
        correctText(v, dictionary: widget.dict.map, replaceArabic: true));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('درست‌نویسی',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
            'متن بنویسید تا با همان موتوری که در کیبورد سورن کار می‌کند، درست شود:',
            style: TextStyle(color: muted, height: 1.8)),
        const SizedBox(height: 12),
        TextField(
          controller: _ctrl,
          onChanged: _run,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'مثلاً: میخام کتاب ها رو به همه افراد بدم، سوال دارم',
            filled: true,
            fillColor: card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: pill, borderRadius: BorderRadius.circular(18)),
          child: Text(_out.isEmpty ? '…' : _out,
              style: const TextStyle(fontSize: 17, height: 1.8)),
        ),
        if (_out.isNotEmpty) ...[
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: darkPill),
            onPressed: () => Clipboard.setData(ClipboardData(text: _out)),
            child: const Text('کپی متن درست‌شده'),
          ),
        ],
      ]),
    );
  }
}

// ================= پندواژهٔ نیم‌فاصله =================
class PandPage extends StatelessWidget {
  const PandPage({super.key});
  @override
  Widget build(BuildContext context) {
    const items = <(String, String)>[
      ('نیم‌فاصله میان پیشوند و فعل',
          'می‌خوام، نمی‌دونم، می‌رود — میان «می/نمی» و فعل همیشه نیم‌فاصله است، نه فاصلهٔ کامل و نه چسبیده.'),
      ('«ها»ی جمع',
          'کتاب‌ها، واژه‌ها، این‌ها — «ها» با نیم‌فاصله به واژه می‌چسبد.'),
      ('همزهٔ اضافه (ٔ)',
          'همهٔ افراد، خانهٔ من، صفحهٔ نخست — پس از واژه‌های پایان‌یافته به «ه»، نشانهٔ اضافه «ٔ» است، نه «ی»: همه‌ی ✗'),
      ('نیم‌فاصله در ترکیب‌ها',
          'درست‌نویسی، واژه‌نامه، هم‌زمان — جزءهای یک واژهٔ مرکب با نیم‌فاصله به هم می‌پیوندند.'),
      ('فاصله و نشانه‌ها',
          'پیش از «،» و «.» و «؟» فاصله نمی‌آید: سلام، خوبی؟'),
    ];
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('پندواژهٔ نیم‌فاصله',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          for (final it in items)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                  color: pill, borderRadius: BorderRadius.circular(18)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(it.$1,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15.5)),
                    const SizedBox(height: 6),
                    Text(it.$2,
                        style: const TextStyle(
                            color: Color(0xFF5C5546), height: 1.9)),
                  ]),
            ),
        ],
      ),
    );
  }
}

// ================= واژه‌های تازه =================
class FreshPage extends StatelessWidget {
  const FreshPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('واژه‌های تازه',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: FutureBuilder<Map<String, dynamic>?>(
        future: SharedFiles.readJson('learned.json'),
        builder: (_, snap) {
          final history = (snap.data?['history'] as List?) ?? [];
          if (history.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(30),
                child: Text(
                    'واژهٔ تازه‌ای هنوز نیست.\nهر واژه‌ای که کیبورد سورن برایتان اصلاح کند و بپذیرید، اینجا می‌آید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: muted, height: 1.9)),
              ),
            );
          }
          final items = history.reversed.take(60).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: Color(0xFFE2D8C2)),
            itemBuilder: (_, i) {
              final m = items[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 9),
                child: Row(children: [
                  SizedBox(width: 96, child: Text('${m['from']}')),
                  const Icon(Icons.arrow_back, size: 15, color: muted),
                  const SizedBox(width: 10),
                  Text('${m['to']}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

// ================= ریشه‌شناسی =================
class EtymologyPage extends StatefulWidget {
  final Dictionary dict;
  const EtymologyPage({super.key, required this.dict});
  @override
  State<EtymologyPage> createState() => _EtymologyPageState();
}

class _EtymologyPageState extends State<EtymologyPage> {
  String _result = '';

  void _check(String v) {
    final w = v.trim();
    if (w.isEmpty) {
      setState(() => _result = '');
      return;
    }
    final inAr = widget.dict.entries.where((e) => e.ar == w);
    if (inAr.isNotEmpty) {
      final e = inAr.first;
      setState(() => _result = e.hasFa
          ? '«$w» واژه‌ای عربی است که در فارسی به کار می‌رود.\nبرابر فارسی آن: ${e.fa.join('، ')}'
          : '«$w» واژه‌ای عربی است؛ هنوز برابر فارسی برایش ثبت نشده.');
      return;
    }
    final asFa = widget.dict.entries
        .where((e) => e.fa.any((f) => f.split('،').map((x) => x.trim()).contains(w) || f == w));
    if (asFa.isNotEmpty) {
      setState(() => _result =
          '«$w» واژه‌ای فارسی است (برابرِ «${asFa.first.ar}»).');
      return;
    }
    setState(() => _result = '«$w» در گنجینهٔ کنونی سورن نیست.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('ریشه‌شناسی',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(children: [
          TextField(
            onChanged: _check,
            decoration: InputDecoration(
              hintText: 'واژه‌ای بنویسید تا ریشه‌اش را ببینید',
              filled: true,
              fillColor: card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 18),
          Text(_result, style: const TextStyle(fontSize: 16.5, height: 1.9)),
        ]),
      ),
    );
  }
}

// ================= راهنمای کیبورد =================
class KeyboardGuidePage extends StatelessWidget {
  const KeyboardGuidePage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('کیبورد سورن',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(padding: const EdgeInsets.all(20), children: [
        const Text(
            'کیبورد سورن همان چیدمان آشنای کیبورد سامسونگ را دارد، با این تفاوت‌ها:\n\n'
            '• هنگام زدن فاصله، املای واژه درست می‌شود: میخام ← می‌خوام.\n'
            '• اگر «جایگزینی خودکار» روشن باشد، واژه‌های عربیِ دارای برابر فارسیِ تک‌واژه‌ای، خودکار فارسی می‌شوند؛ برابرهای چندواژه‌ای در نوار پیشنهاد بالای کیبورد می‌آیند.\n'
            '• روی هر کلید نگه دارید تا نویسهٔ دومش را ببینید (مثل ص ← ض).\n'
            '• کیبورد از انتخاب‌های شما روی همین دستگاه یاد می‌گیرد؛ پیشنهادها کم‌کم به سلیقهٔ شما نزدیک‌تر می‌شوند.\n\n'
            'برای فعال‌کردن: نخست از دکمهٔ زیر تنظیمات کیبورد را باز کنید و «کیبورد سورن» را روشن کنید، سپس آن را به‌عنوان کیبورد کنونی برگزینید.',
            style: TextStyle(height: 2, fontSize: 15)),
        const SizedBox(height: 18),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: darkPill),
          onPressed: () => SharedFiles.openInputSettings(),
          child: const Text('بازکردن تنظیمات کیبورد اندروید'),
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: () => SharedFiles.showKeyboardPicker(),
          child: const Text('برگزیدن کیبورد کنونی'),
        ),
      ]),
    );
  }
}
