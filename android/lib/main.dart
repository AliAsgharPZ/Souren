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
const selectedPill = Color(0xFF6E6455); // soft, not too dark
const dividerC = Color(0xFFE2D8C2);

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
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        }),
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

/// Soft fade+rise entrance, staggered by [index].
class Stagger extends StatelessWidget {
  final int index;
  final Widget child;
  const Stagger({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 260 + (index % 12) * 35),
      curve: Curves.easeOutCubic,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 10 * (1 - v)), child: c),
      ),
      child: child,
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
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
        ),
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  Widget _navBar() {
    // (outlined, filled, label) — linear & soft; selected becomes filled.
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'پیشگاه'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'نشان‌شده‌ها'),
      (Icons.widgets_outlined, Icons.widgets_rounded, 'بخش‌ها'),
      (Icons.star_border_rounded, Icons.star_rounded, 'واژهٔ روز'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'یادگیری من'),
      (Icons.settings_outlined, Icons.settings_rounded, 'تنظیمات'),
    ];
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 26),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(44),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (var i = 0; i < items.length; i++)
            GestureDetector(
              onTap: () => _go(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: EdgeInsets.symmetric(
                    horizontal: tab == i ? 17 : 12, vertical: 11),
                decoration: BoxDecoration(
                  color: tab == i ? selectedPill : Colors.transparent,
                  borderRadius: BorderRadius.circular(32),
                ),
                child: Row(children: [
                  Icon(tab == i ? items[i].$2 : items[i].$1,
                      size: 23,
                      color: tab == i ? cream : ink.withValues(alpha: .72)),
                  if (tab == i) ...[
                    const SizedBox(width: 7),
                    Text(items[i].$3,
                        style: const TextStyle(
                            color: cream,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5)),
                  ],
                ]),
              ),
            ),
        ],
      ),
    );
  }

  // ---------- پیشگاه ----------
  Widget _home(Dictionary d) {
    final frequent = d.entries.where((e) => e.hasFa).take(60).toList();
    final results = query.isEmpty
        ? frequent
        : d.entries
            .where((e) =>
                e.ar.contains(query) || e.fa.any((f) => f.contains(query)))
            .toList();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 6),
      child: Column(children: [
        // جای لوگو (در نسخه‌های بعد می‌آید) — اشیاء پایین‌تر شروع می‌شوند
        const SizedBox(height: 58),
        SizedBox(
          height: 58,
          child: TextField(
            onChanged: (v) => setState(() => query = v.trim()),
            decoration: InputDecoration(
              hintText: 'واژه‌ای را جستجو کنید',
              hintStyle: const TextStyle(color: muted, fontSize: 14.5),
              prefixIcon: const Icon(Icons.search_rounded, color: muted, size: 23),
              filled: true,
              fillColor: card,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(30),
                  borderSide: BorderSide.none),
            ),
          ),
        ),
        const SizedBox(height: 26),
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
                            fontWeight: FontWeight.w700, fontSize: 17.5)),
                    const SizedBox(height: 10),
                    Expanded(child: _fadedPairList(results)),
                  ]),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 124,
              child: SingleChildScrollView(
                child: Column(children: [
                  _sidePill('گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d))),
                  _sidePill('درست‌نویسی', () => _open(CorrectorPage(dict: d))),
                  _sidePill('نیم‌فاصله', () => _open(const NimeFaselePage())),
                  _sidePill('پندواژه', () => _open(const PandvazhePage())),
                  _sidePill('واژه‌های تازه', () => _open(const FreshPage())),
                  _sidePill('ریشه‌شناسی', () => _open(EtymologyPage(dict: d))),
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                        color: pill, borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      const Text('شمار همهٔ واژه‌ها',
                          style: TextStyle(fontSize: 13, color: ink)),
                      const SizedBox(height: 4),
                      Text(faNum(d.entries.length),
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w700)),
                      Text('(${faNum(d.pairCount)} با برابر فارسی)',
                          style: const TextStyle(fontSize: 11, color: muted)),
                    ]),
                  ),
                ]),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _sidePill(String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
            color: pill, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: ink)),
      ),
    );
  }

  /// Pair list with soft scroll fade at top and bottom edges.
  Widget _fadedPairList(List<Entry> items) {
    if (items.isEmpty) {
      return const Center(
          child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: muted)));
    }
    return ShaderMask(
      shaderCallback: (rect) => const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
        stops: [0, 0.045, 0.955, 1],
      ).createShader(rect),
      blendMode: BlendMode.dstIn,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 6),
        itemCount: items.length,
        separatorBuilder: (_, __) => const Divider(height: 1, color: dividerC),
        itemBuilder: (_, i) => Stagger(index: i, child: _pairRow(items[i])),
      ),
    );
  }

  Widget _pairList(List<Entry> items) {
    if (items.isEmpty) {
      return const Center(
          child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: muted)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => const Divider(height: 1, color: dividerC),
      itemBuilder: (_, i) => _pairRow(items[i]),
    );
  }

  /// فارسی پررنگ و درشت (مهم‌تر)، عربی کوچک و کم‌رنگ.
  Widget _pairRow(Entry e) {
    return InkWell(
      onTap: () => _showEntry(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(children: [
          Expanded(
            child: Text(
              e.hasFa ? e.fa.join('، ') : 'برابر فارسی ثبت نشده',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16.5,
                  color: e.hasFa ? ink : const Color(0xFFB4A888)),
            ),
          ),
          const SizedBox(width: 10),
          Text(e.ar,
              style: const TextStyle(color: muted, fontSize: 13.5)),
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
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Expanded(
              child: Text(e.hasFa ? e.fa.join('، ') : e.ar,
                  style: const TextStyle(
                      fontSize: 25, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              icon: Icon(
                  favorites.contains(e.ar)
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: ink),
              onPressed: () {
                _toggleFav(e.ar);
                Navigator.pop(context);
                _showEntry(e);
              },
            ),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                e.hasFa
                    ? 'واژهٔ عربی: ${e.ar} — ریشه: عربی'
                    : 'برای این واژه هنوز برابر فارسی ثبت نشده است.',
                style:
                    const TextStyle(color: muted, fontSize: 14, height: 1.8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: selectedPill,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () {
                Clipboard.setData(
                    ClipboardData(text: e.hasFa ? e.fa.first : e.ar));
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
    return _pageShell(
        'نشان‌شده‌ها',
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: favs.isEmpty
              ? const Center(
                  child: Text(
                      'هنوز واژه‌ای را نشان نکرده‌اید.\nروی نشانکِ هر واژه بزنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: muted, height: 1.9)))
              : _pairList(favs),
        ));
  }

  // ---------- بخش‌ها (همهٔ قابلیت‌ها) ----------
  Widget _sectionsPage(Dictionary d) {
    final tiles = <(IconData, String, VoidCallback)>[
      (Icons.menu_book_rounded, 'گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d))),
      (Icons.spellcheck_rounded, 'درست‌نویسی', () => _open(CorrectorPage(dict: d))),
      (Icons.space_bar_rounded, 'نیم‌فاصله', () => _open(const NimeFaselePage())),
      (Icons.format_quote_rounded, 'پندواژه', () => _open(const PandvazhePage())),
      (Icons.account_tree_rounded, 'ریشه‌شناسی', () => _open(EtymologyPage(dict: d))),
      (Icons.new_releases_rounded, 'واژه‌های تازه', () => _open(const FreshPage())),
      (Icons.bookmark_rounded, 'نشان‌شده‌ها', () => _go(1)),
      (Icons.star_rounded, 'واژهٔ روز', () => _go(3)),
      (Icons.school_rounded, 'یادگیری من', () => _go(4)),
      (Icons.keyboard_rounded, 'کیبورد سورن', () => _open(const KeyboardGuidePage())),
      (Icons.system_update_rounded, 'به‌روزرسانی پایگاه', () => _go(5)),
      (Icons.settings_rounded, 'تنظیمات', () => _go(5)),
    ];
    return _pageShell(
      'بخش‌ها',
      GridView.count(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 1.25,
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        children: [
          for (var i = 0; i < tiles.length; i++)
            Stagger(
              index: i,
              child: GestureDetector(
                onTap: tiles[i].$3,
                child: Container(
                  decoration: BoxDecoration(
                      color: pill, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tiles[i].$1, size: 32, color: ink),
                        const SizedBox(height: 11),
                        Text(tiles[i].$2,
                            style: const TextStyle(fontSize: 15)),
                      ]),
                ),
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
          padding: const EdgeInsets.all(30),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(e.hasFa ? e.fa.first : e.ar,
                style: const TextStyle(
                    fontSize: 40, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text('برابرِ واژهٔ عربی «${e.ar}»',
                style: const TextStyle(color: muted, fontSize: 15)),
            const SizedBox(height: 14),
            Text(e.fa.join('، '),
                style: const TextStyle(fontSize: 19, height: 1.7),
                textAlign: TextAlign.center),
            const SizedBox(height: 22),
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
                padding: EdgeInsets.all(30),
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
          return ListView(padding: const EdgeInsets.all(24), children: [
            Text('شمار اصلاح‌های پذیرفته‌شده: ${faNum(history.length)}',
                style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 6),
            Text('واژه‌های آموخته‌شده: ${faNum(counts.length)}',
                style: const TextStyle(fontSize: 16)),
            const Divider(height: 30),
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
      ListView(padding: const EdgeInsets.all(22), children: [
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
        const Divider(height: 32),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('ارتفاع کیبورد',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'short', label: Text('کوتاه')),
              ButtonSegment(value: 'normal', label: Text('معمولی')),
              ButtonSegment(value: 'tall', label: Text('بلند')),
            ],
            selected: {settings.kbHeight},
            onSelectionChanged: (s) async {
              setState(() => settings.kbHeight = s.first);
              await settings.save();
            },
          ),
        ),
        const Divider(height: 32),
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
        const Divider(height: 32),
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
        const Divider(height: 32),
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
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Align(
          alignment: Alignment.centerRight,
          child: Text(title,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
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
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.transparent, Colors.black, Colors.black, Colors.transparent],
              stops: [0, 0.03, 0.97, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 4),
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
                        padding: const EdgeInsets.only(top: 14, bottom: 2),
                        child: Text(e.ar[0],
                            style: const TextStyle(
                                color: muted,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            e.hasFa ? e.fa.join('، ') : '—',
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15.5),
                          ),
                        ),
                        Text(e.ar,
                            style: const TextStyle(
                                color: muted, fontSize: 13.5)),
                      ]),
                    ),
                    const Divider(height: 1, color: dividerC),
                  ],
                );
              },
            ),
          ),
        ),
        SizedBox(
          width: 24,
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
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Text(l,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 11, color: muted)),
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
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'متن بنویسید تا با همان موتوری که در کیبورد سورن کار می‌کند، درست شود:',
            style: TextStyle(color: muted, height: 1.8)),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          onChanged: _run,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'مثلاً: میخام عالیترین کتابها رو به همه افراد بدم، سوال دارم',
            filled: true,
            fillColor: card,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(20),
                borderSide: BorderSide.none),
          ),
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
              color: pill, borderRadius: BorderRadius.circular(20)),
          child: Text(_out.isEmpty ? '…' : _out,
              style: const TextStyle(fontSize: 17.5, height: 1.8)),
        ),
        if (_out.isNotEmpty) ...[
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: selectedPill,
                padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: () => Clipboard.setData(ClipboardData(text: _out)),
            child: const Text('کپی متن درست‌شده'),
          ),
        ],
      ]),
    );
  }
}

