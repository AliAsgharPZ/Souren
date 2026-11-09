import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lucide.dart';

import 'data/store.dart';
import 'engine/corrector.dart';

/// App palette — pal.bg light theme, warm dark theme. `pal` is set from
/// the user's settings before every build of the app chrome.
class Pal {
  final Color bg, cardC, pillC, ink, muted, sel, div, faint, accent;
  const Pal(
    this.bg,
    this.cardC,
    this.pillC,
    this.ink,
    this.muted,
    this.sel,
    this.div,
    this.faint,
    this.accent,
  );
  static const light = Pal(
    Color(0xFFF7F1E3),
    Color(0xFFEFE7D4),
    Color(0xFFEEE6D2),
    Color(0xFF2B2620),
    Color(0xFF8A8172),
    Color(0xFF6E6455),
    Color(0xFFE2D8C2),
    Color(0xFFB4A888),
    Color(0xFFB3543F),
  );
  static const dark = Pal(
    Color(0xFF221E19),
    Color(0xFF2D2822),
    Color(0xFF342F28),
    Color(0xFFF0E7D3),
    Color(0xFFA79C86),
    Color(0xFF8A7B63),
    Color(0xFF403A31),
    Color(0xFF6E6455),
    Color(0xFFD08A6D),
  );
}

Pal pal = Pal.light;

/// True when [pal] is the dark theme — a few owner rules (bookmark turns
/// black) need theme-aware colors while everything else uses [pal].
bool palDark = false;

/// Like-active red (owner: «لایک قرمز بشه») — Souren's own warm red.
const Color kLikeRed = Color(0xFFCC3D31);

/// Capsule roundness: 90% of the maximum (fully-round = 0.5 × height),
/// so every capsule uses radius = 0.45 × its own height.
double capsuleRadius(double height) => height * 0.45;

BorderRadius capsuleBorder(double height) =>
    BorderRadius.circular(capsuleRadius(height));

/// Height of a text button from its vertical padding (text line ≈ 20).
double buttonHeight(double vPad) => vPad * 2 + 20;

/// A capsule ButtonStyle: radius = 0.45 × height (owner A1) for every
/// remaining Material button in the app.
ButtonStyle capsuleBtn({
  double vPad = 14,
  Color? bg,
  Color? fg,
  Color? sideColor,
}) {
  return ButtonStyle(
    backgroundColor: bg == null ? null : WidgetStatePropertyAll(bg),
    foregroundColor: fg == null ? null : WidgetStatePropertyAll(fg),
    side: sideColor == null
        ? null
        : WidgetStatePropertyAll(BorderSide(color: sideColor)),
    padding: const WidgetStatePropertyAll(
      EdgeInsets.symmetric(vertical: 14),
    ),
    shape: WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: capsuleBorder(buttonHeight(vPad))),
    ),
  );
}

/// Motion language (Claude-inspired feel, Souren's own numbers): one place
/// for every duration/curve so entrances, toggles and transitions match.
/// Colors and general visuals stay Souren's own — only the motion feel is
/// borrowed from the Claude design system (whose own note says animation
/// timings are out of scope, so these numbers are ours).
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 280);
  static const slow = Duration(milliseconds: 380);
  static const curve = Curves.easeOutCubic;
  static const pop = Curves.easeOutBack;
  static const staggerStep = Duration(milliseconds: 35);
}

/// Bottom clearance for tab-page scrollables: the floating nav bar is
/// ~83px tall with a 14px bottom margin, so the last list item must end
/// ~116px above the viewport floor to never hide behind the bar.
const double kNavClearance = 116;

/// Shared fade+rise transition for AnimatedSwitchers (tab switches,
/// auth form, settings switches) — the same entrance the routes use.
Widget enterTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0, 0.02),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// The ONE page-enter transition: fade + gentle rise, ~280ms easeOutCubic.
/// Replaces the old FadeForwardsPageTransitionsBuilder.
class FadeRisePageTransitionsBuilder extends PageTransitionsBuilder {
  const FadeRisePageTransitionsBuilder();
  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return enterTransition(child, animation);
  }
}

/// Scale pop for toggle icons (like / bookmark): replays on [active] change.
class PopIcon extends StatelessWidget {
  final bool active;
  final Widget child;
  const PopIcon({super.key, required this.active, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(active),
      tween: Tween(begin: 0.6, end: 1),
      duration: Motion.fast,
      curve: Motion.pop,
      builder: (_, v, c) => Transform.scale(scale: v, child: c),
      child: child,
    );
  }
}

/// A double that animates smoothly from its previous value (profile
/// progress bar, score count-up) instead of jumping on every rebuild.
class AnimatedValue extends StatefulWidget {
  final double value;
  final Widget Function(double value) builder;
  const AnimatedValue({super.key, required this.value, required this.builder});
  @override
  State<AnimatedValue> createState() => _AnimatedValueState();
}

class _AnimatedValueState extends State<AnimatedValue>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _current = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: Motion.slow);
    _anim = Tween(
      begin: 0.0,
      end: widget.value,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Motion.curve));
    _ctrl.addListener(() => _current = _anim.value);
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant AnimatedValue old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _anim = Tween(
        begin: _current,
        end: widget.value,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Motion.curve));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => widget.builder(_anim.value),
    );
  }
}

/// Press-and-hold feedback for EVERY tappable button/capsule/card: the
/// surface sinks slightly (scale 0.97 + soft dim) while the finger is
/// down and springs back with a gentle pop on release.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double pressScale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.pressScale = 0.97,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _down = false;

  void _set(bool v) {
    if (_down != v && mounted) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => _set(true),
      onTapCancel: () => _set(false),
      onTapUp: (_) => _set(false),
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _down ? widget.pressScale : 1.0),
        duration: _down ? const Duration(milliseconds: 110) : Motion.base,
        curve: _down ? Motion.curve : Motion.pop,
        builder: (_, v, c) => Opacity(
          opacity: _down ? 0.88 : 1,
          child: Transform.scale(scale: v, child: c),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Scroll-aware edge fade (shared by every scrollable list in the app).
///
/// Owner rules: NO fade at the very start of a page — the top fade ramps
/// in smoothly only after the user scrolls a bit; same for the bottom.
/// The fade itself is much longer and smoother than before (eased
/// multi-stop gradient, ~16% of the viewport, from the very edge of the
/// viewport down to where the old short fade used to end).
class ScrollEdgeFade extends StatefulWidget {
  final Widget child;
  const ScrollEdgeFade({super.key, required this.child});
  @override
  State<ScrollEdgeFade> createState() => _ScrollEdgeFadeState();
}

class _ScrollEdgeFadeState extends State<ScrollEdgeFade> {
  double _before = 0; // pixels hidden above the viewport
  double _after = 0; // pixels hidden below the viewport

  double _strength(double hidden) {
    // Ramp 0→1 over the first 90px of hidden content, eased (smoothstep).
    final t = (hidden / 90).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  bool _onNotification(ScrollNotification n) {
    final m = n.metrics;
    if (m.maxScrollExtent <= 0) {
      if (_before == 0 && _after == 0) return false;
      setState(() {
        _before = 0;
        _after = 0;
      });
      return false;
    }
    final before = m.pixels.clamp(0.0, m.maxScrollExtent);
    final after = (m.maxScrollExtent - m.pixels).clamp(0.0, double.infinity);
    if ((before - _before).abs() > 0.5 || (after - _after).abs() > 0.5) {
      setState(() {
        _before = before;
        _after = after;
      });
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: _onNotification,
      child: ShaderMask(
        shaderCallback: (rect) {
          const fadeFrac = 0.16; // much longer than the old 4.5%
          final vh = rect.height;
          var len = (vh * fadeFrac).clamp(72.0, 170.0);
          len = len.clamp(0.0, vh / 2 - 1);
          final topA = _strength(_before);
          final botA = _strength(_after);
          final topLen = len * topA;
          final botLen = len * botA;
          final s1 = (topLen / vh).clamp(0.0, 0.5);
          final s2 = (1 - botLen / vh).clamp(s1, 1.0);
          final opaqueTop = Colors.white.withValues(alpha: 1 - topA);
          final opaqueBot = Colors.white.withValues(alpha: 1 - botA);
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              opaqueTop, // viewport edge — no fade at rest, fades in on scroll
              Color.lerp(opaqueTop, Colors.white, 0.62)!,
              Color.lerp(opaqueTop, Colors.white, 0.9)!,
              Colors.white,
              Colors.white,
              Color.lerp(opaqueBot, Colors.white, 0.9)!,
              Color.lerp(opaqueBot, Colors.white, 0.62)!,
              opaqueBot,
            ],
            stops: [
              0,
              s1 * 0.45,
              s1 * 0.8,
              s1,
              s2,
              s2 + (1 - s2) * 0.2,
              s2 + (1 - s2) * 0.55,
              1,
            ],
          ).createShader(rect);
        },
        blendMode: BlendMode.dstIn,
        child: widget.child,
      ),
    );
  }
}

/// Like + bookmark, side by side everywhere (owner rule). Lucide outline
/// icons only — never filled. Inactive: one faded color for both.
/// Active: like turns red, bookmark turns black (ink in the dark theme
/// so it stays visible).
class LikeFavRow extends StatelessWidget {
  final bool liked;
  final bool faved;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onFav;
  final double iconSize;
  const LikeFavRow({
    super.key,
    required this.liked,
    required this.faved,
    this.likeCount = 0,
    required this.onLike,
    required this.onFav,
    this.iconSize = 21,
  });

  Color _bookmarkActive() => palDark ? pal.ink : const Color(0xFF141210);

