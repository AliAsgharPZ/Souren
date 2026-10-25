import 'dart:convert';
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'data/store.dart';
import 'engine/corrector.dart';

/// App palette — pal.bg light theme, warm dark theme. `pal` is set from
/// the user's settings before every build of the app chrome.
class Pal {
  final Color bg, cardC, pillC, ink, muted, sel, div, faint, accent;
  const Pal(this.bg, this.cardC, this.pillC, this.ink, this.muted, this.sel,
      this.div, this.faint, this.accent);
  static const light = Pal(
    Color(0xFFF7F1E3), Color(0xFFEFE7D4), Color(0xFFEEE6D2),
    Color(0xFF2B2620), Color(0xFF8A8172), Color(0xFF6E6455),
    Color(0xFFE2D8C2), Color(0xFFB4A888), Color(0xFFB3543F),
  );
  static const dark = Pal(
    Color(0xFF221E19), Color(0xFF2D2822), Color(0xFF342F28),
    Color(0xFFF0E7D3), Color(0xFFA79C86), Color(0xFF8A7B63),
    Color(0xFF403A31), Color(0xFF6E6455), Color(0xFFD08A6D),
  );
}

Pal pal = Pal.light;

/// Category display metadata: id -> (icon, Persian title).
const catMeta = <String, (IconData, String)>{
  'health': (Icons.medical_services_rounded, 'پزشکی و تندرستی'),
  'work': (Icons.work_rounded, 'پیشه و کار'),
  'money': (Icons.storefront_rounded, 'پول و بازار'),
  'edu': (Icons.school_rounded, 'آموزش و دانش'),
  'lang': (Icons.forum_rounded, 'سخن و نوشتار'),
  'home': (Icons.home_rounded, 'خانه و خانواده'),
  'nature': (Icons.park_rounded, 'طبیعت و گیتی'),
  'faith': (Icons.self_improvement_rounded, 'باور و آیین'),
  'state': (Icons.account_balance_rounded, 'کشور و داد'),
  'mind': (Icons.psychology_rounded, 'دل و اندیشه'),
  'time': (Icons.schedule_rounded, 'زمان و سنجش'),
  'travel': (Icons.flight_rounded, 'سفر و جابه‌جایی'),
  'general': (Icons.public_rounded, 'همگانی'),
};

const catOrder = <String>[
  'health', 'work', 'money', 'edu', 'lang', 'home',
  'nature', 'faith', 'state', 'mind', 'time', 'travel', 'general',
];

String faNum(Object n) {
  const d = ['۰', '۱', '۲', '۳', '۴', '۵', '۶', '۷', '۸', '۹'];
  return n.toString().split('').map((c) {
    final i = int.tryParse(c);
    return i == null ? (c == ',' ? '٬' : c) : d[i];
  }).join();
}

void main() => runApp(const SourenApp());

class SourenApp extends StatefulWidget {
  const SourenApp({super.key});
  @override
  State<SourenApp> createState() => _SourenAppState();
}

class _SourenAppState extends State<SourenApp> {
  bool ready = false;

  @override
  void initState() {
    super.initState();
    SettingsStore.ensureLoaded().then((_) {
      if (mounted) setState(() => ready = true);
    });
    SettingsStore.revision.addListener(_onSettings);
  }