// ================= نیم‌فاصله =================
class NimeFaselePage extends StatelessWidget {
  const NimeFaselePage({super.key});
  @override
  Widget build(BuildContext context) {
    const items = <(String, String)>[
      ('میان پیشوند و فعل',
          'می‌خوام، نمی‌دونم، می‌رود — میان «می/نمی» و بنِ فعل نیم‌فاصله است.'),
      ('پسوندهای «تر» و «ترین»',
          'عالی‌ترین، گرم‌تر، بزرگ‌ترین — به‌جز پنج واژهٔ چسبیده: بهتر، کمتر، بیشتر، مهتر، کهتر.'),
      ('«ها»ی جمع',
          'کتاب‌ها، واژه‌ها، کتابها هم اگر چسبیده تایپ شود کیبورد آن را کتاب‌ها می‌کند.'),
      ('پایان فعل‌های گذشتهٔ نقلی',
          'رفته‌ام، آمده‌ام، خوابیده‌اید — پسوندهای ام، ای، ایم، اید، اند پس از «ه» با نیم‌فاصله می‌آیند.'),
      ('ضمیرهای چسبان پس از «ه» و «ی»',
          'خانه‌اش، کشتی‌شان، صفحه‌ام — این پسوندها هم نیم‌فاصله می‌خواهند.'),
      ('ترکیب‌های «شده» و پیشوند «بی»',
          'گم‌شده، ترجمه‌شده، بی‌نهایت، بی‌آبرو.'),
      ('همزهٔ اضافه (ٔ)',
          'همهٔ افراد، خانهٔ من، صفحهٔ نخست — پس از واژه‌های پایان‌یافته به «ه»، نشانهٔ اضافه «ٔ» است، نه «ی».'),
      ('فاصله و نشانه‌ها',
          'پیش از «،» و «.» و «؟» فاصله نمی‌آید: سلام، خوبی؟'),
    ];
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('نیم‌فاصله',
              style: TextStyle(fontWeight: FontWeight.w700))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
              'کیبورد سورن همهٔ این قاعده‌ها را هنگام تایپ، خودکار رعایت می‌کند.',
              style: TextStyle(color: muted, height: 1.8)),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            Stagger(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: pill, borderRadius: BorderRadius.circular(20)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(items[i].$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                      const SizedBox(height: 7),
                      Text(items[i].$2,
                          style: const TextStyle(
                              color: Color(0xFF5C5546), height: 1.9)),
                    ]),
              ),
            ),
        ],
      ),
    );
  }
}