  @override
  Widget build(BuildContext context) {
    final inactive = pal.faint;
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (likeCount > 0) ...[
        AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: Text(
            faNum(likeCount),
            key: ValueKey(likeCount),
            style: TextStyle(color: pal.muted, fontSize: 12.5),
          ),
        ),
        const SizedBox(width: 4),
      ],
      Pressable(
        onTap: onLike,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: PopIcon(
            active: liked,
            child: Icon(
              LucideIcons.heart,
              size: iconSize,
              color: liked ? kLikeRed : inactive,
            ),
          ),
        ),
      ),
      Pressable(
        onTap: onFav,
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: PopIcon(
            active: faved,
            child: Icon(
              LucideIcons.bookmark,
              size: iconSize,
              color: faved ? _bookmarkActive() : inactive,
            ),
          ),
        ),
      ),
    ]);
  }
}

/// Category display metadata: id -> (icon, Persian title).
const catMeta = <String, (IconData, String)>{
  'health': (LucideIcons.activity, 'پزشکی و تندرستی'),
  'work': (LucideIcons.briefcase, 'پیشه و کار'),
  'money': (LucideIcons.wallet, 'پول و بازار'),
  'edu': (LucideIcons.notebookPen, 'آموزش و دانش'),
  'lang': (LucideIcons.messageSquare, 'سخن و نوشتار'),
  'home': (LucideIcons.house, 'خانه و خانواده'),
  'nature': (LucideIcons.compass, 'طبیعت و گیتی'),
  'faith': (LucideIcons.moon, 'باور و آیین'),
  'state': (LucideIcons.building2, 'کشور و داد'),
  'mind': (LucideIcons.heart, 'دل و اندیشه'),
  'time': (LucideIcons.clock, 'زمان و سنجش'),
  'travel': (LucideIcons.mapPin, 'سفر و جابه‌جایی'),
  'general': (LucideIcons.globe, 'همگانی'),
};

const catOrder = <String>[
  'health',
  'work',
  'money',
  'edu',
  'lang',
  'home',
  'nature',
  'faith',
  'state',
  'mind',
  'time',
  'travel',
  'general',
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
    palDark = st.dark;
    return MaterialApp(
      title: 'سورن',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: st.font == 'arad' ? 'Arad' : null,
        brightness: st.dark ? Brightness.dark : Brightness.light,
        scaffoldBackgroundColor: pal.bg,
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {TargetPlatform.android: FadeRisePageTransitionsBuilder()},
        ),
        textSelectionTheme: TextSelectionThemeData(
          cursorColor: pal.sel,
          selectionColor: pal.sel.withValues(alpha: 0.3),
          selectionHandleColor: pal.sel,
        ),
        progressIndicatorTheme: ProgressIndicatorThemeData(color: pal.sel),
        snackBarTheme: SnackBarThemeData(backgroundColor: pal.sel),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: pal.ink, fontSize: 15),
          bodySmall: TextStyle(color: pal.muted, fontSize: 13),
        ),
      ),
      builder: (context, child) => AnimatedTheme(
        data: Theme.of(context),
        duration: Motion.slow,
        curve: Motion.curve,
        child: MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(st.textScale)),
          child: Directionality(
            textDirection: st.direction == 'ltr'
                ? TextDirection.ltr
                : TextDirection.rtl,
            child: child!,
          ),
        ),
      ),
      home: AnimatedSwitcher(
        duration: Motion.base,
        transitionBuilder: enterTransition,
        child: ready
            ? const KeyedSubtree(key: ValueKey('shell'), child: Shell())
            : const KeyedSubtree(
                key: ValueKey('loading'),
                child: Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                ),
              ),
      ),
    );
  }
}

/// The ONE list/page entrance: soft fade + gentle rise, staggered by
/// [index] for list items only. Replaces the three old entrances
/// (Stagger, the route fade, the tab cross-fade).
class Enter extends StatelessWidget {
  final int index;
  final Widget child;
  const Enter({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Duration(milliseconds: (index % 12) * 35),
      curve: Motion.curve,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, 12 * (1 - v)), child: c),
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