  void _onSettings() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsStore.revision.removeListener(_onSettings);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = SettingsStore.current;
    pal = st.dark ? Pal.dark : Pal.light;
    return MaterialApp(
      title: 'سورن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: st.font == 'arad' ? 'Arad' : null,
        brightness: st.dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: pal.bg,
        colorScheme: ColorScheme.fromSeed(
            seedColor: pal.ink,
            surface: pal.bg,
            brightness: st.dark ? Brightness.dark : Brightness.light),
        pageTransitionsTheme: const PageTransitionsTheme(builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        }),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: pal.ink, fontSize: 15),
          bodySmall: TextStyle(color: pal.muted, fontSize: 13),
        ),
      ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(st.textScale)),
        child: Directionality(
            textDirection:
                st.direction == 'ltr' ? TextDirection.ltr : TextDirection.rtl,
            child: child!),
      ),
      home: ready
          ? const Shell()
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
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
  Settings settings = SettingsStore.current;
  Set<String> favorites = {};
  Set<String> liked = {};
  Map<String, int> likeCounts = {};
  Categories categories = const Categories({});
  int learnedWords = 0;
  int learnedCorrections = 0;
  int tab = 0;
  String query = '';

  // auth form state (نمایهٔ کاربری)
  bool showAuthForm = false;
  bool authRegister = false;
  bool authBusy = false;
  bool dbSyncing = false;
  String? authError;
  final _userCtl = TextEditingController();
  final _passCtl = TextEditingController();
  final _nameCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await Dictionary.load();
    final s = await SettingsStore.ensureLoaded();
    final cats = await Categories.load();
    final fav = await SharedFiles.readJson('favorites.json');
    final lk = await SharedFiles.readJson('liked.json');
    final learned = await SharedFiles.readJson('learned.json');
    await AuthService.restore();
    final counts = await AuthService.fetchLikeCounts();
    Set<String> srvFav = {}, srvLiked = {};
    if (AuthService.user != null) {
      final prof = await AuthService.fetchProfile();
      if (prof != null) {
        srvFav = prof.$1;
        srvLiked = prof.$2;
      }
    }
    setState(() {
      dict = d;
      settings = s;
      categories = cats;
      if (fav != null && fav['words'] is List) {
        favorites = (fav['words'] as List).map((e) => e.toString()).toSet();
      }
      if (lk != null && lk['words'] is List) {
        liked = (lk['words'] as List).map((e) => e.toString()).toSet();
      }
      favorites = {...favorites, ...srvFav};
      liked = {...liked, ...srvLiked};
      likeCounts = counts;
      if (learned != null) {
        learnedWords = ((learned['counts'] as Map?) ?? {}).length;
        learnedCorrections = ((learned['history'] as List?) ?? []).length;
      }
    });
    _syncDictionary(d);
  }

  bool _dictSyncDone = false;

  /// Online dictionary update: when the network is up, pull the Worker
  /// dataset; a newer one replaces the on-device archive and the UI
  /// reloads. Offline, the archive already on the phone is used.
  Future<void> _syncDictionary(Dictionary current) async {
    if (_dictSyncDone) return;
    _dictSyncDone = true;
    final updated = await DictionarySync.syncFromServer(current);
    if (updated && mounted) {
      final d2 = await Dictionary.load();
      setState(() => dict = d2);
    }
  }

  Future<void> _toggleFav(String word) async {
    setState(() {
      favorites.contains(word) ? favorites.remove(word) : favorites.add(word);
    });
    await SharedFiles.writeJson('favorites.json', {'words': favorites.toList()});
    await AuthService.pushProfile(favorites, liked);
  }

  Future<void> _toggleLike(String word) async {
    final nowLiked = !liked.contains(word);
    setState(() {
      nowLiked ? liked.add(word) : liked.remove(word);
      final c = likeCounts[word] ?? 0;
      likeCounts[word] = nowLiked ? c + 1 : (c > 0 ? c - 1 : 0);
    });
    await SharedFiles.writeJson('liked.json', {'words': liked.toList()});
    final serverCount = await AuthService.setLike(word, nowLiked);
    if (serverCount != null && mounted) {
      setState(() => likeCounts[word] = serverCount);
    }
  }

  Widget _likeButton(String ar) {
    final isLiked = liked.contains(ar);
    final count = likeCounts[ar] ?? 0;
    // The count lives in a fixed-width slot that is always present, so
    // liking a word never shifts the row layout.
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 26,
        child: Text(count > 0 ? faNum(count) : '',
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, fontSize: 12.5)),
      ),
      IconButton(
        visualDensity: VisualDensity.compact,
        icon: Icon(
            isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            size: 21,
            color: isLiked ? pal.accent : pal.muted),
        onPressed: () => _toggleLike(ar),
      ),
    ]);
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
      _likedPage(d),
      _sectionsPage(d),
      _favoritesPage(d),
      _profilePage(d),
      _settingsPage(d),
    ];
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 92),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            child: KeyedSubtree(key: ValueKey(tab), child: pages[tab]),
          ),
        ),
      ),
      bottomNavigationBar:
          Container(color: Colors.transparent, child: _navBar()),
    );
  }

  // One single capsule slides between the tabs (no per-tab rectangles).
  final List<GlobalKey> _tabKeys = List.generate(6, (_) => GlobalKey());
  final GlobalKey _navStackKey = GlobalKey();
  double _indLeft = 0;
  double _indWidth = 0;

  void _measureIndicator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stackBox =
          _navStackKey.currentContext?.findRenderObject() as RenderBox?;
      final tabBox =
          _tabKeys[tab].currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null || tabBox == null) return;
      final pos = tabBox.localToGlobal(Offset.zero, ancestor: stackBox);
      if ((pos.dx - _indLeft).abs() > .5 ||
          (tabBox.size.width - _indWidth).abs() > .5) {
        setState(() {
          _indLeft = pos.dx;
          _indWidth = tabBox.size.width;
        });
      }
    });
  }

  Widget _navBar() {
    // (outlined, filled, label) — linear & soft; selected becomes filled.
    final items = <(IconData, IconData, String)>[
      (Icons.home_outlined, Icons.home_rounded, 'پیشگاه'),
      (Icons.favorite_border_rounded, Icons.favorite_rounded, 'پسندیده‌ها'),
      (Icons.widgets_outlined, Icons.widgets_rounded, 'بخش‌ها'),
      (Icons.bookmark_border_rounded, Icons.bookmark_rounded, 'نشان‌شده'),
      (Icons.person_outline_rounded, Icons.person_rounded, 'نمایه'),
      (Icons.settings_outlined, Icons.settings_rounded, 'پیکربندی'),
    ];
    _measureIndicator();
    final selSoft = Color.lerp(pal.sel, pal.bg, 0.38)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 10, 22, 26),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: pal.cardC,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 16, offset: Offset(0, 4))
        ],
      ),
      child: Stack(
        key: _navStackKey,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            left: _indLeft,
            top: 0,
            bottom: 0,
            width: _indWidth,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selSoft,
                borderRadius: BorderRadius.circular(19),
              ),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < items.length; i++)
                GestureDetector(
                  key: _tabKeys[i],
                  onTap: () => _go(i),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: tab == i ? 13 : 11, vertical: 9),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(tab == i ? items[i].$2 : items[i].$1,
                          size: 22,
                          color: tab == i
                              ? pal.bg
                              : pal.ink.withValues(alpha: .72)),
                      if (tab == i) ...[
                        const SizedBox(width: 6),
                        Text(items[i].$3,
                            style: TextStyle(
                                color: pal.bg,
                                fontWeight: FontWeight.w700,
                                fontSize: 13.5)),
                      ],
                    ]),
                  ),
                ),
            ],
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
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
      child: Column(children: [
        // جای لوگو (در نسخه‌های بعد می‌آید) — اشیاء پایین‌تر شروع می‌شوند
        const SizedBox(height: 86),
        SizedBox(
          height: 58,
          child: TextField(
            onChanged: (v) => setState(() => query = v.trim()),
            decoration: InputDecoration(
              hintText: 'واژه‌ای را جستجو کنید',
              hintStyle: TextStyle(color: pal.muted, fontSize: 14.5),
              prefixIcon: Icon(Icons.search_rounded, color: pal.muted, size: 23),
              filled: true,
              fillColor: pal.cardC,
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
                  _sidePill('گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d, onTapEntry: _showEntry))),
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
                        color: pal.pillC, borderRadius: BorderRadius.circular(20)),
                    child: Column(children: [
                      Text('شمار همهٔ واژه‌ها',
                          style: TextStyle(fontSize: 13, color: pal.ink)),
                      const SizedBox(height: 4),
                      Text(faNum(d.entries.length),
                          style: const TextStyle(
                              fontSize: 23, fontWeight: FontWeight.w700)),
                      Text('(${faNum(d.pairCount)} با برابر فارسی)',
                          style: TextStyle(fontSize: 11, color: pal.muted)),
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
            color: pal.pillC, borderRadius: BorderRadius.circular(20)),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: pal.ink)),
      ),
    );
  }

  /// Pair list with soft scroll fade at top and bottom edges.
  Widget _fadedPairList(List<Entry> items) {
    if (items.isEmpty) {
      return Center(
          child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)));
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
        separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
        itemBuilder: (_, i) => Stagger(index: i, child: _pairRow(items[i])),
      ),
    );
  }

  Widget _pairList(List<Entry> items) {
    if (items.isEmpty) {
      return Center(
          child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)));
    }
    return ListView.separated(
      itemCount: items.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
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
                  color: e.hasFa ? pal.ink : pal.faint),
            ),
          ),
          const SizedBox(width: 10),
          Text(e.ar,
              style: TextStyle(color: pal.muted, fontSize: 13.5)),
          _likeButton(e.ar),
        ]),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Pushes a shell-built page (pageShell column) as its own route.
  void _pushPage(Widget body) {
    Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => Scaffold(body: SafeArea(child: body))));
  }

  void _showEntry(Entry e) {
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.bg,
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
            Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: Icon(
                    liked.contains(e.ar)
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: liked.contains(e.ar) ? pal.accent : pal.ink),
                onPressed: () {
                  _toggleLike(e.ar);
                  Navigator.pop(context);
                  _showEntry(e);
                },
              ),
              IconButton(
                icon: Icon(
                    favorites.contains(e.ar)
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: pal.ink),
                onPressed: () {
                  _toggleFav(e.ar);
                  Navigator.pop(context);
                  _showEntry(e);
                },
              ),
            ]),
          ]),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
                e.hasFa
                    ? 'واژهٔ عربی: ${e.ar} — ریشه: عربی'
                    : 'برای این واژه هنوز برابر فارسی ثبت نشده است.',
                style:
                    TextStyle(color: pal.muted, fontSize: 14, height: 1.8)),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: pal.sel,
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

  // ---------- پسندیده‌ها ----------
  Widget _likedPage(Dictionary d) {
    final mine = d.entries.where((e) => liked.contains(e.ar)).toList();
    return _pageShell(
        'پسندیده‌ها',
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: mine.isEmpty
              ? Center(
                  child: Text(
                      'هنوز واژه‌ای را نپسندیده‌اید.\nروی قلبِ هر واژه بزنید تا اینجا بیاید.\nشمار کنار قلب، پسندهای همهٔ کاربران است.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.muted, height: 1.9)))
              : _pairList(mine),
        ));
  }

  // ---------- نشان‌شده ----------
  Widget _favoritesPage(Dictionary d) {
    final favs = d.entries.where((e) => favorites.contains(e.ar)).toList();
    return _pageShell(
        'نشان‌شده',
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: favs.isEmpty
              ? Center(
                  child: Text(
                      'هنوز واژه‌ای را نشان نکرده‌اید.\nروی نشانکِ هر واژه بزنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: pal.muted, height: 1.9)))
              : _pairList(favs),
        ));
  }

  // ---------- بخش‌ها (همهٔ قابلیت‌ها) ----------
  Widget _sectionsPage(Dictionary d) {
    final tiles = <(IconData, String, VoidCallback)>[
      (Icons.menu_book_rounded, 'گنجینهٔ واژه‌ها', () => _open(LexiconPage(dict: d, onTapEntry: _showEntry))),
      (Icons.spellcheck_rounded, 'درست‌نویسی', () => _open(CorrectorPage(dict: d))),
      (Icons.space_bar_rounded, 'نیم‌فاصله', () => _open(const NimeFaselePage())),
      (Icons.format_quote_rounded, 'پندواژه', () => _open(const PandvazhePage())),
      (Icons.account_tree_rounded, 'ریشه‌شناسی', () => _open(EtymologyPage(dict: d))),
      (Icons.new_releases_rounded, 'واژه‌های تازه', () => _open(const FreshPage())),
      (Icons.favorite_rounded, 'پسندیده‌ها', () => _go(1)),
      (Icons.bookmark_rounded, 'نشان‌شده', () => _go(3)),
      (Icons.star_rounded, 'واژهٔ روز', () => _pushPage(_dailyPage(d))),
      (Icons.school_rounded, 'یادگیری من', () => _pushPage(_learningPage())),
      (Icons.person_rounded, 'نمایهٔ کاربری', () => _go(4)),
      (Icons.keyboard_rounded, 'کیبورد سورن', () => _open(const KeyboardGuidePage())),
      (Icons.system_update_rounded, 'به‌روزرسانی پایگاه', () => _go(5)),
      (Icons.settings_rounded, 'پیکربندی', () => _go(5)),
    ];
    return _pageShell(
      'بخش‌ها',
      Column(children: [
        LayoutBuilder(builder: (context, c) {
          // Same height as the grid tiles below (2 columns, 14 spacing,
          // aspect 1.25, 24 page padding on each side).
          final tileH = ((c.maxWidth - 48 - 14) / 2) / 1.25;
          return Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
          child: Stagger(
            index: 0,
            child: GestureDetector(
              onTap: () => _pushPage(_categoriesPage(d)),
              child: Container(
                height: tileH,
                decoration: BoxDecoration(
                    color: pal.pillC, borderRadius: BorderRadius.circular(24)),
                padding: const EdgeInsets.symmetric(horizontal: 22),
                child: Row(children: [
                  Icon(Icons.category_rounded, size: 36, color: pal.ink),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('دسته‌بندی‌ها',
                            style: TextStyle(
                                fontSize: 17.5,
                                fontWeight: FontWeight.w700,
                                color: pal.ink)),
                        const SizedBox(height: 5),
                        Text('واژه‌ها بر پایهٔ زمینه و پیشه — ${faNum(catOrder.length)} دسته',
                            style: TextStyle(fontSize: 12.5, color: pal.muted)),
                      ],
                    ),
                  ),
                  Icon(Icons.arrow_back_ios_new_rounded,
                      size: 17, color: pal.muted),
                ]),
              ),
            ),
          ),
          );
        }),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 14,
            crossAxisSpacing: 14,
            childAspectRatio: 1.25,
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            children: [
              for (var i = 0; i < tiles.length; i++)
                Stagger(
                  index: i + 1,
                  child: GestureDetector(
                    onTap: tiles[i].$3,
                    child: Container(
                      decoration: BoxDecoration(
                          color: pal.pillC,
                          borderRadius: BorderRadius.circular(24)),
                      child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(tiles[i].$1, size: 32, color: pal.ink),
                            const SizedBox(height: 11),
                            Text(tiles[i].$2,
                                style: const TextStyle(fontSize: 15)),
                          ]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }

  // ---------- دسته‌بندی‌ها ----------
  Widget _categoriesPage(Dictionary d) {
    return _pageShell(
      'دسته‌بندی‌ها',
      ListView(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
        children: [
          for (var i = 0; i < catOrder.length; i++)
            Stagger(
              index: i,
              child: GestureDetector(
                onTap: () => _pushPage(_categoryWordsPage(d, catOrder[i])),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                      color: pal.pillC,
                      borderRadius: BorderRadius.circular(22)),
                  child: Row(children: [
                    Icon(catMeta[catOrder[i]]!.$1, size: 27, color: pal.ink),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(catMeta[catOrder[i]]!.$2,
                          style: TextStyle(fontSize: 16, color: pal.ink)),
                    ),
                    Text(
                        '${faNum(categories.inCategory(d, catOrder[i]).length)} واژه',
                        style: TextStyle(fontSize: 13, color: pal.muted)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    , back: true);
  }

  Widget _categoryWordsPage(Dictionary d, String catId) {
    final items = categories.inCategory(d, catId);
    return _pageShell(
      catMeta[catId]!.$2,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: items.isEmpty
            ? Center(
                child: Text('در این دسته هنوز واژه‌ای نیست',
                    style: TextStyle(color: pal.muted)))
            : _pairList(items),
      ),
    , back: true);
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
                style: TextStyle(color: pal.muted, fontSize: 15)),
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
    , back: true);
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
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                    'کیبورد سورن از انتخاب‌ها و اصلاح‌های شما روی همین دستگاه یاد می‌گیرد.\nهنوز چیزی نیاموخته است؛ با کیبورد سورن بنویسید تا اینجا ببینید چه یاد گرفته.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.muted, height: 1.9)),
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
                    style: TextStyle(color: pal.muted)),
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
    , back: true);
  }

  // ---------- نمایهٔ کاربری ----------
  static const _badgeMeta = <String, (IconData, String, String)>{
    'member': (Icons.verified_rounded, 'عضو سورن', 'با نمایه وارد شده‌اید'),
    'firstBookmark': (Icons.bookmark_rounded, 'نخستین نشان', 'یک واژه نشان کنید'),
    'liker': (Icons.favorite_rounded, 'دل‌باختهٔ واژه', '۱۰ واژه را بپسندید'),
    'keyboardStudent': (Icons.keyboard_rounded, 'شاگرد کیبورد', '۲۰ اصلاح کیبورد را بپذیرید'),
    'hundred': (Icons.star_rounded, 'باشگاه صدتایی‌ها', 'به ۱۰۰ امتیاز برسید'),
    'collector': (Icons.collections_bookmark_rounded, 'گنجینه‌دار', '۲۵ واژه نشان کنید'),
  };

  Future<void> _authSubmit() async {
    setState(() {
      authBusy = true;
      authError = null;
    });
    final (u, err) = authRegister
        ? await AuthService.register(
            _userCtl.text.trim(), _passCtl.text, _nameCtl.text.trim())
        : await AuthService.login(_userCtl.text.trim(), _passCtl.text);
    if (!mounted) return;
    setState(() {
      authBusy = false;
      authError = err;
    });
    if (u != null) {
      await _syncAfterLogin();
      if (mounted) setState(() => showAuthForm = false);
    }
  }

  Future<void> _syncAfterLogin() async {
    final prof = await AuthService.fetchProfile();
    if (prof != null) {
      setState(() {
        favorites = {...favorites, ...prof.$1};
        liked = {...liked, ...prof.$2};
      });
      await SharedFiles.writeJson(
          'favorites.json', {'words': favorites.toList()});
      await SharedFiles.writeJson('liked.json', {'words': liked.toList()});
      await AuthService.pushProfile(favorites, liked);
    }
    final counts = await AuthService.fetchLikeCounts();
    if (mounted) setState(() => likeCounts = counts);
  }

  Widget _profilePage(Dictionary d) {
    final user = AuthService.user;
    final score = profileScore(
        favorites: favorites.length,
        likes: liked.length,
        learnedWords: learnedWords,
        corrections: learnedCorrections);
    final next = nextLevelAt(score);
    final levelStart = levelThresholds.lastWhere((t) => score >= t.$1).$1;
    final progress =
        next == null ? 1.0 : (score - levelStart) / (next - levelStart);
    return _pageShell(
      'نمایهٔ کاربری',
      ListView(padding: const EdgeInsets.fromLTRB(24, 10, 24, 24), children: [
        Row(children: [
          CircleAvatar(
            radius: 33,
            backgroundColor: pal.sel,
            child: user != null
                ? Text(
                    user.displayName.isNotEmpty
                        ? user.displayName.characters.first
                        : 'س',
                    style: TextStyle(
                        color: pal.bg,
                        fontSize: 24,
                        fontWeight: FontWeight.w700))
                : Icon(Icons.person_rounded, color: pal.bg, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user?.displayName ?? 'مهمان',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: pal.ink)),
                  const SizedBox(height: 4),
                  Text(
                      user != null
                          ? '@${user.username}'
                          : 'وارد شوید تا نشان‌شده‌ها و پسندیده‌هایتان روی سرور هم نگه داشته شود',
                      style: TextStyle(color: pal.muted, fontSize: 13, height: 1.7)),
                ]),
          ),
        ]),
        const SizedBox(height: 22),
        if (user != null) ...[
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: pal.cardC, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('امتیاز شما',
                      style: TextStyle(fontSize: 14.5, color: pal.muted)),
                  Text('سطح: ${levelFor(score)}',
                      style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: pal.ink)),
                ]),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(faNum(score),
                  style: TextStyle(
                      fontSize: 38,
                      fontWeight: FontWeight.w700,
                      color: pal.ink)),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 9,
                backgroundColor: pal.div,
                color: pal.sel,
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                  next == null
                      ? 'به بالاترین سطح رسیده‌اید'
                      : 'تا سطح بعد ${faNum(next - score)} امتیاز دیگر',
                  style: TextStyle(fontSize: 12.5, color: pal.muted)),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        Text('بج‌ها',
            style: TextStyle(
                fontSize: 16.5, fontWeight: FontWeight.w700, color: pal.ink)),
        const SizedBox(height: 12),
        Wrap(spacing: 10, runSpacing: 10, children: [
          for (final id in badgeIds)
            Builder(builder: (_) {
              final earned = badgeEarned(id,
                  loggedIn: user != null,
                  favorites: favorites.length,
                  likes: liked.length,
                  corrections: learnedCorrections,
                  score: score);
              final meta = _badgeMeta[id]!;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                    color: earned ? pal.sel : pal.pillC,
                    borderRadius: BorderRadius.circular(20)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(meta.$1,
                      size: 18, color: earned ? pal.bg : pal.muted),
                  const SizedBox(width: 7),
                  Text(meta.$2,
                      style: TextStyle(
                          fontSize: 13.5,
                          color: earned ? pal.bg : pal.muted,
                          fontWeight:
                              earned ? FontWeight.w700 : FontWeight.w400)),
                ]),
              );
            }),
        ]),
        const SizedBox(height: 6),
        for (final id in badgeIds)
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text('• ${_badgeMeta[id]!.$2}: ${_badgeMeta[id]!.$3}',
                style: TextStyle(fontSize: 12.5, color: pal.muted)),
          ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
              color: pal.cardC, borderRadius: BorderRadius.circular(24)),
          child: Column(children: [
            _statRow('واژه‌های نشان‌شده', favorites.length),
            _statRow('واژه‌های پسندیده', liked.length),
            _statRow('واژه‌های آموختهٔ کیبورد', learnedWords),
            _statRow('اصلاح‌های پذیرفته‌شده', learnedCorrections,
                last: true),
          ]),
        ),
        const SizedBox(height: 24),
        ],
        if (user == null) ...[
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
                color: pal.pillC, borderRadius: BorderRadius.circular(22)),
            child: Row(children: [
              Icon(Icons.lock_outline_rounded, color: pal.muted, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                    'امتیاز، بج‌ها و همگام‌سازی از امکانات اصلی نمایه‌اند و با ورود فعال می‌شوند. به‌عنوان مهمان، واژه‌نامه، کیبورد و نشان‌شده‌های روی گوشی در دسترس‌تان است.',
                    style:
                        TextStyle(color: pal.muted, fontSize: 13, height: 1.8)),
              ),
            ]),
          ),
          const SizedBox(height: 24),
        ],
        if (user == null && !showAuthForm) ...[
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: pal.sel,
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () => setState(() {
                showAuthForm = true;
                authRegister = false;
                authError = null;
              }),
              child: const Text('ورود به نمایه'),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15)),
              onPressed: () => setState(() {
                showAuthForm = true;
                authRegister = true;
                authError = null;
              }),
              child: const Text('ساخت نمایهٔ تازه'),
            ),
          ),
        ],
        if (user == null && showAuthForm) _authForm(),
        if (user != null) ...[
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                await AuthService.pushProfile(favorites, liked);
                await _syncAfterLogin();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('همگام‌سازی انجام شد')));
                }
              },
              child: const Text('همگام‌سازی اکنون'),
            ),
          ),
          const SizedBox(height: 11),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                  foregroundColor: pal.accent,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              onPressed: () async {
                await AuthService.logout();
                if (mounted) setState(() {});
              },
              child: const Text('خروج از نمایه'),
            ),
          ),
        ],
        const SizedBox(height: 10),
        ListTile(
          leading: Icon(Icons.school_rounded, color: pal.ink),
          title: const Text('آموخته‌های کیبورد'),
          subtitle: const Text('آنچه کیبورد سورن از شما آموخته است'),
          onTap: () => _pushPage(_learningPage()),
        ),
      ]),
    );
  }

  Widget _statRow(String label, int value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: last ? 12 : 12),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(label, style: TextStyle(fontSize: 14.5, color: pal.ink)),
        Text(faNum(value),
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w700, color: pal.ink)),
      ]),
    );
  }

  Widget _authForm() {
    InputDecoration deco(String hint) => InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: pal.muted, fontSize: 14),
          filled: true,
          fillColor: pal.cardC,
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
        );
    return Column(children: [
      Text(authRegister ? 'ساخت نمایهٔ تازه' : 'ورود به نمایه',
          style: TextStyle(
              fontSize: 16.5, fontWeight: FontWeight.w700, color: pal.ink)),
      const SizedBox(height: 14),
      if (authRegister) ...[
        TextField(
            controller: _nameCtl,
            decoration: deco('نام نمایشی (مانند: سورن)')),
        const SizedBox(height: 11),
      ],
      TextField(controller: _userCtl, decoration: deco('نام کاربری')),
      const SizedBox(height: 11),
      TextField(
          controller: _passCtl,
          obscureText: true,
          decoration: deco('گذرواژه (دست‌کم ۶ نویسه)')),
      if (authError != null) ...[
        const SizedBox(height: 11),
        Text(authError!,
            style: TextStyle(color: pal.accent, fontSize: 13.5)),
      ],
      const SizedBox(height: 15),
      SizedBox(
        width: double.infinity,
        child: FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: pal.sel,
              padding: const EdgeInsets.symmetric(vertical: 15)),
          onPressed: authBusy ? null : _authSubmit,
          child: authBusy
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : Text(authRegister ? 'ساختن نمایه' : 'ورود'),
        ),
      ),
      TextButton(
        onPressed: () => setState(() {
          authRegister = !authRegister;
          authError = null;
        }),
        child: Text(
            authRegister
                ? 'نمایه دارید؟ وارد شوید'
                : 'نمایه ندارید؟ یکی بسازید',
            style: TextStyle(color: pal.muted)),
      ),
      TextButton(
        onPressed: () => setState(() => showAuthForm = false),
        child: Text('پس‌نمایش', style: TextStyle(color: pal.muted)),
      ),
    ]);
  }

  // ---------- تنظیمات ----------
  Widget _groupHeader(String title, {bool first = false}) {
    return Padding(
      padding: EdgeInsets.fromLTRB(16, first ? 2 : 26, 16, 6),
      child: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w800, fontSize: 16, color: pal.accent)),
    );
  }

  Widget _settingsPage(Dictionary d) {
    return _pageShell(
      'پیکربندی',
      ListView(padding: const EdgeInsets.all(22), children: [
        _groupHeader('درست‌نویسی و کیبورد', first: true),
        SwitchListTile(
          title: const Text('جایگزینی خودکار واژه‌های عربی با فارسی'),
          subtitle: const Text(
              'در کیبورد، واژهٔ عربی با نخستین برابرِ تک‌واژه‌ای‌اش جایگزین می‌شود'),
          value: settings.replaceArabic,
          onChanged: (v) async {
            setState(() => settings.replaceArabic = v);
            await SettingsStore.update(settings);
          },
        ),
        SwitchListTile(
          title: const Text('اصلاح خودکار املایی'),
          subtitle: const Text('نیم‌فاصله، همزهٔ اضافه و مانند آن هنگام زدن فاصله'),
          value: settings.autoCorrect,
          onChanged: (v) async {
            setState(() => settings.autoCorrect = v);
            await SettingsStore.update(settings);
          },
        ),
        const SizedBox(height: 8),
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
              await SettingsStore.update(settings);
            },
          ),
        ),
        const SizedBox(height: 8),
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
        _groupHeader('نمایش'),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('تم و رنگ',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'light', label: Text('روشن (کرم)')),
              ButtonSegment(value: 'dark', label: Text('تیره')),
            ],
            selected: {settings.theme},
            onSelectionChanged: (v) async {
              setState(() => settings.theme = v.first);
              await SettingsStore.update(settings);
            },
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('فونت برنامه',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'arad', label: Text('آراد')),
              ButtonSegment(value: 'system', label: Text('پیش‌فرض سیستم')),
            ],
            selected: {settings.font},
            onSelectionChanged: (v) async {
              setState(() => settings.font = v.first);
              await SettingsStore.update(settings);
            },
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('اندازهٔ نوشته‌ها',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'small', label: Text('کم')),
              ButtonSegment(value: 'normal', label: Text('معمولی')),
              ButtonSegment(value: 'large', label: Text('زیاد')),
            ],
            selected: {settings.textSize},
            onSelectionChanged: (v) async {
              setState(() => settings.textSize = v.first);
              await SettingsStore.update(settings);
            },
          ),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('جهت نمایش',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'rtl', label: Text('راست‌چین')),
              ButtonSegment(value: 'ltr', label: Text('چپ‌چین')),
            ],
            selected: {settings.direction},
            onSelectionChanged: (v) async {
              setState(() => settings.direction = v.first);
              await SettingsStore.update(settings);
            },
          ),
        ),
        _groupHeader('پایگاه واژه‌ها'),
        ListTile(
          leading: const Icon(Icons.cloud_sync_rounded),
          title: const Text('به‌روزرسانی آنلاین از سرور'),
          subtitle: Text(
              'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — با اینترنت، تازه‌ترین پایگاه از سرور گرفته می‌شود؛ آفلاین، آرشیو روی گوشی به کار می‌رود'),
          trailing: dbSyncing
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : null,
          onTap: dbSyncing ? null : () => _syncDbNow(d),
        ),
        ListTile(
          leading: const Icon(Icons.file_open_rounded),
          title: const Text('بارگذاری پایگاه از فایل'),
          subtitle: const Text('فایل JSON یا CSV برگزینید'),
          onTap: () => _importDb(),
        ),
        ListTile(
          leading: const Icon(Icons.ios_share_rounded),
          title: const Text('خروجی از پایگاه واژه‌ها'),
          subtitle: const Text('JSON پایگاه در حافظهٔ برنامه ذخیره و مسیرش نشان داده می‌شود'),
          onTap: () => _exportDb(d),
        ),
        _groupHeader('درباره'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
              'درباره: سورن دیکشنری عربی به فارسی است با کیبوردی که درست‌نویسی فارسی را رعایت می‌کند. فونت برنامه: آراد. یادگیری کیبورد فقط روی همین دستگاه انجام می‌شود و داده‌ای بیرون نمی‌رود.',
              style: TextStyle(color: pal.muted, height: 1.9, fontSize: 13)),
        ),
      ]),
    );
  }

  Future<void> _syncDbNow(Dictionary d) async {
    setState(() => dbSyncing = true);
    final updated = await DictionarySync.syncFromServer(d);
    if (updated) {
      final d2 = await Dictionary.load();
      if (mounted) setState(() => dict = d2);
    }
    if (mounted) {
      setState(() => dbSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(updated
              ? 'پایگاه واژه‌ها به‌روز شد'
              : 'پایگاه به‌روز است یا ارتباط با سرور برقرار نشد')));
    }
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

  Widget _pageShell(String title, Widget body, {bool back = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Row(children: [
          if (back) ...[
            BackButton(color: pal.ink),
            const SizedBox(width: 4),
          ],
          Text(title,
              style:
                  const TextStyle(fontSize: 21, fontWeight: FontWeight.w700)),
        ]),
      ),
      Expanded(child: body),
    ]);
  }
}