// ================= پندواژه (ضرب‌المثل‌ها) =================
class PandvazhePage extends StatelessWidget {
  const PandvazhePage({super.key});
  static const proverbs = <(String, String)>[
    ('از کوره دررفتن', 'زود خشمگین شدن و از اندازه بیرون رفتن.'),
    ('آب در هاون کوبیدن', 'کار بیهوده و بی‌سرانجام کردن.'),
    ('دست بالای دست بسیار است', 'همیشه کسی تواناتر از تو هست.'),
    ('جوجه را آخر پاییز می‌شمارند', 'نتیجهٔ کار را باید در پایان دید، نه آغاز.'),
    ('از دل برود هر آنکه از دیده برفت', 'دوری، مهر را کم می‌کند.'),
    ('کار نیکو کردن از پر کردن است', 'خوبی با انباشته‌شدن از کارهای کوچک ساخته می‌شود.'),
    ('هر که بامش بیش، برفش بیشتر', 'هر که دارایی و جایگاهش بزرگ‌تر، گرفتاری‌اش هم بیشتر.'),
    ('آش کشک خاله‌ته، بخوری پاته نخوری پاته', 'کاری که گریزی از آن نیست؛ چه بخواهی چه نه، در آنی.'),
    ('یک دست صدا ندارد', 'کار گروهی به‌تنهایی شدنی نیست.'),
    ('از این ستون به آن ستون فرج است', 'با گذر زمان و جابه‌جایی، گشایشی پیش می‌آید.'),
    ('عجله کار شیطان است', 'شتاب‌زدگی کار را خراب می‌کند.'),
    ('حرف راست را باید از بچه شنید', 'راستِ بی‌پرده را کسی می‌گوید که نفعی در پنهان‌کردنش ندارد.'),
    ('تا نباشد چیزکی، مردم نگویند چیزها', 'هر شایعه‌ای ریشه‌ای از راستی دارد.'),
    ('دل به دل راه دارد', 'مهر و احساس میان دو کس دوسویه است.'),
    ('صبر تلخ است ولیکن بر شیرین دارد', 'شکیبایی سخت است اما میوه‌اش شیرین است.'),
    ('آنچه شیران را کند روبه‌مزاج، احتیاج است', 'نیاز، آدمِ دلیر را هم وادار به فروتنی می‌کند.'),
    ('خواستن، توانستن است', 'ارادهٔ استوار راه رسیدن را باز می‌کند.'),
    ('کبوتر با کبوتر، باز با باز', 'هر کس با هم‌گونهٔ خود می‌آمیزد.'),
  ];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          backgroundColor: cream,
          elevation: 0,
          foregroundColor: ink,
          title: const Text('پندواژه — ضرب‌المثل‌های فارسی',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17))),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (var i = 0; i < proverbs.length; i++)
            Stagger(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: pill, borderRadius: BorderRadius.circular(20)),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(proverbs[i].$1,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16.5)),
                      const SizedBox(height: 6),
                      Text(proverbs[i].$2,
                          style: const TextStyle(
                              color: Color(0xFF5C5546), height: 1.9)),
                    ]),
              ),
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
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                const Divider(height: 1, color: dividerC),
            itemBuilder: (_, i) {
              final m = items[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(width: 96, child: Text('${m['from']}')),
                  const Icon(Icons.arrow_back_rounded, size: 15, color: muted),
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
    final asFa = widget.dict.entries.where((e) => e.fa.contains(w));
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
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(
            onChanged: _check,
            decoration: InputDecoration(
              hintText: 'واژه‌ای بنویسید تا ریشه‌اش را ببینید',
              filled: true,
              fillColor: card,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 20),
          Text(_result, style: const TextStyle(fontSize: 17, height: 1.9)),
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
      body: ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'کیبورد سورن چیدمان و رفتار کیبورد سامسونگ را دارد:\n\n'
            '• نوار بالا هنگام تایپ جای خود را به پیشنهادها می‌دهد و با پیکان برمی‌گردد.\n'
            '• هنگام زدن فاصله یا اینتر، اصلاح و جایگزینی خودکار انجام می‌شود: میخام ← می‌خوام، سوال ← پرسش.\n'
            '• کلید نیم‌فاصله در ردیف پایین است (نشانهٔ دو پیکان با خط‌چین)؛ برای چسباندن درستِ جزءهای واژه.\n'
            '• روی هر کلید نگه دارید تا نویسهٔ دومش بیاید (ص ← ض)؛ پیش‌نمایش نویسه هم بالای کلید دیده می‌شود.\n'
            '• پنل کلیپ‌بورد از نوار ابزار باز می‌شود و بریده‌هایتان را نگه می‌دارد.\n'
            '• ارتفاع کیبورد از تنظیمات برنامه کم‌وزیاد می‌شود.\n'
            '• کیبورد از انتخاب‌های شما روی همین دستگاه یاد می‌گیرد.\n\n'
            'برای فعال‌کردن: نخست از دکمهٔ زیر تنظیمات کیبورد را باز کنید و «کیبورد سورن» را روشن کنید، سپس آن را به‌عنوان کیبورد کنونی برگزینید.',
            style: TextStyle(height: 2, fontSize: 15)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: selectedPill,
              padding: const EdgeInsets.symmetric(vertical: 14)),
          onPressed: () => SharedFiles.openInputSettings(),
          child: const Text('بازکردن تنظیمات کیبورد اندروید'),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: () => SharedFiles.showKeyboardPicker(),
          child: const Text('برگزیدن کیبورد کنونی'),
        ),
      ]),
    );
  }
}