  // search focus state (home): back icon + page blur while focused.
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchFocused = false;

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
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    _load();
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    _userCtl.dispose();
    _passCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    // Local-only data first: the app must render immediately, offline
    // included (owner B4). Network (likes + profile) happens after.
    final d = await Dictionary.load();
    final s = await SettingsStore.ensureLoaded();
    final cats = await Categories.load();
    final fav = await SharedFiles.readJson('favorites.json');
    final lk = await SharedFiles.readJson('liked.json');
    final learned = await SharedFiles.readJson('learned.json');
    await AuthService.restore();
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
      if (learned != null) {
        learnedWords = ((learned['counts'] as Map?) ?? {}).length;
        learnedCorrections = ((learned['history'] as List?) ?? []).length;
      }
    });
    _syncDictionary(d);
    _fetchRemote();
  }

  /// Remote data (like counts, server profile) — fetched strictly in the
  /// background with bounded timeouts; failures never block the app.
  Future<void> _fetchRemote() async {
    try {
      final counts = await AuthService.fetchLikeCounts().timeout(
        const Duration(seconds: 10),
      );
      if (mounted) setState(() => likeCounts = counts);
    } catch (_) {
      // offline: local counts (already rendered) keep working
    }
    if (AuthService.user == null) return;
    try {
      final prof = await AuthService.fetchProfile().timeout(
        const Duration(seconds: 10),
      );
      if (prof != null && mounted) {
        setState(() {
          favorites = {...favorites, ...prof.$1};
          liked = {...liked, ...prof.$2};
        });
      }
    } catch (_) {
      // offline: on-device favorites/likes keep working
    }
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
    await SharedFiles.writeJson('favorites.json', {
      'words': favorites.toList(),
    });
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
        top: true,
        bottom: false,
        child: AnimatedSwitcher(
          duration: Motion.base,
          transitionBuilder: enterTransition,
          child: KeyedSubtree(
            key: ValueKey(
              '${tab}_${settings.font}_${settings.direction}_${settings.textSize}',
            ),
            child: pages[tab],
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
    // (icon, label) — Lucide icons from the CUI pack. Buttons are FIXED
    // slots: they never move or resize when a tab is selected; only the
    // sliding indicator moves (owner rules A3/A20). No glassmorphism —
    // a fully floating solid capsule with a soft shadow (A19).
    final items = <(IconData, String)>[
      (LucideIcons.house, 'پیشگاه'),
      (LucideIcons.heart, 'پسندیده‌ها'),
      (LucideIcons.layoutDashboard, 'بخش‌ها'),
      (LucideIcons.bookmark, 'نشان‌شده'),
      (LucideIcons.user, 'نمایه'),
      (LucideIcons.settings, 'پیکربندی'),
    ];
    _measureIndicator();
    final selSoft = Color.lerp(pal.sel, pal.bg, 0.38)!;
    // A5: give the bar 1.5% of the viewport width, split over both sides.
    final vw = MediaQuery.of(context).size.width;
    final hInset = (22 - vw * 0.015 / 2).clamp(14.0, 24.0);
    // A20: the indicator must sit with EQUAL spacing top/bottom and
    // left/right — the inner padding is uniform (8) and the buttons
    // match it, so the capsule has the same 8px gap all around.
    const inner = 8.0;
    const btnVPad = 12.0; // button height = 12*2 + 23 = 47
    const barH = 47 + inner * 2; // 63 — same total as before
    return Container(
      margin: EdgeInsets.fromLTRB(hInset, 6, hInset, 14),
      child: Container(
        padding: const EdgeInsets.all(inner),
        decoration: BoxDecoration(
          color: pal.cardC,
          borderRadius: capsuleBorder(barH),
          border: Border.all(color: pal.div.withValues(alpha: 0.6)),
          boxShadow: [
            BoxShadow(
              color: pal.ink.withValues(alpha: 0.10),
              blurRadius: 22,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Stack(
          key: _navStackKey,
          clipBehavior: Clip.none,
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
                  borderRadius: capsuleBorder(47),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < items.length; i++)
                  Pressable(
                    key: _tabKeys[i],
                    onTap: () => _go(i),
                    pressScale: 0.94,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: inner,
                        vertical: btnVPad,
                      ),
                      child: AnimatedSwitcher(
                        duration: Motion.fast,
                        switchInCurve: Motion.curve,
                        switchOutCurve: Motion.curve,
                        transitionBuilder: (child, anim) => FadeTransition(
                          opacity: anim,
                          child: ScaleTransition(
                            scale: Tween<double>(
                              begin: 0.8,
                              end: 1,
                            ).animate(anim),
                            child: child,
                          ),
                        ),
                        child: Icon(
                          key: ValueKey<bool>(tab == i),
                          items[i].$1,
                          size: 23,
                          color: tab == i
                              ? pal.bg
                              : pal.ink.withValues(alpha: .72),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ---------- پیشگاه ----------
  // Measured height of the buttons column — the word list on the other
  // side must be exactly as tall (owner A2).
  final GlobalKey _homeButtonsKey = GlobalKey();
  double _buttonsH = 0;

  void _measureButtons() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final box =
          _homeButtonsKey.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.attached) return;
      final h = box.size.height;
      if ((h - _buttonsH).abs() > 0.5) setState(() => _buttonsH = h);
    });
  }

  Widget _home(Dictionary d) {
    final frequent = d.entries.where((e) => e.hasFa).take(60).toList();
    final results = query.isEmpty
        ? frequent
        : d.entries
              .where(
                (e) =>
                    e.ar.contains(query) || e.fa.any((f) => f.contains(query)),
              )
              .toList();
    _measureButtons();
    // Owner A22, in order: reserved logo gap → search capsule → the two
    // columns → an empty band the size of the nav bar (reserved for ads)
    // → the nav bar itself (untouched). The search sits a bit lower than
    // before and the column heights are tuned; nothing else moved.
    const logoGap = 66.0;
    const searchH = 58.0;
    const gapBelowSearch = 20.0;
    const adsReserve = 83.0; // the floating nav bar's total footprint
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
      child: Stack(
        children: [
          Column(
            children: [
              // جای لوگو (در نسخه‌های بعد می‌آید) — خالی، ولی رزرو شده
              const SizedBox(height: logoGap),
              const SizedBox(height: searchH), // جای کپسول سرچ
              const SizedBox(height: gapBelowSearch),
              Expanded(
                child: LayoutBuilder(builder: (context, c) {
                  // Before the buttons column is measured the list fills
                  // the available height; afterwards it is EXACTLY the
                  // buttons' height, capped by what fits (owner A2).
                  final listH = _buttonsH <= 0
                      ? c.maxHeight
                      : _buttonsH.clamp(0.0, c.maxHeight);
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              query.isEmpty
                                  ? 'پرکاربردترین واژگان فارسی'
                                  : 'نتیجه‌های جستجو',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 17.5,
                              ),
                            ),
                            const SizedBox(height: 10),
                            SizedBox(
                              height: listH,
                              child: _pairList(results),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        width: 124,
                        child: SingleChildScrollView(
                          child: Column(
                            key: _homeButtonsKey,
                            children: [
                              _sidePill(
                                'واژهٔ روز',
                                () => _pushPage(_dailyPage(d)),
                              ),
                              _sidePill(
                                'گنجینهٔ واژه‌ها',
                                () => _open(
                                  LexiconPage(dict: d, onTapEntry: _showEntry),
                                ),
                              ),
                              _sidePill(
                                'درست‌نویسی',
                                () => _open(CorrectorPage(dict: d)),
                              ),
                              _sidePill(
                                'نیم‌فاصله',
                                () => _open(const NimeFaselePage()),
                              ),
                              _sidePill(
                                'پندواژه',
                                () => _open(_pandvazhePage()),
                              ),
                              _sidePill(
                                'واژه‌های تازه',
                                () => _open(_freshPage(d)),
                              ),
                              _sidePill(
                                'ریشه‌شناسی',
                                () => _open(EtymologyPage(dict: d)),
                              ),
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.only(top: 4),
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.pillC,
                                  borderRadius: capsuleBorder(14 * 2 + 66),
                                ),
                                child: Column(
                                  children: [
                                    Text(
                                      'شمار همهٔ واژه‌ها',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: pal.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      faNum(d.entries.length),
                                      style: const TextStyle(
                                        fontSize: 23,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    Text(
                                      '(${faNum(d.pairCount)} با برابر فارسی)',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: pal.muted,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              // فضای خالی اندازهٔ نویگیشن‌بار — رزرو برای تبلیغ
              const SizedBox(height: adsReserve),
            ],
          ),
          // بلر کل صفحه هنگام فوکوس سرچ — کپسول و دکمهٔ برگشت واضح می‌مانند.
          if (_searchFocused)
            Positioned.fill(
              child: GestureDetector(
                onTap: () => _searchFocus.unfocus(),
                child: BackdropFilter(
                  filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(color: pal.bg.withValues(alpha: 0.35)),
                ),
              ),
            ),
          // کپسول سرچ (روی بلر، واضح)
          Positioned(
            top: logoGap,
            left: 0,
            right: 0,
            child: SizedBox(
              height: searchH,
              child: TextField(
                controller: _searchCtl,
                focusNode: _searchFocus,
                onChanged: (v) => setState(() => query = v.trim()),
                decoration: InputDecoration(
                  hintText: 'واژه‌ای را جستجو کنید',
                  hintStyle: TextStyle(color: pal.muted, fontSize: 14.5),
                  prefixIcon: Icon(
                    LucideIcons.search,
                    color: pal.muted,
                    size: 22,
                  ),
                  filled: true,
                  fillColor: pal.cardC,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18),
                  border: OutlineInputBorder(
                    borderRadius: capsuleBorder(searchH),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: capsuleBorder(searchH),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: capsuleBorder(searchH),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          // آیکون برگشت بالای صفحه هنگام فوکوس سرچ
          if (_searchFocused)
            Positioned(
              top: 6,
              right: 0,
              child: IconButton(
                icon: Icon(
                  LucideIcons.arrowLeft,
                  color: pal.ink,
                  size: 24,
                ),
                onPressed: () => _searchFocus.unfocus(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sidePill(String label, VoidCallback onTap) {
    const h = 14.0 * 2 + 20.0; // capsule height from its vertical padding
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: pal.pillC,
          borderRadius: capsuleBorder(h),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: pal.ink),
        ),
      ),
    );
  }

  /// Pair list with the shared scroll fade and the unified entrance.
  /// [bottomPad] clears the floating nav bar on tab pages; the home page
  /// reserves that space with its own ads band, so it passes less.
  Widget _pairList(List<Entry> items, {double bottomPad = 8}) {
    if (items.isEmpty) {
      return Center(
        child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)),
      );
    }
    return ScrollEdgeFade(
      child: ListView.separated(
        padding: EdgeInsets.only(top: 6, bottom: bottomPad),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
        itemBuilder: (_, i) => Enter(index: i, child: _pairRow(items[i])),
      ),
    );
  }

  /// Home rows (owner A12): the word itself is right-aligned, ONE
  /// meaning left-aligned, both on a single line — never two.
  Widget _pairRow(Entry e) {
    return Pressable(
      onTap: () => _showEntry(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(
              e.ar,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 17.5,
                color: pal.ink,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                e.hasFa ? e.fa.first : 'برابر فارسی ثبت نشده',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.end,
                style: TextStyle(
                  color: e.hasFa ? pal.muted : pal.faint,
                  fontSize: 13.5,
                ),
              ),
            ),
            const SizedBox(width: 8),
            LikeFavRow(
              liked: liked.contains(e.ar),
              faved: favorites.contains(e.ar),
              likeCount: likeCounts[e.ar] ?? 0,
              onLike: () => _toggleLike(e.ar),
              onFav: () => _toggleFav(e.ar),
            ),
          ],
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  /// Proverb page wired to the shell's like/favorite storage.
  Widget _pandvazhePage() => PandvazhePage(
    liked: liked,
    favorites: favorites,
    likeCounts: likeCounts,
    onToggleLike: _toggleLike,
    onToggleFav: _toggleFav,
  );

  /// Fresh-words page (new words of the latest update) + Word of the Day.
  Widget _freshPage(Dictionary d) =>
      FreshPage(dict: d, onWordOfDay: () => _pushPage(_dailyPage(d)));

  /// Pushes a shell-built page (pageShell column) as its own route.
  void _pushPage(Widget body) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(body: SafeArea(child: body)),
      ),
    );
  }

  void _showEntry(Entry e) {
    final cat = categories.categoryOf(e.ar);
    final info = <(String, String)>[
      (
        'برابر فارسی',
        e.hasFa ? e.fa.join('، ') : 'برای این واژه هنوز برابر فارسی ثبت نشده است',
      ),
      if (cat != null && catMeta[cat] != null)
        ('دسته‌بندی', catMeta[cat]!.$2),
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: pal.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => EntrySheet(
        title: e.ar,
        infoRows: info,
        shareText: [
          e.ar,
          if (e.hasFa) e.fa.join('، '),
          if (cat != null && catMeta[cat] != null) catMeta[cat]!.$2,
          'سورن — واژه‌نامهٔ عربی به فارسی',
        ].join('\n'),
        copyText: e.hasFa ? e.fa.first : e.ar,
        copyLabel: 'کپی برابر فارسی',
        liked: liked.contains(e.ar),
        faved: favorites.contains(e.ar),
        likeCount: likeCounts[e.ar] ?? 0,
        onLike: () => _toggleLike(e.ar),
        onFav: () => _toggleFav(e.ar),
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
                  style: TextStyle(color: pal.muted, height: 1.9),
                ),
              )
            : _pairList(mine, bottomPad: kNavClearance),
      ),
    );
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
                  style: TextStyle(color: pal.muted, height: 1.9),
                ),
              )
            : _pairList(favs, bottomPad: kNavClearance),
      ),
    );
  }

  // ---------- بخش‌ها (همهٔ قابلیت‌ها) ----------
  Widget _sectionsPage(Dictionary d) {
    // Owner A15: buttons that live in the navigation bar (پسندیده‌ها،
    // نشان‌شده، نمایهٔ کاربری، پیکربندی) are NOT duplicated here.
    final tiles = <(IconData, String, VoidCallback)>[
      (
        LucideIcons.box,
        'گنجینهٔ واژه‌ها',
        () => _open(LexiconPage(dict: d, onTapEntry: _showEntry)),
      ),
      (
        LucideIcons.type,
        'درست‌نویسی',
        () => _open(CorrectorPage(dict: d)),
      ),
      (
        LucideIcons.minus,
        'نیم‌فاصله',
        () => _open(const NimeFaselePage()),
      ),
      (LucideIcons.history, 'پندواژه', () => _open(_pandvazhePage())),
      (
        LucideIcons.gitBranch,
        'ریشه‌شناسی',
        () => _open(EtymologyPage(dict: d)),
      ),
      (
        LucideIcons.sparkles,
        'واژه‌های تازه',
        () => _open(_freshPage(d)),
      ),
      (LucideIcons.star, 'واژهٔ روز', () => _pushPage(_dailyPage(d))),
      (
        LucideIcons.notebookPen,
        'یادگیری من',
        () => _pushPage(_learningPage()),
      ),
      (
        LucideIcons.keyboard,
        'کیبورد سورن',
        () => _open(const KeyboardGuidePage()),
      ),
      (LucideIcons.refreshCw, 'به‌روزرسانی پایگاه', () => _go(5)),
    ];
    return _pageShell(
      'بخش‌ها',
      ScrollEdgeFade(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                child: Enter(
                  index: 0,
                  child: LayoutBuilder(builder: (context, c) {
                    // Owner A4: the categories card is EXACTLY as tall as
                    // one grid tile — the grid below uses the same width,
                    // spacing and aspect ratio, so compute its height.
                    final tileW = (c.maxWidth - 14) / 2;
                    final tileH = tileW / 1.25;
                    return Pressable(
                      onTap: () => _pushPage(_categoriesPage(d)),
                      child: Container(
                        height: tileH,
                        decoration: BoxDecoration(
                          color: pal.pillC,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Row(
                          children: [
                            Icon(
                              LucideIcons.grid3x3,
                              size: 36,
                              color: pal.ink,
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'دسته‌بندی‌ها',
                                    style: TextStyle(
                                      fontSize: 17.5,
                                      fontWeight: FontWeight.w700,
                                      color: pal.ink,
                                    ),
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    'واژه‌ها بر پایهٔ زمینه و پیشه — ${faNum(catOrder.length)} دسته',
                                    style: TextStyle(
                                      fontSize: 12.5,
                                      color: pal.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronLeft,
                              size: 17,
                              color: pal.muted,
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24 + kNavClearance),
              sliver: SliverGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 14,
                crossAxisSpacing: 14,
                childAspectRatio: 1.25,
                children: [
                  for (var i = 0; i < tiles.length; i++)
                    Enter(
                      index: i + 1,
                      child: Pressable(
                        onTap: tiles[i].$3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pal.pillC,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(tiles[i].$1, size: 32, color: pal.ink),
                              const SizedBox(height: 11),
                              Text(
                                tiles[i].$2,
                                style: const TextStyle(fontSize: 15),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- دسته‌بندی‌ها ----------
  Widget _categoriesPage(Dictionary d) {
    return _pageShell(
      'دسته‌بندی‌ها',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          children: [
            for (var i = 0; i < catOrder.length; i++)
              Enter(
                index: i,
                child: GestureDetector(
                  onTap: () => _pushPage(_categoryWordsPage(d, catOrder[i])),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: pal.pillC,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          catMeta[catOrder[i]]!.$1,
                          size: 27,
                          color: pal.ink,
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Text(
                            catMeta[catOrder[i]]!.$2,
                            style: TextStyle(fontSize: 16, color: pal.ink),
                          ),
                        ),
                        Text(
                          '${faNum(categories.inCategory(d, catOrder[i]).length)} واژه',
                          style: TextStyle(fontSize: 13, color: pal.muted),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    back: true);
  }

  Widget _categoryWordsPage(Dictionary d, String catId) {
    final items = categories.inCategory(d, catId);
    return _pageShell(
      catMeta[catId]!.$2,
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: items.isEmpty
            ? Center(
                child: Text(
                  'در این دسته هنوز واژه‌ای نیست',
                  style: TextStyle(color: pal.muted),
                ),
              )
            : _pairList(items),
      ),
    back: true);
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                e.ar,
                style: const TextStyle(
                  fontSize: 40,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'برابر فارسی',
                style: TextStyle(color: pal.muted, fontSize: 15),
              ),
              const SizedBox(height: 14),
              Text(
                e.fa.join('، '),
                style: const TextStyle(fontSize: 19, height: 1.7),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),
              OutlinedButton(
                style: capsuleBtn(sideColor: pal.div),
                onPressed: () => _showEntry(e),
                child: const Text('دیدن واژه'),
              ),
            ],
          ),
        ),
      ),
    back: true);
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
                  style: TextStyle(color: pal.muted, height: 1.9),
                ),
              ),
            );
          }
          final counts = (j['counts'] as Map?) ?? {};
          final history = (j['history'] as List?) ?? [];
          final top = counts.entries.toList()
            ..sort((a, b) => (b.value as num).compareTo(a.value as num));
          return ScrollEdgeFade(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                Text(
                  'شمار اصلاح‌های پذیرفته‌شده: ${faNum(history.length)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 6),
                Text(
                  'واژه‌های آموخته‌شده: ${faNum(counts.length)}',
                  style: const TextStyle(fontSize: 16),
                ),
                const Divider(height: 30),
                const Text(
                  'پرکاربردترین‌ها نزد شما',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                for (final t in top.take(15))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${t.key} — ${faNum(t.value)} بار',
                      style: TextStyle(color: pal.muted),
                    ),
                  ),
                const SizedBox(height: 18),
                OutlinedButton(
                  style: capsuleBtn(sideColor: pal.div),
                  onPressed: () async {
                    final f = await SharedFiles.file('learned.json');
                    if (await f.exists()) await f.delete();
                    setState(() {});
                  },
                  child: const Text('پاک‌کردن آموخته‌ها'),
                ),
              ],
            ),
          );
        },
      ),
    back: true);
  }

  // ---------- نمایهٔ کاربری ----------
  static const _badgeMeta = <String, (IconData, String, String)>{
    'member': (
      LucideIcons.badgeCheck,
      'عضو سورن',
      'با نمایه وارد شده‌اید',
    ),
    'firstBookmark': (
      LucideIcons.bookmark,
      'نخستین نشان',
      'یک واژه نشان کنید',
    ),
    'liker': (
      LucideIcons.heart,
      'دل‌باختهٔ واژه',
      '۱۰ واژه را بپسندید',
    ),
    'keyboardStudent': (
      LucideIcons.keyboard,
      'شاگرد کیبورد',
      '۲۰ اصلاح کیبورد را بپذیرید',
    ),
    'hundred': (
      LucideIcons.star,
      'باشگاه صدتایی‌ها',
      'به ۱۰۰ امتیاز برسید',
    ),
    'collector': (
      LucideIcons.layers,
      'گنجینه‌دار',
      '۲۵ واژه نشان کنید',
    ),
  };

  Future<void> _authSubmit() async {
    setState(() {
      authBusy = true;
      authError = null;
    });
    final (u, err) = authRegister
        ? await AuthService.register(
            _userCtl.text.trim(),
            _passCtl.text,
            _nameCtl.text.trim(),
          )
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
      await SharedFiles.writeJson('favorites.json', {
        'words': favorites.toList(),
      });
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
      corrections: learnedCorrections,
    );
    final next = nextLevelAt(score);
    final levelStart = levelThresholds.lastWhere((t) => score >= t.$1).$1;
    final progress = next == null
        ? 1.0
        : (score - levelStart) / (next - levelStart);
    return _pageShell(
      'نمایهٔ کاربری',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24 + kNavClearance),
          children: [
            Row(
              children: [
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
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : Icon(
                          LucideIcons.user,
                          color: pal.bg,
                          size: 32,
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.displayName ?? 'مهمان',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user != null ? '@${user.username}' : 'وارد شوید تا نشان‌شده‌ها و پسندیده‌هایتان روی سرور هم نگه داشته شود',
                        style: TextStyle(
                          color: pal.muted,
                          fontSize: 13,
                          height: 1.7,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: pal.cardC,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'امتیاز شما',
                        style: TextStyle(fontSize: 14.5, color: pal.muted),
                      ),
                      Text(
                        'سطح: ${levelFor(score)}',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: AnimatedValue(
                      value: score.toDouble(),
                      builder: (v) => Text(
                        faNum(v.round()),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  AnimatedValue(
                    value: progress,
                    builder: (v) => ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: v,
                        minHeight: 9,
                        backgroundColor: pal.div,
                        color: pal.sel,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      next == null
                          ? 'به بالاترین سطح رسیده‌اید'
                          : 'تا سطح بعد ${faNum(next - score)} امتیاز دیگر',
                      style: TextStyle(fontSize: 12.5, color: pal.muted),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'بج‌ها',
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
            const SizedBox(height: 12),
            // Owner A17: badges occupy the FULL width (two per line), no
            // guide list underneath — tapping a badge shows its
            // description as a notification from the top of the screen.
            for (var r = 0; r < badgeIds.length; r += 2)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    for (var c = 0; c < 2; c++)
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                            left: c == 0 ? 0 : 5,
                            right: c == 0 ? 5 : 0,
                          ),
                          child: r + c < badgeIds.length
                              ? _badgeCapsule(
                                  badgeIds[r + c],
                                  user != null,
                                  score,
                                )
                              : const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: pal.cardC,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                children: [
                  _statRow('واژه‌های نشان‌شده', favorites.length),
                  _statRow('واژه‌های پسندیده', liked.length),
                  _statRow('واژه‌های آموختهٔ کیبورد', learnedWords),
                  _statRow(
                    'اصلاح‌های پذیرفته‌شده',
                    learnedCorrections,
                    last: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (user == null) ...[
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                    color: pal.pillC,
                    borderRadius: BorderRadius.circular(22)),
                child: Row(children: [
                  Icon(LucideIcons.lock, color: pal.muted, size: 22),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                        'امتیاز، بج‌ها و همگام‌سازی از امکانات اصلی نمایه‌اند و با ورود فعال می‌شوند. به‌عنوان مهمان، واژه‌نامه، کیبورد و نشان‌شده‌های روی گوشی در دسترس‌تان است.',
                        style: TextStyle(
                            color: pal.muted, fontSize: 13, height: 1.8)),
                  ),
                ]),
              ),
              const SizedBox(height: 24),
            ],
            if (user == null)
              AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: enterTransition,
                child: showAuthForm
                    ? KeyedSubtree(
                        key: const ValueKey('form'),
                        child: _authForm(),
                      )
                    : KeyedSubtree(
                        key: const ValueKey('buttons'),
                        child: _authButtons(),
                      ),
              ),
            if (user != null) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: capsuleBtn(sideColor: pal.div),
                  onPressed: () async {
                    await AuthService.pushProfile(favorites, liked);
                    await _syncAfterLogin();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('همگام‌سازی انجام شد')),
                      );
                    }
                  },
                  child: const Text('همگام‌سازی اکنون'),
                ),
              ),
              const SizedBox(height: 11),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: capsuleBtn(
                    sideColor: pal.div, fg: pal.accent),
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
              leading: Icon(LucideIcons.notebookPen, color: pal.ink),
              title: const Text('آموخته‌های کیبورد'),
              subtitle: const Text('آنچه کیبورد سورن از شما آموخته است'),
              onTap: () => _pushPage(_learningPage()),
            ),
          ],
        ),
      ),
    );
  }

  /// One full-width badge capsule; a tap raises its description from the
  /// top of the screen like a notification (owner A17).
  Widget _badgeCapsule(String id, bool loggedIn, int score) {
    final earned = badgeEarned(
      id,
      loggedIn: loggedIn,
      favorites: favorites.length,
      likes: liked.length,
      corrections: learnedCorrections,
      score: score,
    );
    final meta = _badgeMeta[id]!;
    const h = 10.0 * 2 + 20.0;
    return Pressable(
      onTap: () => showBadgeToast(context, meta.$1, meta.$2, meta.$3),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: earned ? pal.sel : pal.pillC,
          borderRadius: capsuleBorder(h),
        ),
        child: Row(
          children: [
            Icon(
              meta.$1,
              size: 17,
              color: earned ? pal.bg : pal.muted,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                meta.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13,
                  color: earned ? pal.bg : pal.muted,
                  fontWeight: earned ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statRow(String label, int value, {bool last = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: last ? 12 : 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14.5, color: pal.ink)),
          Text(
            faNum(value),
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
        ],
      ),
    );
  }

  Widget _authButtons() {
    // Owner A18: creating a profile and logging in sit on ONE line.
    return Row(
      children: [
        Expanded(
          child: Pressable(
            onTap: () => setState(() {
              showAuthForm = true;
              authRegister = false;
              authError = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: pal.sel,
                borderRadius: capsuleBorder(buttonHeight(14)),
              ),
              child: Text(
                'ورود به نمایه',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pal.bg,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Pressable(
            onTap: () => setState(() {
              showAuthForm = true;
              authRegister = true;
              authError = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 14),
              decoration: BoxDecoration(
                color: pal.pillC,
                borderRadius: capsuleBorder(buttonHeight(14)),
                border: Border.all(color: pal.div),
              ),
              child: Text(
                'ساخت نمایهٔ تازه',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
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
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 15),
    );
    return AnimatedSize(
      duration: Motion.base,
      curve: Motion.curve,
      child: Column(
        children: [
          Text(
            authRegister ? 'ساخت نمایهٔ تازه' : 'ورود به نمایه',
            style: TextStyle(
              fontSize: 16.5,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 14),
          if (authRegister)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Motion.fast,
              builder: (_, v, c) => Opacity(opacity: v, child: c),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _nameCtl,
                    decoration: deco('نام نمایشی (مانند: سورن)'),
                  ),
                  const SizedBox(height: 11),
                ],
              ),
            ),
          TextField(controller: _userCtl, decoration: deco('نام کاربری')),
          const SizedBox(height: 11),
          TextField(
            controller: _passCtl,
            obscureText: true,
            decoration: deco('گذرواژه (دست‌کم ۶ نویسه)'),
          ),
          if (authError != null) ...[
            const SizedBox(height: 11),
            Text(
              authError!,
              style: TextStyle(color: pal.accent, fontSize: 13.5),
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: capsuleBtn(bg: pal.sel, vPad: 15),
              onPressed: authBusy ? null : _authSubmit,
              child: authBusy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
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
              style: TextStyle(color: pal.muted),
            ),
          ),
          TextButton(
            onPressed: () => setState(() => showAuthForm = false),
            child: Text('پس‌نمایش', style: TextStyle(color: pal.muted)),
          ),
        ],
      ),
    );
  }

  /// Custom capsule segmented control (replaces Material SegmentedButton):
  /// one pill container, the selected option is a taller, less-round
  /// capsule of its own. Radius = 0.45 × height (owner A1).
  Widget _capsuleGroup<T>({
    required List<(T, String)> options,
    required T value,
    required ValueChanged<T> onChanged,
  }) {
    const innerH = 14.0 * 2 + 20.0;
    const outerH = innerH + 8;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.cardC,
        borderRadius: capsuleBorder(outerH),
      ),
      child: Row(
        children: [
          for (final o in options)
            Expanded(
              child: Pressable(
                onTap: () => onChanged(o.$1),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    color: value == o.$1 ? pal.sel : Colors.transparent,
                    borderRadius: capsuleBorder(innerH),
                  ),
                  child: Text(
                    o.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: value == o.$1 ? pal.bg : pal.ink,
                      fontWeight: value == o.$1
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Custom capsule toggle (replaces Material SwitchListTile): title +
  /// subtitle with an animated pill switch whose knob slides to the
  /// reading-direction end when on.
  Widget _toggleRow({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      color: pal.muted,
                      height: 1.6,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.curve,
              width: 54,
              height: 32,
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: value ? pal.sel : pal.div,
                borderRadius: capsuleBorder(32),
              ),
              child: AnimatedAlign(
                duration: Motion.base,
                curve: Motion.curve,
                alignment: value
                    ? AlignmentDirectional.centerEnd
                    : AlignmentDirectional.centerStart,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: pal.bg,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- تنظیمات ----------
  Widget _settingsPage(Dictionary d) {
    return _pageShell(
      'پیکربندی',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22 + kNavClearance),
          children: [
            _toggleRow(
              title: 'جایگزینی خودکار واژه‌های عربی با فارسی',
              subtitle: 'در کیبورد، واژهٔ عربیِ دارای برابرِ تک‌واژه‌ای، خودکار فارسی می‌شود',
              value: settings.replaceArabic,
              onChanged: (v) async {
                setState(() => settings.replaceArabic = v);
                await SettingsStore.update(settings);
              },
            ),
            _toggleRow(
              title: 'اصلاح خودکار املایی',
              subtitle: 'نیم‌فاصله، همزهٔ اضافه و مانند آن هنگام زدن فاصله',
              value: settings.autoCorrect,
              onChanged: (v) async {
                setState(() => settings.autoCorrect = v);
                await SettingsStore.update(settings);
              },
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ارتفاع کیبورد',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _capsuleGroup<String>(
                options: const [
                  ('short', 'کوتاه'),
                  ('normal', 'معمولی'),
                  ('tall', 'بلند'),
                ],
                value: settings.kbHeight,
                onChanged: (v) async {
                  setState(() => settings.kbHeight = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'تم و رنگ',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _capsuleGroup<String>(
                options: const [('light', 'روشن (کرم)'), ('dark', 'تیره')],
                value: settings.theme,
                onChanged: (v) async {
                  setState(() => settings.theme = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'فونت برنامه',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _capsuleGroup<String>(
                options: const [('arad', 'آراد'), ('system', 'پیش‌فرض سیستم')],
                value: settings.font,
                onChanged: (v) async {
                  setState(() => settings.font = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'اندازهٔ نوشته‌ها',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _capsuleGroup<String>(
                options: const [
                  ('small', 'کم'),
                  ('normal', 'معمولی'),
                  ('large', 'زیاد'),
                ],
                value: settings.textSize,
                onChanged: (v) async {
                  setState(() => settings.textSize = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const SizedBox(height: 20),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'جهت نمایش',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _capsuleGroup<String>(
                options: const [('rtl', 'راست‌چین'), ('ltr', 'چپ‌چین')],
                value: settings.direction,
                onChanged: (v) async {
                  setState(() => settings.direction = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(LucideIcons.keyboard),
              title: const Text('فعال‌کردن کیبورد سورن'),
              subtitle: const Text('تنظیمات کیبورد اندروید باز می‌شود'),
              onTap: () => SharedFiles.openInputSettings(),
            ),
            ListTile(
              leading: const Icon(LucideIcons.keyRound),
              title: const Text('برگزیدن کیبورد سورن به‌عنوان کیبورد کنونی'),
              onTap: () => SharedFiles.showKeyboardPicker(),
            ),
            const Divider(height: 32),
            ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: const Text('به‌روزرسانی پایگاه واژه‌ها'),
              subtitle: Text(
                'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — فایل JSON یا CSV برگزینید',
              ),
              onTap: () => _importDb(),
            ),
            ListTile(
              leading: const Icon(LucideIcons.cloud),
              title: const Text('به‌روزرسانی آنلاین از سرور'),
              subtitle: Text(
                'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — با اینترنت، تازه‌ترین پایگاه از سرور گرفته می‌شود؛ آفلاین، آرشیو روی گوشی به کار می‌رود',
              ),
              trailing: dbSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: dbSyncing ? null : () => _syncDbNow(d),
            ),
            ListTile(
              leading: const Icon(LucideIcons.upload),
              title: const Text('خروجی از پایگاه واژه‌ها'),
              subtitle: const Text(
                'JSON پایگاه در حافظهٔ برنامه ذخیره و مسیرش نشان داده می‌شود',
              ),
              onTap: () => _exportDb(d),
            ),
            const Divider(height: 32),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'درباره: سورن دیکشنری عربی به فارسی است با کیبوردی که درست‌نویسی فارسی را رعایت می‌کند. فونت برنامه: آراد. یادگیری کیبورد فقط روی همین دستگاه انجام می‌شود و داده‌ای بیرون نمی‌رود.',
                style: TextStyle(color: pal.muted, height: 1.9, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
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
    // Words already in the live dictionary before this import — anything
    // else in the imported file is new in this update (Fresh page).
    final beforeArs = {
      for (final e in (dict?.entries ?? const <Entry>[])) e.ar,
    };
    try {
      final isJson = content.trimLeft().startsWith('{');
      // Strict validation BEFORE anything is written: the existing
      // working dictionary is never overwritten by a bad file (B6).
      final check = validateDatasetText(content);
      if (!check.ok || check.data == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(check.error ?? 'این فایل خوانا نیست')),
          );
        }
        return;
      }
      final data = Map<String, dynamic>.of(check.data!);
      if (!isJson) {
        data['version'] = (dict?.version ?? 1) + 1;
      }
      await SharedFiles.writeJsonAtomic('dataset_updated.json', data);
      await _load();
      final freshArs = <String>[];
      final seen = <String>{};
      for (final raw in (data['entries'] as List? ?? const [])) {
        final ar = (raw as Map?)?['ar']?.toString() ?? '';
        if (ar.isEmpty || !seen.add(ar) || beforeArs.contains(ar)) continue;
        freshArs.add(ar);
      }
      await SharedFiles.writeJson('fresh_words.json', {
        'version': data['version'],
        'words': freshArs,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'پایگاه واژه‌ها به‌روز شد — ${faNum((data['entries'] as List).length)} مدخل',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('این فایل خوانا نیست: $e')),
        );
      }
    }
  }

  Future<void> _exportDb(Dictionary d) async {
    final f = await SharedFiles.file('dataset_export.json');
    await f.writeAsString(
      jsonEncode({
        'version': d.version,
        'entries': [
          for (final e in d.entries) {'ar': e.ar, 'fa': e.fa},
        ],
      }),
    );
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('ذخیره شد: ${f.path}')));
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
          child: ScrollEdgeFade(
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
                          Icon(LucideIcons.chevronLeft,
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
    setState(
      () => _out = correctText(
        v,
        dictionary: widget.dict.map,
        replaceArabic: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      'درست‌نویسی',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'متن بنویسید تا با همان موتوری که در کیبورد سورن کار می‌کند، درست شود:',
              style: TextStyle(color: pal.muted, height: 1.8),
            ),
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
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 18),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: pal.pillC,
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _out.isEmpty ? '…' : _out,
                  key: ValueKey(_out),
                  style: const TextStyle(fontSize: 17.5, height: 1.8),
                ),
              ),
            ),
            AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: enterTransition,
              child: _out.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('no-copy'))
                  : Column(
                      key: ValueKey(_out),
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(height: 14),
                        FilledButton(
                          style: capsuleBtn(bg: pal.sel),
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _out)),
                          child: const Text('کپی متن درست‌شده'),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= نیم‌فاصله =================
class NimeFaselePage extends StatelessWidget {
  const NimeFaselePage({super.key});
  @override
  Widget build(BuildContext context) {
    const items = <(String, String)>[
      (
        'میان پیشوند و فعل',
        'می‌خوام، نمی‌دونم، می‌رود — میان «می/نمی» و بنِ فعل نیم‌فاصله است.',
      ),
      (
        'پسوندهای «تر» و «ترین»',
        'عالی‌ترین، گرم‌تر، بزرگ‌ترین — به‌جز پنج واژهٔ چسبیده: بهتر، کمتر، بیشتر، مهتر، کهتر.',
      ),
      (
        '«ها»ی جمع',
        'کتاب‌ها، واژه‌ها، کتابها هم اگر چسبیده تایپ شود کیبورد آن را کتاب‌ها می‌کند.',
      ),
      (
        'پایان فعل‌های گذشتهٔ نقلی',
        'رفته‌ام، آمده‌ام، خوابیده‌اید — پسوندهای ام، ای، ایم، اید، اند پس از «ه» با نیم‌فاصله می‌آیند.',
      ),
      (
        'ضمیرهای چسبان پس از «ه» و «ی»',
        'خانه‌اش، کشتی‌شان، صفحه‌ام — این پسوندها هم نیم‌فاصله می‌خواهند.',
      ),
      (
        'ترکیب‌های «شده» و پیشوند «بی»',
        'گم‌شده، ترجمه‌شده، بی‌نهایت، بی‌آبرو.',
      ),
      (
        'همزهٔ اضافه (ٔ)',
        'همهٔ افراد، خانهٔ من، صفحهٔ نخست — پس از واژه‌های پایان‌یافته به «ه»، نشانهٔ اضافه «ٔ» است، نه «ی».',
      ),
      ('فاصله و نشانه‌ها', 'پیش از «،» و «.» و «؟» فاصله نمی‌آید: سلام، خوبی؟'),
    ];
    return subScaffold(
      'نیم‌فاصله',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'کیبورد سورن همهٔ این قاعده‌ها را هنگام تایپ، خودکار رعایت می‌کند.',
              style: TextStyle(color: pal.muted, height: 1.8),
            ),
            const SizedBox(height: 14),
            for (var i = 0; i < items.length; i++)
              Enter(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 13),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pal.pillC,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        items[i].$1,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        items[i].$2,
                        style: const TextStyle(
                          color: Color(0xFF5C5546),
                          height: 1.9,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= پندواژه (ضرب‌المثل‌ها) =================
class PandvazhePage extends StatefulWidget {
  final Set<String> liked;
  final Set<String> favorites;
  final Map<String, int> likeCounts;
  final Future<void> Function(String) onToggleLike;
  final Future<void> Function(String) onToggleFav;

  const PandvazhePage({
    super.key,
    required this.liked,
    required this.favorites,
    required this.likeCounts,
    required this.onToggleLike,
    required this.onToggleFav,
  });

  static const proverbs = <(String, String)>[
    ('از کوره دررفتن', 'زود خشمگین شدن و از اندازه بیرون رفتن.'),
    ('آب در هاون کوبیدن', 'کار بیهوده و بی‌سرانجام کردن.'),
    ('دست بالای دست بسیار است', 'همیشه کسی تواناتر از تو هست.'),
    (
      'جوجه را آخر پاییز می‌شمارند',
      'نتیجهٔ کار را باید در پایان دید، نه آغاز.',
    ),
    ('از دل برود هر آنکه از دیده برفت', 'دوری، مهر را کم می‌کند.'),
    (
      'کار نیکو کردن از پر کردن است',
      'خوبی با انباشته‌شدن از کارهای کوچک ساخته می‌شود.',
    ),
    (
      'هر که بامش بیش، برفش بیشتر',
      'هر که دارایی و جایگاهش بزرگ‌تر، گرفتاری‌اش هم بیشتر.',
    ),
    (
      'آش کشک خاله‌ته، بخوری پاته نخوری پاته',
      'کاری که گریزی از آن نیست؛ چه بخواهی چه نه، در آنی.',
    ),
    ('یک دست صدا ندارد', 'کار گروهی به‌تنهایی شدنی نیست.'),
    (
      'از این ستون به آن ستون فرج است',
      'با گذر زمان و جابه‌جایی، گشایشی پیش می‌آید.',
    ),
    ('عجله کار شیطان است', 'شتاب‌زدگی کار را خراب می‌کند.'),
    (
      'حرف راست را باید از بچه شنید',
      'راستِ بی‌پرده را کسی می‌گوید که نفعی در پنهان‌کردنش ندارد.',
    ),
    ('تا نباشد چیزکی، مردم نگویند چیزها', 'هر شایعه‌ای ریشه‌ای از راستی دارد.'),
    ('دل به دل راه دارد', 'مهر و احساس میان دو کس دوسویه است.'),
    (
      'صبر تلخ است ولیکن بر شیرین دارد',
      'شکیبایی سخت است اما میوه‌اش شیرین است.',
    ),
    (
      'آنچه شیران را کند روبه‌مزاج، احتیاج است',
      'نیاز، آدمِ دلیر را هم وادار به فروتنی می‌کند.',
    ),
    ('خواستن، توانستن است', 'ارادهٔ استوار راه رسیدن را باز می‌کند.'),
    ('کبوتر با کبوتر، باز با باز', 'هر کس با هم‌گونهٔ خود می‌آمیزد.'),
  ];

  @override
  State<PandvazhePage> createState() => _PandvazhePageState();
}

class _PandvazhePageState extends State<PandvazhePage> {
  late final Set<String> _liked = {...widget.liked};
  late final Set<String> _faved = {...widget.favorites};
  late final Map<String, int> _counts = {...widget.likeCounts};

  void _toggleLike(String key) {
    final now = !_liked.contains(key);
    setState(() {
      now ? _liked.add(key) : _liked.remove(key);
      final c = _counts[key] ?? 0;
      _counts[key] = now ? c + 1 : (c > 0 ? c - 1 : 0);
    });
    widget.onToggleLike(key);
  }

  void _toggleFav(String key) {
    final now = !_faved.contains(key);
    setState(() => now ? _faved.add(key) : _faved.remove(key));
    widget.onToggleFav(key);
  }

  /// Like + bookmark side by side (owner A11) — same widget as the word
  /// rows: outline icons, one faded inactive color, red when liked.
  Widget _likeFavRow(String key) {
    return LikeFavRow(
      liked: _liked.contains(key),
      faved: _faved.contains(key),
      likeCount: _counts[key] ?? 0,
      onLike: () => _toggleLike(key),
      onFav: () => _toggleFav(key),
    );
  }

  /// The proverb popup is EXACTLY the word card (owner A9): same sheet,
  /// same size, same options — one shared widget for both.
  void _proverbSheet(BuildContext context, String title, String meaning) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.bg,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => EntrySheet(
        title: title,
        infoRows: [('معنی', meaning)],
        shareText: [
          title,
          meaning,
          'سورن — پندواژه‌های فارسی',
        ].join('\n'),
        copyText: title,
        copyLabel: 'کپی پندواژه',
        liked: _liked.contains(title),
        faved: _faved.contains(title),
        likeCount: _counts[title] ?? 0,
        onLike: () => _toggleLike(title),
        onFav: () => _toggleFav(title),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      'پندواژه — ضرب‌المثل‌های فارسی',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            for (var i = 0; i < PandvazhePage.proverbs.length; i++)
              Enter(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Pressable(
                    onTap: () => _proverbSheet(
                      context,
                      PandvazhePage.proverbs[i].$1,
                      PandvazhePage.proverbs[i].$2,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            color: pal.pillC.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: pal.div.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      PandvazhePage.proverbs[i].$1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 19,
                                      ),
                                    ),
                                  ),
                                  _likeFavRow(PandvazhePage.proverbs[i].$1),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                PandvazhePage.proverbs[i].$2,
                                style: const TextStyle(
                                  color: Color(0xFF5C5546),
                                  height: 1.9,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ================= واژه‌های تازه =================
/// New words of the platform's LATEST update — not the keyboard-learned
/// history (that meaning moved out). The update's new entries are recorded
/// at import time (fresh_words.json); if an update predates that recording,
/// the page diffs the live dictionary against the bundled asset instead.
class FreshPage extends StatefulWidget {
  final Dictionary dict;
  final VoidCallback onWordOfDay;
  const FreshPage({super.key, required this.dict, required this.onWordOfDay});
  @override
  State<FreshPage> createState() => _FreshPageState();
}

class _FreshPageState extends State<FreshPage> {
  List<Entry>? _fresh;
  int _freshVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadFresh();
  }

  Future<void> _loadFresh() async {
    final j = await SharedFiles.readJson('fresh_words.json');
    var words = <String>[];
    var version = 0;
    if (j != null && j['words'] is List) {
      words = (j['words'] as List).map((e) => e.toString()).toList();
      version = (j['version'] as num?)?.toInt() ?? 0;
    } else {
      // No import record yet (or an update imported before the recording
      // existed): diff the live dictionary against the bundled asset.
      try {
        final raw = await rootBundle.loadString('assets/db/dataset.json');
        final bundled = jsonDecode(raw) as Map<String, dynamic>;
        final bundledArs = ((bundled['entries'] as List).map(
          (e) => (e as Map)['ar'].toString(),
        )).toSet();
        final live = await Dictionary.load();
        words = live.entries
            .where((e) => !bundledArs.contains(e.ar))
            .map((e) => e.ar)
            .toList();
        version = live.version;
      } catch (_) {}
    }
    final byAr = {for (final e in widget.dict.entries) e.ar: e};
    final items = [
      for (final w in words)
        if (byAr[w] != null) byAr[w]!,
    ];
    if (mounted) {
      setState(() {
        _fresh = items;
        _freshVersion = version;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final fresh = _fresh;
    return subScaffold(
      'واژه‌های تازه',
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 10, 24, 0),
        child: Column(
          children: [
            SizedBox(
              width: double.infinity,
              child: Pressable(
                onTap: widget.onWordOfDay,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 17),
                  decoration: BoxDecoration(
                    color: pal.pillC,
                    borderRadius: capsuleBorder(17 * 2 + 20),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(LucideIcons.star, size: 20, color: pal.ink),
                      const SizedBox(width: 9),
                      Text(
                        'واژهٔ روز',
                        style: TextStyle(fontSize: 15, color: pal.ink),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: fresh == null
                  ? const Center(child: CircularProgressIndicator())
                  : fresh.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(30),
                        child: Text(
                          'واژهٔ تازه‌ای هنوز نیست.\nبا به‌روزرسانی پایگاه واژه‌ها، واژه‌های تازهٔ آن به‌روزرسانی اینجا می‌آیند.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: pal.muted, height: 1.9),
                        ),
                      ),
                    )
                  : ScrollEdgeFade(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 6, bottom: 24),
                        itemCount: fresh.length + 1,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: pal.div),
                        itemBuilder: (_, i) {
                          if (i == 0) {
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Text(
                                _freshVersion > 0
                                    ? 'واژه‌های تازه در به‌روزرسانیِ نسخهٔ ${faNum(_freshVersion)} — ${faNum(fresh.length)} واژه'
                                    : 'واژه‌های تازه — ${faNum(fresh.length)} واژه',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 13,
                                ),
                              ),
                            );
                          }
                          final e = fresh[i - 1];
                          return Enter(
                            index: i,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Row(
                                children: [
                                  Text(
                                    e.ar,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 17.5,
                                      color: pal.ink,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      e.hasFa
                                          ? e.fa.join('، ')
                                          : 'برابر فارسی ثبت نشده',
                                      style: TextStyle(
                                        color: e.hasFa ? pal.muted : pal.faint,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
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
  final _ctrl = TextEditingController();
  String _query = '';
  List<Entry> _suggestions = const [];
  String _result = '';

  String _norm(String s) => normalizeLetters(s.trim());

  void _onChanged(String v) {
    final q = _norm(v);
    if (q.isEmpty) {
      setState(() {
        _query = '';
        _suggestions = const [];
        _result = '';
      });
      return;
    }
    final scored = <(int, Entry)>[];
    for (final e in widget.dict.entries) {
      final ar = _norm(e.ar);
      var score = -1;
      if (ar.startsWith(q)) {
        score = 0;
      } else if (ar.contains(q)) {
        score = 2;
      } else {
        for (final f in e.fa) {
          final nf = _norm(f);
          if (nf.startsWith(q)) {
            score = 1;
            break;
          }
          if (nf.contains(q)) {
            score = 3;
            break;
          }
        }
      }
      if (score >= 0) scored.add((score, e));
    }
    scored.sort((a, b) => a.$1.compareTo(b.$1));
    final exact = scored.where((s) => _norm(s.$2.ar) == q).toList();
    setState(() {
      _query = q;
      _suggestions = scored.take(20).map((s) => s.$2).toList();
      _result = exact.isNotEmpty ? _resultFor(exact.first.$2, q) : '';
    });
  }

  String _resultFor(Entry e, String q) {
    final ar = _norm(e.ar);
    if (ar == q || ar.startsWith(q) || ar.contains(q)) {
      return e.hasFa
          ? '«${e.ar}» واژه‌ای عربی است که در فارسی به کار می‌رود.\nبرابر فارسی آن: ${e.fa.join('، ')}'
          : '«${e.ar}» واژه‌ای عربی است؛ هنوز برابر فارسی برایش ثبت نشده.';
    }
    final matchedFa = e.fa.firstWhere(
      (f) => _norm(f).startsWith(q) || _norm(f).contains(q),
      orElse: () => e.fa.first,
    );
    return '«$matchedFa» واژه‌ای فارسی است (برابرِ «${e.ar}»).';
  }

  void _select(Entry e) {
    setState(() => _result = _resultFor(e, _query));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emptyQuery = _query.isEmpty;
    return subScaffold(
      'ریشه‌شناسی',
      Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            TextField(
              controller: _ctrl,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: 'واژه‌ای بنویسید تا ریشه‌اش را ببینید',
                prefixIcon: Icon(
                  LucideIcons.search,
                  color: pal.muted,
                  size: 23,
                ),
                filled: true,
                fillColor: pal.cardC,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: enterTransition,
              child: _result.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('no-result'))
                  : Container(
                      key: ValueKey(_result),
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: pal.pillC,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        _result,
                        style: const TextStyle(fontSize: 17, height: 1.9),
                      ),
                    ),
            ),
            Expanded(
              child: emptyQuery
                  ? Center(
                      child: Text(
                        'چند حرف از واژه را بنویسید؛ پیشنهادها همان‌جا می‌آیند.\nروی هر پیشنهاد بزنید تا ریشه‌اش را ببینید.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted, height: 1.9),
                      ),
                    )
                  : _suggestions.isEmpty
                  ? Center(
                      child: Text(
                        '«${_ctrl.text.trim()}» در گنجینهٔ کنونی سورن نیست.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted, height: 1.9),
                      ),
                    )
                  : ScrollEdgeFade(
                      child: ListView.separated(
                        padding: const EdgeInsets.only(top: 6, bottom: 24),
                        itemCount: _suggestions.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: pal.div),
                        itemBuilder: (_, i) {
                          final e = _suggestions[i];
                          return Enter(
                            index: i,
                            child: InkWell(
                              onTap: () => _select(e),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Text(
                                      e.ar,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 17.5,
                                        color: pal.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        e.hasFa
                                            ? e.fa.join('، ')
                                            : 'برابر فارسی ثبت نشده',
                                        style: TextStyle(
                                          color: e.hasFa
                                              ? pal.muted
                                              : pal.faint,
                                          fontSize: 13.5,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= راهنمای کیبورد =================
class KeyboardGuidePage extends StatelessWidget {
  const KeyboardGuidePage({super.key});
  @override
  Widget build(BuildContext context) {
    return subScaffold(
      'کیبورد سورن',
      ScrollEdgeFade(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
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
              style: TextStyle(height: 2, fontSize: 15),
            ),
            const SizedBox(height: 20),
            FilledButton(
              style: capsuleBtn(bg: pal.sel),
              onPressed: () => SharedFiles.openInputSettings(),
              child: const Text('بازکردن تنظیمات کیبورد اندروید'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: capsuleBtn(sideColor: pal.div),
              onPressed: () => SharedFiles.showKeyboardPicker(),
              child: const Text('برگزیدن کیبورد کنونی'),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= کارت واژه / پندواژه (یکسان) =================

/// THE one popup card for words AND proverbs (owner A9: the proverb card
/// must be exactly like the word card — same size, shape, options).
/// Like/bookmark sit side by side (A11) and toggling them updates this
/// card in place — no other card ever opens (A8 bug fix).
class EntrySheet extends StatefulWidget {
  final String title;
  final List<(String, String)> infoRows;
  final String shareText;
  final String copyText;
  final String copyLabel;
  final bool liked;
  final bool faved;
  final int likeCount;
  final VoidCallback onLike;
  final VoidCallback onFav;
  const EntrySheet({
    super.key,
    required this.title,
    required this.infoRows,
    required this.shareText,
    required this.copyText,
    this.copyLabel = 'کپی',
    required this.liked,
    required this.faved,
    this.likeCount = 0,
    required this.onLike,
    required this.onFav,
  });
  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late bool liked = widget.liked;
  late bool faved = widget.faved;

  @override
  Widget build(BuildContext context) {
    // Words keep the exact shape the word card always had: same padding,
    // same top radius (26), same title row — proverbs inherit all of it.
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    style: const TextStyle(
                      fontSize: 25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                LikeFavRow(
                  liked: liked,
                  faved: faved,
                  likeCount: widget.likeCount,
                  onLike: () {
                    setState(() => liked = !liked);
                    widget.onLike();
                  },
                  onFav: () {
                    setState(() => faved = !faved);
                    widget.onFav();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            for (var i = 0; i < widget.infoRows.length; i++) ...[
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${widget.infoRows[i].$1}: ${widget.infoRows[i].$2}',
                  style: TextStyle(color: pal.muted, fontSize: 14, height: 1.8),
                ),
              ),
              if (i != widget.infoRows.length - 1) const SizedBox(height: 8),
            ],
            const SizedBox(height: 16),
            Pressable(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  backgroundColor: pal.bg,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
                  ),
                  builder: (_) => ShareSheet(
                    title: widget.title,
                    shareText: widget.shareText,
                  ),
                );
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: pal.pillC,
                  borderRadius: capsuleBorder(buttonHeight(13)),
                  border: Border.all(color: pal.div),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(LucideIcons.share2, size: 18, color: pal.ink),
                    const SizedBox(width: 9),
                    Text(
                      'اشتراک‌گذاری',
                      style: TextStyle(fontSize: 14.5, color: pal.ink),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 11),
            Pressable(
              onTap: () {
                Clipboard.setData(ClipboardData(text: widget.copyText));
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('کپی شد')));
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: pal.sel,
                  borderRadius: capsuleBorder(buttonHeight(14)),
                ),
                child: Text(
                  widget.copyLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: pal.bg,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================= اشتراک‌گذاری (متن / عکس / متن و عکس) =================

/// Share options (owner A10): pick the format — text, image, or text and
/// image — and what to do with it: share it, or keep it on the phone
/// (image saved to the gallery, text copied). The generated image
/// carries ALL the information the app has about the entry.
class ShareSheet extends StatefulWidget {
  final String title;
  final String shareText;
  const ShareSheet({super.key, required this.title, required this.shareText});
  @override
  State<ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<ShareSheet> {
  String _format = 'text'; // text | image | both
  bool _busy = false;

  Future<Uint8List?> _renderImage() async {
    try {
      return await renderEntryImage(
        title: widget.title,
        body: widget.shareText,
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> _run(String action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final wantsImage = _format != 'text';
      final Uint8List? img = wantsImage ? await _renderImage() : null;
      if (wantsImage && img == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('ساخت عکس ممکن نشد')),
        );
        return;
      }
      switch ((action, _format)) {
        case ('share', 'text'):
          await SharePlatform.shareText(widget.shareText);
        case ('share', 'image'):
          await SharePlatform.shareImage(img!);
        case ('share', 'both'):
          await SharePlatform.shareImage(img!, text: widget.shareText);
        case ('save', 'text'):
          await Clipboard.setData(ClipboardData(text: widget.shareText));
          messenger.showSnackBar(
            const SnackBar(content: Text('متن کپی شد')),
          );
        case ('save', _):
          final path = await SharePlatform.saveImage(img!);
          messenger.showSnackBar(SnackBar(
            content: Text(path == null ? 'ذخیره نشد' : 'در حافظه ذخیره شد'),
          ));
        case ('copy', 'image'):
          final ok = await SharePlatform.copyImage(img!);
          messenger.showSnackBar(SnackBar(
            content: Text(ok ? 'عکس کپی شد' : 'کپی عکس ممکن نشد'),
          ));
        case ('copy', _):
          await Clipboard.setData(ClipboardData(text: widget.shareText));
          messenger.showSnackBar(const SnackBar(content: Text('کپی شد')));
      }
      if (action != 'share') navigator.pop();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(26, 22, 26, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'اشتراک‌گذاری «${widget.title}»',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            _capsulePicker(),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _actionButton('share', 'اشتراک‌گذاری', LucideIcons.share2),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton('save', 'ذخیره در گوشی', LucideIcons.save),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _actionButton('copy', 'کپی', LucideIcons.copy),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'عکس شامل همهٔ اطلاعات واژه است و در «Souren» حافظه ذخیره می‌شود.',
              textAlign: TextAlign.center,
              style: TextStyle(color: pal.muted, fontSize: 12, height: 1.7),
            ),
          ],
        ),
      ),
    );
  }

  Widget _capsulePicker() {
    const h = 46.0;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: pal.cardC,
        borderRadius: capsuleBorder(h),
      ),
      child: Row(
        children: [
          for (final (id, label) in const [
            ('text', 'متن'),
            ('image', 'عکس'),
            ('both', 'متن و عکس'),
          ])
            Expanded(
              child: Pressable(
                onTap: () => setState(() => _format = id),
                child: AnimatedContainer(
                  duration: Motion.base,
                  curve: Motion.curve,
                  height: h - 8,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: _format == id ? pal.sel : Colors.transparent,
                    borderRadius: capsuleBorder(h - 8),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      color: _format == id ? pal.bg : pal.ink,
                      fontWeight: _format == id
                          ? FontWeight.w700
                          : FontWeight.w400,
                      fontSize: 13.5,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _actionButton(String id, String label, IconData icon) {
    return Pressable(
      onTap: _busy ? null : () => _run(id),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: pal.pillC,
          borderRadius: capsuleBorder(buttonHeight(12)),
          border: Border.all(color: pal.div),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: pal.ink),
            const SizedBox(height: 5),
            Text(label, style: TextStyle(fontSize: 11.5, color: pal.ink)),
          ],
        ),
      ),
    );
  }
}

/// Renders the shareable portrait card (1080x1350) for a word or a
/// proverb with every piece of information the app has: the entry
/// itself, all its rows, and the Souren signature. Painted offscreen —
/// no widget tree, no packages.
Future<Uint8List?> renderEntryImage({
  required String title,
  required String body,
}) async {
  const w = 1080.0;
  const h = 1350.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(Offset.zero & const Size(w, h), Paint()..color = pal.bg);
  const margin = 72.0;
  const cardRect = Rect.fromLTWH(margin, margin, w - margin * 2, h - margin * 2);
  final cardRRect = RRect.fromRectAndRadius(
    cardRect,
    const Radius.circular(56),
  );
  canvas.drawRRect(cardRRect, Paint()..color = pal.cardC);

  Future<void> paintText(
    String text,
    double x,
    double y,
    double maxWidth, {
    required double size,
    required Color color,
    FontWeight weight = FontWeight.w400,
    TextAlign align = TextAlign.right,
  }) async {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Arad',
          fontSize: size,
          color: color,
          fontWeight: weight,
          height: 1.7,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.rtl,
    )..layout(maxWidth: maxWidth);
    tp.paint(canvas, Offset(x, y));
    return;
  }

  const pad = 56.0;
  var y = cardRect.top + pad + 36;
  await paintText(
    title,
    cardRect.left + pad,
    y,
    cardRect.width - pad * 2,
    size: 92,
    color: pal.ink,
    weight: FontWeight.w700,
  );
  y += 150;
  canvas.drawLine(
    Offset(cardRect.left + pad, y),
    Offset(cardRect.right - pad, y),
    Paint()
      ..color = pal.div
      ..strokeWidth = 3,
  );
  y += 44;
  final bodyLines = body.split('\n');
  for (final line in bodyLines) {
    if (line.trim().isEmpty) continue;
    await paintText(
      line,
      cardRect.left + pad,
      y,
      cardRect.width - pad * 2,
      size: 44,
      color: line == bodyLines.last ? pal.faint : pal.muted,
    );
    y += 78;
    if (y > cardRect.bottom - 190) break;
  }
  await paintText(
    'سورن',
    cardRect.left + pad,
    cardRect.bottom - pad - 96,
    cardRect.width - pad * 2,
    size: 40,
    color: pal.ink,
    weight: FontWeight.w700,
    align: TextAlign.center,
  );
  await paintText(
    'واژه‌نامهٔ عربی به فارسی',
    cardRect.left + pad,
    cardRect.bottom - pad - 40,
    cardRect.width - pad * 2,
    size: 30,
    color: pal.muted,
    align: TextAlign.center,
  );

  final picture = recorder.endRecording();
  final image = await picture.toImage(w.toInt(), h.toInt());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes?.buffer.asUint8List();
}

// ================= اعلان بج از بالای صفحه =================

/// Top notification (owner A17): tapping a badge slides a toast down
/// from the very top of the screen with the badge description.
void showBadgeToast(
  BuildContext context,
  IconData icon,
  String title,
  String description,
) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _BadgeToast(
      icon: icon,
      title: title,
      description: description,
      onDismiss: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _BadgeToast extends StatefulWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onDismiss;
  const _BadgeToast({
    required this.icon,
    required this.title,
    required this.description,
    required this.onDismiss,
  });
  @override
  State<_BadgeToast> createState() => _BadgeToastState();
}

class _BadgeToastState extends State<_BadgeToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Motion.base,
    reverseDuration: const Duration(milliseconds: 220),
  );

  @override
  void initState() {
    super.initState();
    _ctrl.forward();
    Future.delayed(const Duration(milliseconds: 2600), _dismiss);
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _ctrl.reverse();
    if (mounted) widget.onDismiss();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(parent: _ctrl, curve: Motion.curve);
    return Positioned(
      top: MediaQuery.of(context).padding.top + 10,
      left: 18,
      right: 18,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -1.4),
          end: Offset.zero,
        ).animate(curved),
        child: FadeTransition(
          opacity: curved,
          child: GestureDetector(
            onTap: _dismiss,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                decoration: BoxDecoration(
                  color: pal.sel,
                  borderRadius: capsuleBorder(78),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.18),
                      blurRadius: 22,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(widget.icon, color: pal.bg, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              color: pal.bg,
                              fontWeight: FontWeight.w700,
                              fontSize: 14.5,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.description,
                            style: TextStyle(
                              color: pal.bg.withValues(alpha: 0.85),
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