/// Scaffold for sub-pages: the content scrolls under a header strip
/// whose background fades and blurs into the page colour — no hard
/// rectangle edge appears under the page title while scrolling.
Widget subScaffold(String title, Widget body) {
  return Scaffold(
    backgroundColor: pal.bg,
    body: SafeArea(
      child: Stack(children: [
        Positioned.fill(top: 58, child: body),
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: 66,
          child: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 9, sigmaY: 9),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      pal.bg.withValues(alpha: .94),
                      pal.bg.withValues(alpha: .55),
                    ],
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(children: [
                  BackButton(color: pal.ink),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(title,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: pal.ink)),
                  ),
                ]),
              ),
            ),
          ),
        ),
      ]),
    ),
  );
}

// ================= گنجینهٔ واژه‌ها =================

class LexiconPage extends StatefulWidget {
  final Dictionary dict;
  final void Function(Entry) onTapEntry;
  const LexiconPage({super.key, required this.dict, required this.onTapEntry});
  @override
  State<LexiconPage> createState() => _LexiconPageState();
}

class _LexiconPageState extends State<LexiconPage> {
  // Fixed row heights make letter offsets computable, so the alphabet
  // rail jumps exactly (like a phone contacts app) instead of hunting
  // for section widgets that may not be built yet.
  static const double _headerH = 40;
  static const double _rowH = 51;

  late final List<String> _letters;
  late final Map<String, double> _offsets;
  late final List<Object> _items; // String = letter header, Entry = row
  final ScrollController _scroll = ScrollController();
  String? _railLetter;

  @override
  void initState() {
    super.initState();
    final entries = [...widget.dict.entries]
      ..sort((a, b) => a.ar.compareTo(b.ar));
    _letters = [];
    _offsets = {};
    _items = [];
    var offset = 0.0;
    String? cur;
    for (final e in entries) {
      final c = e.ar.isEmpty ? '' : e.ar[0];
      if (c.isNotEmpty && c != cur) {
        cur = c;
        if (!_letters.contains(c)) _letters.add(c);
        _offsets[c] = offset;
        _items.add(c);
        offset += _headerH;
      }
      _items.add(e);
      offset += _rowH;
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _jumpTo(String letter, {bool animate = true}) {
    final off = _offsets[letter];
    if (off == null || !_scroll.hasClients) return;
    final target = off.clamp(0.0, _scroll.position.maxScrollExtent);
    if (animate) {
      _scroll.animateTo(target,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic);
    } else {
      _scroll.jumpTo(target);
    }
  }

  void _railAt(double dy, double height) {
    if (_letters.isEmpty || height <= 0) return;
    final slot = height / _letters.length;
    var idx = (dy / slot).floor().clamp(0, _letters.length - 1);
    final letter = _letters[idx];
    if (letter != _railLetter) {
      _railLetter = letter;
      _jumpTo(letter, animate: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      'گنجینهٔ واژه‌ها',
      Row(children: [
        // Alphabet rail — first in the RTL row, so it sits on the RIGHT.
        SizedBox(
          width: 30,
          child: LayoutBuilder(builder: (context, c) {
            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => _railAt(d.localPosition.dy, c.maxHeight),
              onVerticalDragStart: (d) =>
                  _railAt(d.localPosition.dy, c.maxHeight),
              onVerticalDragUpdate: (d) =>
                  _railAt(d.localPosition.dy, c.maxHeight),
              onVerticalDragEnd: (_) => _railLetter = null,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final l in _letters)
                    Text(l,
                        style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.muted)),
                ],
              ),
            );
          }),
        ),
        Expanded(
          child: ShaderMask(
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black,
                Colors.black,
                Colors.transparent
              ],
              stops: [0, 0.035, 0.965, 1],
            ).createShader(rect),
            blendMode: BlendMode.dstIn,
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(6, 4, 18, 24),
              itemCount: _items.length,
              itemBuilder: (_, i) {
                final it = _items[i];
                if (it is String) {
                  return SizedBox(
                    height: _headerH,
                    child: Align(
                      alignment: Alignment.bottomRight,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Text(it,
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: pal.accent)),
                      ),
                    ),
                  );
                }
                final e = it as Entry;
                return SizedBox(
                  height: _rowH,
                  child: Column(children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => widget.onTapEntry(e),
                        child: Row(children: [
                          Text(e.ar,
                              style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: pal.ink)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(e.fa.join('، '),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: pal.muted, fontSize: 13.5)),
                          ),
                          Icon(Icons.arrow_back_ios_new_rounded,
                              size: 13, color: pal.muted),
                        ]),
                      ),
                    ),
                    Divider(
                        height: 1,
                        color: pal.ink.withValues(alpha: .07)),
                  ]),
                );
              },
            ),
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
    return subScaffold('درست‌نویسی', ListView(padding: const EdgeInsets.all(24), children: [
        Text(
            'متن بنویسید تا با همان موتوری که در کیبورد سورن کار می‌کند، درست شود:',
            style: TextStyle(color: pal.muted, height: 1.8)),
        const SizedBox(height: 14),
        TextField(
          controller: _ctrl,
          onChanged: _run,
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'مثلاً: میخام عالیترین کتابها رو به همه افراد بدم، سوال دارم',
            filled: true,
            fillColor: pal.cardC,
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
              color: pal.pillC, borderRadius: BorderRadius.circular(20)),
          child: Text(_out.isEmpty ? '…' : _out,
              style: const TextStyle(fontSize: 17.5, height: 1.8)),
        ),
        if (_out.isNotEmpty) ...[
          const SizedBox(height: 14),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: pal.sel,
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
    return subScaffold('نیم‌فاصله', ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
              'کیبورد سورن همهٔ این قاعده‌ها را هنگام تایپ، خودکار رعایت می‌کند.',
              style: TextStyle(color: pal.muted, height: 1.8)),
          const SizedBox(height: 14),
          for (var i = 0; i < items.length; i++)
            Stagger(
              index: i,
              child: Container(
                margin: const EdgeInsets.only(bottom: 13),
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: pal.pillC, borderRadius: BorderRadius.circular(20)),
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

  void _proverbSheet(BuildContext context, String title, String meaning) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.cardC,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(26, 20, 26, 30),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 44,
              height: 5,
              decoration: BoxDecoration(
                  color: pal.muted.withValues(alpha: .35),
                  borderRadius: BorderRadius.circular(3))),
          const SizedBox(height: 20),
          Icon(Icons.format_quote_rounded, size: 30, color: pal.accent),
          const SizedBox(height: 12),
          Text(title,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w800,
                  color: pal.ink,
                  height: 1.8)),
          const SizedBox(height: 10),
          Text(meaning,
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.muted, height: 1.8, fontSize: 14.5)),
          const SizedBox(height: 18),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                foregroundColor: pal.ink,
                side: BorderSide(color: pal.ink.withValues(alpha: .25)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16))),
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: title));
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('در حافظه کپی شد')));
              }
            },
            icon: const Icon(Icons.copy_rounded, size: 17),
            label: const Text('کپی'),
          ),
        ]),
      ),
    );
  }
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
    return subScaffold('پندواژه — ضرب‌المثل‌های فارسی', ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (var i = 0; i < proverbs.length; i++)
            Stagger(
              index: i,
              child: GestureDetector(
                onTap: () =>
                    _proverbSheet(context, proverbs[i].$1, proverbs[i].$2),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 13),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                      color: pal.pillC, borderRadius: BorderRadius.circular(20)),
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
    return subScaffold('واژه‌های تازه', FutureBuilder<Map<String, dynamic>?>(
        future: SharedFiles.readJson('learned.json'),
        builder: (_, snap) {
          final history = (snap.data?['history'] as List?) ?? [];
          if (history.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(30),
                child: Text(
                    'واژهٔ تازه‌ای هنوز نیست.\nهر واژه‌ای که کیبورد سورن برایتان اصلاح کند و بپذیرید، اینجا می‌آید.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: pal.muted, height: 1.9)),
              ),
            );
          }
          final items = history.reversed.take(60).toList();
          return ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: items.length,
            separatorBuilder: (_, __) =>
                Divider(height: 1, color: pal.div),
            itemBuilder: (_, i) {
              final m = items[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(children: [
                  SizedBox(width: 96, child: Text('${m['from']}')),
                  Icon(Icons.arrow_back_rounded, size: 15, color: pal.muted),
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
    return subScaffold('ریشه‌شناسی', Padding(
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          TextField(
            onChanged: _check,
            decoration: InputDecoration(
              hintText: 'واژه‌ای بنویسید تا ریشه‌اش را ببینید',
              filled: true,
              fillColor: pal.cardC,
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
    return subScaffold('کیبورد سورن', ListView(padding: const EdgeInsets.all(24), children: [
        const Text(
            'کیبورد سورن کپیِ رفتار و چیدمان کیبورد سامسونگ است:\n\n'
            '• نوار بالا هنگام تایپ جای خود را به پیشنهادها می‌دهد و با پیکان برمی‌گردد.\n'
            '• هنگام زدن فاصله یا اینتر، اصلاح و جایگزینی خودکار انجام می‌شود: میخام ← می‌خوام، سوال ← پرسش.\n'
            '• روی هر کلید نگه دارید: پنجره‌ای بالای کلید باز می‌شود با همهٔ نویسه‌های لایهٔ شیفت و خویشاوندهای آن کلید؛ انگشت را بکشید و رها کنید تا همان نویسه بنشیند.\n'
            '• کلید شیفت لایهٔ اعراب و شکل‌های عربی/همزه‌دار را روی کلیدها نشان می‌دهد؛ نگه‌داشتنش لایه را قفل می‌کند.\n'
            '• برای انگلیسی، روی کلید فاصله به چپ یا راست بکشید؛ زبان عوض می‌شود. نگه‌داشتن فاصله آن را به صفحهٔ حرکتِ نشانگر تبدیل می‌کند.\n'
            '• کلید نیم‌فاصله در ردیف پایین است؛ نگه‌داشتنش «چسبان» (ZWJ) می‌دهد.\n'
            '• کلید کنار فاصله «سفارشی» است: نگهش دارید و نمادی برگزینید؛ همان نماد روی کلید می‌ماند.\n'
            '• نگه‌داشتن نقطه، ده نماد و نشانهٔ پرکاربرد (اعراب و ؟) را باز می‌کند.\n'
            '• پنل ایموجی از نوار ابزار باز می‌شود: دسته‌بندی، جست‌وجو با واژه (مثل گربه یا خنده)، ایموجی‌های اخیر، و با نگه‌داشتن روی ایموجی‌های آدم، رنگ پوست.\n'
            '• صفحهٔ دوم نمادها (کلید =<) لیگچرها و گلیف‌های عربی را دارد: ﷽ ﷲ ﷺ ﷻ ﷼ و اعراب کامل و کشیده.\n'
            '• پنل کلیپ‌بورد از نوار ابزار باز می‌شود و بریده‌هایتان را نگه می‌دارد.\n'
            '• ارتفاع کیبورد از تنظیمات برنامه کم‌وزیاد می‌شود.\n'
            '• کیبورد از انتخاب‌های شما روی همین دستگاه یاد می‌گیرد.\n\n'
            'برای فعال‌کردن: نخست از دکمهٔ زیر تنظیمات کیبورد را باز کنید و «کیبورد سورن» را روشن کنید، سپس آن را به‌عنوان کیبورد کنونی برگزینید.',
            style: TextStyle(height: 2, fontSize: 15)),
        const SizedBox(height: 20),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: pal.sel,
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
