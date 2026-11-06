import 'dart:convert';
import 'dart:math' as math;
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

/// Capsule roundness (round 2): 90% of the maximum — radius = 0.45 × the
/// capsule's own height (fully round would be 0.5 × height). Every
/// capsule computes its radius from its own fixed height through this
/// helper, so no two capsules share one hardcoded value.
double capR(double height) => height * 0.45;
BorderRadius capRadius(double height) => BorderRadius.circular(capR(height));

/// Scroll-aware top+bottom scroll fade (shared by every scrollable list).
/// Taller and smoother than round 1 (9% zones, eased multi-stop
/// gradient). The top fade is ZERO at scroll offset 0 — it only appears,
/// fading in smoothly (scroll-driven, smoothstepped), after the user
/// scrolls a little. The bottom fade reaches the viewport floor so
/// content dissolves as it slides behind the nav bar.
class ScrollFade extends StatefulWidget {
  final Widget child;
  const ScrollFade({super.key, required this.child});
  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late Animation<double> _anim;
  double _target = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 180),
    );
    _anim = Tween(
      begin: 0.0,
      end: 0.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  void _onScroll(ScrollNotification n) {
    // Smoothstep ramp over the first 48px of scroll.
    final t = (n.metrics.pixels / 48).clamp(0.0, 1.0);
    final eased = t * t * (3 - 2 * t);
    if ((eased - _target).abs() > 0.01) {
      _target = eased;
      _anim = Tween(
        begin: _anim.value,
        end: _target,
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
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
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _onScroll(n);
        return false;
      },
      child: AnimatedBuilder(
        animation: _anim,
        builder: (_, child) {
          final top = 0.09 * _anim.value; // top fade zone, 0..9%
          const bottom = 0.09; // bottom fade zone
          final gradient = top < 0.001
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black,
                    Colors.black,
                    Color(0xBF000000),
                    Color(0x59000000),
                    Colors.transparent,
                  ],
                  stops: [0, 0.91, 0.94, 0.97, 1],
                )
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: const [
                    Colors.transparent,
                    Color(0x59000000),
                    Color(0xBF000000),
                    Colors.black,
                    Colors.black,
                    Color(0xBF000000),
                    Color(0x59000000),
                    Colors.transparent,
                  ],
                  stops: [
                    0,
                    top * 0.4,
                    top * 0.75,
                    top,
                    1 - bottom,
                    1 - bottom * 0.75,
                    1 - bottom * 0.4,
                    1,
                  ],
                );
          return ShaderMask(
            shaderCallback: (rect) => gradient.createShader(rect),
            blendMode: BlendMode.dstIn,
            child: child,
          );
        },
        child: widget.child,
      ),
    );
  }
}

/// Soft top+bottom scroll fade (shared by every scrollable list in the app).
Widget edgeFade({required Widget child}) => ScrollFade(child: child);

/// Category display metadata: id -> (icon, Persian title).
const catMeta = <String, (IconData, String)>{
  'health': (LucideIcons.activity, 'پزشکی و تندرستی'),
  'work': (LucideIcons.briefcase, 'پیشه و کار'),
  'money': (LucideIcons.wallet, 'پول و بازار'),
  'edu': (LucideIcons.notebookPen, 'آموزش و دانش'),
  'lang': (LucideIcons.messageSquare, 'سخن و نوشتار'),
  'home': (LucideIcons.house, 'خانه و خانواده'),
  'nature': (LucideIcons.sun, 'طبیعت و گیتی'),
  'faith': (LucideIcons.moon, 'باور و آیین'),
  'state': (LucideIcons.building2, 'کشور و داد'),
  'mind': (LucideIcons.compass, 'دل و اندیشه'),
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

// ============ CUI components, recreated in Flutter ============
// CUI (yappologistic/CUI, MIT) is a C99 immediate-mode UI library — it
// cannot be imported into Flutter. These widgets recreate its
// components' look and motion (spring/overshoot, press dip, stretch) in
// Dart, in Souren's palette (Pal) and Arad typography. Behaviours follow
// docs/components.md in the CUI repo (~/workspace/cui-reference).

/// CUI button: presses scale to 0.97 on a snappy spring; one primary per
/// view; loading keeps the label so nothing jumps.
enum CuiButtonVariant { primary, secondary, outline, ghost, danger }

class CuiButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final CuiButtonVariant variant;
  final double height; // CUI sizes: sm 30, md 36, lg 44
  final IconData? icon;
  final bool loading;
  final bool fullWidth;
  const CuiButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = CuiButtonVariant.secondary,
    this.height = 44,
    this.icon,
    this.loading = false,
    this.fullWidth = false,
  });
  @override
  State<CuiButton> createState() => _CuiButtonState();
}

class _CuiButtonState extends State<CuiButton> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null && !widget.loading;
    final Color bg, fg;
    final BorderSide side;
    switch (widget.variant) {
      case CuiButtonVariant.primary:
        bg = pal.sel;
        fg = pal.bg;
        side = BorderSide.none;
      case CuiButtonVariant.secondary:
        bg = pal.cardC;
        fg = pal.ink;
        side = BorderSide.none;
      case CuiButtonVariant.outline:
        bg = Colors.transparent;
        fg = pal.ink;
        side = BorderSide(color: pal.div);
      case CuiButtonVariant.ghost:
        bg = Colors.transparent;
        fg = pal.ink;
        side = BorderSide.none;
      case CuiButtonVariant.danger:
        bg = pal.accent;
        fg = pal.bg;
        side = BorderSide.none;
    }
    final content = Row(
      mainAxisSize: widget.fullWidth ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading)
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        else if (widget.icon != null) ...[
          Icon(widget.icon, size: 18, color: fg),
          const SizedBox(width: 8),
        ],
        Text(
          widget.label,
          style: TextStyle(
            color: fg,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
    final btn = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => setState(() => _scale = 0.97) : null,
      onTapUp: enabled ? (_) => setState(() => _scale = 1) : null,
      onTapCancel: () => setState(() => _scale = 1),
      onTap: enabled ? widget.onPressed : null,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          height: widget.height,
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: capRadius(widget.height),
            border: Border.fromBorderSide(side),
          ),
          alignment: Alignment.center,
          child: Opacity(opacity: enabled ? 1 : 0.45, child: content),
        ),
      ),
    );
    return widget.fullWidth ? SizedBox(width: double.infinity, child: btn) : btn;
  }
}

/// CUI icon button: round, ghost by default. When the icon changes, the
/// old one shrinks away while the new one scales in. [switchKey] lets a
/// toggle (like/bookmark) animate the icon swap even when the glyph
/// itself stays the same and only the state changes.
class CuiIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final String? tooltip;
  final Object? switchKey;
  const CuiIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 22,
    this.color,
    this.tooltip,
    this.switchKey,
  });
  @override
  Widget build(BuildContext context) {
    final btn = IconButton(
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
      icon: AnimatedSwitcher(
        duration: Motion.fast,
        switchInCurve: Motion.curve,
        switchOutCurve: Motion.curve,
        transitionBuilder: (child, anim) => ScaleTransition(
          scale: Tween<double>(begin: 0.6, end: 1).animate(anim),
          child: FadeTransition(opacity: anim, child: child),
        ),
        child: Icon(
          icon,
          key: ValueKey(switchKey ?? icon),
          size: size,
          color: color ?? pal.ink,
        ),
      ),
      onPressed: onPressed,
    );
    return tooltip == null ? btn : Tooltip(message: tooltip, child: btn);
  }
}

/// CUI segmented control: the highlight's two edges have their own
/// springs — the leading edge runs ahead and the trailing one follows, so
/// the highlight stretches toward the new option and draws in as it
/// lands. (One controller: the leading edge interpolates while the
/// highlight's width swells mid-flight, so the trailing edge lags.)
/// Replaces the old hand-rolled _capsuleGroup.
class CuiSegmented<T> extends StatefulWidget {
  final List<(T, String)> options;
  final T value;
  final ValueChanged<T> onChanged;
  final List<IconData>? icons;
  const CuiSegmented({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.icons,
  });
  @override
  State<CuiSegmented<T>> createState() => _CuiSegmentedState<T>();
}

class _CuiSegmentedState<T> extends State<CuiSegmented<T>>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  int _index = 0;
  double _from = 0;
  double _to = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _index = widget.options.indexWhere((o) => o.$1 == widget.value);
    if (_index < 0) _index = 0;
    _from = _to = _index.toDouble();
  }

  @override
  void didUpdateWidget(covariant CuiSegmented<T> old) {
    super.didUpdateWidget(old);
    final i = widget.options.indexWhere((o) => o.$1 == widget.value);
    if (i >= 0 && i != _index) {
      _from = _pos();
      _to = i.toDouble();
      _index = i;
      _ctrl.forward(from: 0);
    }
  }

  double _pos() {
    final t = Curves.easeOutCubic.transform(_ctrl.value);
    return _from + (_to - _from) * t;
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const h = 56.0;
    return LayoutBuilder(
      builder: (context, c) {
        final innerW = c.maxWidth - 8;
        final ow = innerW / widget.options.length;
        return Container(
          height: h,
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: pal.cardC,
            borderRadius: capRadius(h),
          ),
          child: ClipRRect(
            borderRadius: capRadius(h - 8),
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final pos = _pos();
                    final stretch = 1 + 0.22 * math.sin(math.pi * _ctrl.value);
                    return Positioned(
                      left: pos * ow,
                      top: 0,
                      bottom: 0,
                      width: ow * stretch,
                      child: Container(
                        decoration: BoxDecoration(
                          color: pal.sel,
                          borderRadius: capRadius(h - 8),
                        ),
                      ),
                    );
                  },
                ),
                Row(
                  children: [
                    for (var i = 0; i < widget.options.length; i++)
                      Expanded(
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onChanged(widget.options[i].$1),
                          child: Container(
                            height: double.infinity,
                            alignment: Alignment.center,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (widget.icons != null) ...[
                                  Icon(
                                    widget.icons![i],
                                    size: 17,
                                    color: i == _index ? pal.bg : pal.ink,
                                  ),
                                  const SizedBox(width: 6),
                                ],
                                Text(
                                  widget.options[i].$2,
                                  style: TextStyle(
                                    color: i == _index ? pal.bg : pal.ink,
                                    fontWeight: i == _index
                                        ? FontWeight.w700
                                        : FontWeight.w400,
                                    fontSize: 14,
                                  ),
                                ),
                              ],
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
      },
    );
  }
}

/// CUI switch: the thumb stretches with its speed in flight, keeping its
/// volume, and rounds out as it lands; a press dips the control;
/// checking overshoots a touch and settles. Applies immediately.
class CuiSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  const CuiSwitch({super.key, required this.value, required this.onChanged});
  @override
  State<CuiSwitch> createState() => _CuiSwitchState();
}

class _CuiSwitchState extends State<CuiSwitch>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _scale = 1;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      value: widget.value ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant CuiSwitch old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      if (widget.value) {
        _ctrl.animateTo(
          1,
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutBack,
        );
      } else {
        _ctrl.animateTo(
          0,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
        );
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const w = 54.0, h = 32.0, pad = 3.0, thumb = 26.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.94),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onChanged(!widget.value);
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            // Stretch mid-flight, volume preserved (x grows, y shrinks).
            final stretch = 1 + 0.28 * math.sin(math.pi * t);
            final squash = 1 - 0.14 * math.sin(math.pi * t);
            final trackColor = Color.lerp(pal.div, pal.sel, t)!;
            final x = pad + (w - 2 * pad - thumb) * t;
            return ClipRRect(
              borderRadius: capRadius(h),
              child: Container(
                width: w,
                height: h,
                decoration: BoxDecoration(
                  color: trackColor,
                  borderRadius: capRadius(h),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: x,
                      top: pad,
                      child: Transform.scale(
                        scaleX: stretch,
                        scaleY: squash,
                        alignment: Alignment.center,
                        child: Container(
                          width: thumb,
                          height: thumb,
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
          },
        ),
      ),
    );
  }
}

/// CUI checkbox: the whole row is clickable; a press dips the box;
/// checking overshoots a touch and settles.
class CuiCheckbox extends StatefulWidget {
  final bool value;
  final ValueChanged<bool> onChanged;
  final String label;
  final String? description;
  const CuiCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.description,
  });
  @override
  State<CuiCheckbox> createState() => _CuiCheckboxState();
}

class _CuiCheckboxState extends State<CuiCheckbox> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onChanged(!widget.value);
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Row(
          children: [
            AnimatedContainer(
              duration: Motion.base,
              curve: Motion.curve,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: widget.value ? pal.sel : Colors.transparent,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: widget.value ? pal.sel : pal.div,
                  width: 1.5,
                ),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) => ScaleTransition(
                  scale: Tween<double>(
                    begin: 0.4,
                    end: 1,
                  ).animate(CurvedAnimation(parent: anim, curve: Motion.pop)),
                  child: child,
                ),
                child: widget.value
                    ? Icon(
                        LucideIcons.check,
                        key: const ValueKey('on'),
                        size: 16,
                        color: pal.bg,
                      )
                    : const SizedBox.shrink(key: ValueKey('off')),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: pal.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CUI radio: a press dips the circle; selecting overshoots a touch and
/// settles, the dot scaling in.
class CuiRadio extends StatefulWidget {
  final bool selected;
  final VoidCallback onTap;
  final String label;
  final String? description;
  const CuiRadio({
    super.key,
    required this.selected,
    required this.onTap,
    required this.label,
    this.description,
  });
  @override
  State<CuiRadio> createState() => _CuiRadioState();
}

class _CuiRadioState extends State<CuiRadio> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.96),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: widget.selected ? pal.sel : pal.div,
                  width: 1.5,
                ),
              ),
              child: Center(
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, anim) => ScaleTransition(
                    scale: Tween<double>(
                      begin: 0.2,
                      end: 1,
                    ).animate(
                      CurvedAnimation(parent: anim, curve: Motion.pop),
                    ),
                    child: child,
                  ),
                  child: widget.selected
                      ? Container(
                          key: const ValueKey('on'),
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: pal.sel,
                            shape: BoxShape.circle,
                          ),
                        )
                      : const SizedBox.shrink(key: ValueKey('off')),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.description != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      widget.description!,
                      style: TextStyle(
                        fontSize: 13,
                        color: pal.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// CUI chip: toggle chip; press scales to 0.97 on a spring.
class CuiChip extends StatefulWidget {
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback? onTap;
  const CuiChip({
    super.key,
    required this.label,
    this.icon,
    required this.selected,
    this.onTap,
  });
  @override
  State<CuiChip> createState() => _CuiChipState();
}

class _CuiChipState extends State<CuiChip> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    const h = 36.0;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _scale = 0.97),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _scale = 1),
      onTapCancel: () => setState(() => _scale = 1),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Container(
          height: h,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: widget.selected ? pal.sel : pal.pillC,
            borderRadius: capRadius(h),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: 18,
                  color: widget.selected ? pal.bg : pal.muted,
                ),
                const SizedBox(width: 7),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: widget.selected ? pal.bg : pal.muted,
                  fontWeight: widget.selected
                      ? FontWeight.w700
                      : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// CUI text field: label, placeholder, hint, error, leading icon, and a
/// clear button when not empty (always on for the search variant).
class CuiTextField extends StatefulWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final String? label;
  final String? error;
  final IconData? icon;
  final bool search;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onSubmitted;
  final TextInputType? keyboardType;
  final int maxLines;
  final double height;
  final bool autofocus;
  final bool obscureText;
  const CuiTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.label,
    this.error,
    this.icon,
    this.search = false,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.maxLines = 1,
    this.height = 56,
    this.autofocus = false,
    this.obscureText = false,
  });
  @override
  State<CuiTextField> createState() => _CuiTextFieldState();
}

class _CuiTextFieldState extends State<CuiTextField> {
  late final TextEditingController _ctl;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _ctl = widget.controller ?? TextEditingController();
    _hasText = _ctl.text.isNotEmpty;
    _ctl.addListener(() {
      final has = _ctl.text.isNotEmpty;
      if (has != _hasText && mounted) setState(() => _hasText = has);
    });
  }

  @override
  Widget build(BuildContext context) {
    final field = TextField(
      controller: _ctl,
      focusNode: widget.focusNode,
      onChanged: widget.onChanged,
      onSubmitted: (_) => widget.onSubmitted?.call(),
      keyboardType: widget.keyboardType,
      maxLines: widget.maxLines,
      autofocus: widget.autofocus,
      obscureText: widget.obscureText,
      style: const TextStyle(fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hint,
        hintStyle: TextStyle(color: pal.muted, fontSize: 14.5),
        border: InputBorder.none,
        contentPadding: EdgeInsets.symmetric(
          horizontal: widget.icon == null ? 18 : 0,
          vertical: 16,
        ),
      ),
    );
    final box = Container(
      height: widget.maxLines > 1 ? null : widget.height,
      padding: widget.maxLines > 1
          ? const EdgeInsets.symmetric(horizontal: 18, vertical: 4)
          : null,
      decoration: BoxDecoration(
        color: pal.cardC,
        borderRadius: capRadius(
          widget.maxLines > 1 ? widget.height : widget.height,
        ),
        border: widget.error != null
            ? Border.all(color: pal.accent, width: 1.5)
            : null,
      ),
      child: Row(
        children: [
          if (widget.icon != null) ...[
            const SizedBox(width: 16),
            Icon(widget.icon, color: pal.muted, size: 22),
            const SizedBox(width: 10),
          ],
          Expanded(child: field),
          AnimatedSwitcher(
            duration: Motion.fast,
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: _hasText
                ? CuiIconButton(
                    key: const ValueKey('clear'),
                    icon: LucideIcons.x,
                    size: 18,
                    color: pal.muted,
                    onPressed: () {
                      _ctl.clear();
                      widget.onChanged?.call('');
                    },
                  )
                : const SizedBox.shrink(key: ValueKey('no-clear')),
          ),
          if (_hasText) const SizedBox(width: 6),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.label != null) ...[
          Padding(
            padding: const EdgeInsets.only(right: 4, bottom: 7),
            child: Text(
              widget.label!,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: pal.ink,
              ),
            ),
          ),
        ],
        box,
        if (widget.error != null) ...[
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(
              widget.error!,
              style: TextStyle(color: pal.accent, fontSize: 13),
            ),
          ),
        ],
      ],
    );
  }
}

/// CUI card: hairline border, no shadow. Pressable cards dip with a
/// spring scale on press.
class CuiCard extends StatefulWidget {
  final Widget child;
  final Color? color;
  final double radius;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? height;
  const CuiCard({
    super.key,
    required this.child,
    this.color,
    this.radius = 20,
    this.padding,
    this.onTap,
    this.height,
  });
  @override
  State<CuiCard> createState() => _CuiCardState();
}

class _CuiCardState extends State<CuiCard> {
  double _scale = 1;
  @override
  Widget build(BuildContext context) {
    final card = Container(
      height: widget.height,
      padding: widget.padding,
      decoration: BoxDecoration(
        color: widget.color ?? pal.cardC,
        borderRadius: BorderRadius.circular(widget.radius),
        border: Border.all(color: pal.div),
      ),
      child: widget.child,
    );
    if (widget.onTap == null) return card;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _scale = 0.98),
      onTapUp: (_) {
        setState(() => _scale = 1);
        widget.onTap!();
      },
      onTapCancel: () => setState(() => _scale = 1),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: card,
      ),
    );
  }
}

/// CUI badge: small status pill, tones mapped to Souren's palette.
enum CuiTone { neutral, success, warning, danger, info }

class CuiBadge extends StatelessWidget {
  final String label;
  final CuiTone tone;
  final bool dot;
  final bool solid;
  const CuiBadge({
    super.key,
    required this.label,
    this.tone = CuiTone.neutral,
    this.dot = false,
    this.solid = false,
  });
  @override
  Widget build(BuildContext context) {
    final Color bg, fg;
    switch (tone) {
      case CuiTone.neutral:
        bg = pal.pillC;
        fg = pal.muted;
      case CuiTone.success:
        bg = solid ? pal.sel : pal.pillC;
        fg = solid ? pal.bg : pal.sel;
      case CuiTone.warning:
      case CuiTone.danger:
        bg = solid ? pal.accent : pal.pillC;
        fg = solid ? pal.bg : pal.accent;
      case CuiTone.info:
        bg = solid ? pal.sel : pal.pillC;
        fg = solid ? pal.bg : pal.sel;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (dot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: fg, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// The ONE back button in the app: Lucide arrow (flips in RTL), pops the
/// route. Used everywhere a back button appears — page headers, sheets,
/// search — so it never shows a stray icon again.
class CuiBackButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const CuiBackButton({super.key, this.onPressed});
  @override
  Widget build(BuildContext context) {
    return CuiIconButton(
      icon: LucideIcons.arrowLeft,
      size: 24,
      onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
    );
  }
}

/// CUI list item: leading icon, title, subtitle, trailing. Replaces
/// Material ListTile.
class CuiListItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const CuiListItem({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 22, color: pal.ink),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 15)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 13,
                        color: pal.muted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
      ),
    );
  }
}

/// CUI toast: slides up with a spring, auto-dismisses, drag sideways to
/// dismiss (a fling or a long drag carries it off; a short one springs
/// back). Shown with CuiToast.show — replaces SnackBar everywhere.
class CuiToast {
  static void show(BuildContext context, String message) {
    final overlay = Overlay.of(context);
    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _ToastWidget(
        message: message,
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );
    overlay.insert(entry);
  }
}

class _ToastWidget extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;
  const _ToastWidget({required this.message, required this.onDismiss});
  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  bool _gone = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
    );
    _ctrl.forward();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_gone) _dismiss();
    });
  }

  Future<void> _dismiss() async {
    if (_gone) return;
    _gone = true;
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
    return Positioned(
      bottom: 132,
      left: 24,
      right: 24,
      child: Center(
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, child) {
            final t = Curves.easeOutBack.transform(_ctrl.value);
            return Opacity(
              opacity: _ctrl.value,
              child: Transform.translate(
                offset: Offset(0, 24 * (1 - t)),
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
            );
          },
          child: Dismissible(
            key: const ValueKey('toast'),
            direction: DismissDirection.horizontal,
            onDismissed: (_) {
              _gone = true;
              widget.onDismiss();
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
              decoration: BoxDecoration(
                color: pal.sel,
                borderRadius: capRadius(48),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(LucideIcons.check, size: 18, color: pal.bg),
                  const SizedBox(width: 9),
                  Flexible(
                    child: Text(
                      widget.message,
                      style: TextStyle(color: pal.bg, fontSize: 14.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// CUI slider: drag past either end and the track stretches like rubber,
/// then springs back on release; tapping the track glides the thumb.
/// (Library component — no current screen has a slider control yet.)
class CuiSlider extends StatefulWidget {
  final double value; // 0..1
  final ValueChanged<double> onChanged;
  final String Function(double)? format;
  const CuiSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.format,
  });
  @override
  State<CuiSlider> createState() => _CuiSliderState();
}

class _CuiSliderState extends State<CuiSlider>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  double _value = 0;
  double _over = 0; // rubber-band overshoot beyond 0..1 (-0.25..0.25)

  @override
  void initState() {
    super.initState();
    _value = widget.value.clamp(0.0, 1.0);
    _ctrl = AnimationController(vsync: this, duration: Motion.base);
  }

  @override
  void didUpdateWidget(covariant CuiSlider old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) _value = widget.value.clamp(0.0, 1.0);
  }

  void _springBack() {
    final from = _over;
    _ctrl.reset();
    final anim = Tween(begin: from, end: 0.0).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutBack),
    );
    anim.addListener(() {
      if (mounted) setState(() => _over = anim.value);
    });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shown = (_value + _over * 0.5).clamp(-0.1, 1.1);
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.maxWidth;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) {
                final target = (d.localPosition.dx / w).clamp(0.0, 1.0);
                final from = _value;
                _ctrl.reset();
                final anim = Tween(begin: from, end: target).animate(
                  CurvedAnimation(parent: _ctrl, curve: Motion.curve),
                );
                anim.addListener(() {
                  if (mounted) {
                    setState(() => _value = anim.value);
                  }
                });
                anim.addStatusListener((s) {
                  if (s == AnimationStatus.completed) {
                    widget.onChanged(_value);
                  }
                });
                _ctrl.forward();
              },
              onHorizontalDragUpdate: (d) {
                final dv = d.delta.dx / w;
                var next = _value + dv;
                var over = 0.0;
                if (next < 0) {
                  over = (next * 0.4).clamp(-0.25, 0.0);
                  next = 0;
                } else if (next > 1) {
                  over = ((next - 1) * 0.4).clamp(0.0, 0.25);
                  next = 1;
                }
                setState(() {
                  _value = next;
                  _over = over;
                });
                widget.onChanged(_value);
              },
              onHorizontalDragEnd: (_) => _springBack(),
              child: SizedBox(
                height: 32,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 6,
                      decoration: BoxDecoration(
                        color: pal.div,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: shown.clamp(0.0, 1.0),
                      child: Container(
                        height: 6,
                        decoration: BoxDecoration(
                          color: pal.sel,
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                    Positioned(
                      left: shown * w - 12,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: pal.bg,
                          shape: BoxShape.circle,
                          border: Border.all(color: pal.sel, width: 2),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.format != null) ...[
              const SizedBox(height: 6),
              Text(
                widget.format!(_value),
                style: TextStyle(color: pal.muted, fontSize: 13),
              ),
            ],
          ],
        );
      },
    );
  }
}

/// CUI sheet (bottom): slides up from the bottom edge. The word-entry
/// and proverb detail sheets share this one look (item 10).
Future<void> cuiShowSheet(BuildContext context, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: pal.bg,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (_) => child,
  );
}

/// The ONE detail sheet in the app (item 10): the word-entry popup
/// and the proverb popup are EXACTLY the same card — same size, same
/// shape, same options (like, bookmark, copy). The toggles update in
/// place (no pop-and-reopen).
class DetailSheet extends StatefulWidget {
  final String title;
  final String body;
  final bool liked;
  final bool faved;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleFav;
  final String copyLabel;
  final String copyText;
  const DetailSheet({
    super.key,
    required this.title,
    required this.body,
    required this.liked,
    required this.faved,
    required this.onToggleLike,
    required this.onToggleFav,
    required this.copyLabel,
    required this.copyText,
  });
  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet> {
  late bool _liked = widget.liked;
  late bool _faved = widget.faved;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 22, 26, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CuiIconButton(
                    icon: LucideIcons.heart,
                    size: 22,
                    color: _liked ? pal.accent : pal.ink,
                    tooltip: 'پسندیدن',
                    onPressed: () {
                      setState(() => _liked = !_liked);
                      widget.onToggleLike();
                    },
                  ),
                  CuiIconButton(
                    icon: LucideIcons.bookmark,
                    size: 22,
                    color: pal.ink,
                    tooltip: 'نشان کردن',
                    onPressed: () {
                      setState(() => _faved = !_faved);
                      widget.onToggleFav();
                    },
                  ),
                ],
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.body,
              style: TextStyle(color: pal.muted, fontSize: 14, height: 1.8),
            ),
          ),
          const SizedBox(height: 16),
          CuiButton(
            label: widget.copyLabel,
            icon: LucideIcons.copy,
            variant: CuiButtonVariant.primary,
            fullWidth: true,
            onPressed: () {
              Clipboard.setData(ClipboardData(text: widget.copyText));
              Navigator.pop(context);
              CuiToast.show(context, 'کپی شد');
            },
          ),
        ],
      ),
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

  // Device screen corner radius (item 14): read from Android (API 31+
  // RoundedCorner via the souren/screen channel); 28dp fallback until
  // it arrives. The nav bar's corners match the phone's own corners.
  double _cornerRadius = 28;

  // Home bottom-anchored layout (item 13): the word list is exactly as
  // tall as the left buttons column, measured after layout.
  final _homeButtonsKey = GlobalKey();
  final _homeRowKey = GlobalKey();
  double _homeListH = 556;
  double _homeRowH = 590;

  void _measureHome() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bBox =
          _homeButtonsKey.currentContext?.findRenderObject() as RenderBox?;
      final rBox =
          _homeRowKey.currentContext?.findRenderObject() as RenderBox?;
      var changed = false;
      if (bBox != null && (bBox.size.height - _homeListH).abs() > 0.5) {
        _homeListH = bBox.size.height;
        changed = true;
      }
      if (rBox != null && (rBox.size.height - _homeRowH).abs() > 0.5) {
        _homeRowH = rBox.size.height;
        changed = true;
      }
      if (changed) setState(() {});
    });
  }

  Future<void> _fetchCornerRadius() async {
    try {
      final v = await const MethodChannel(
        'souren/screen',
      ).invokeMethod<double>('cornerRadius');
      if (v != null && v > 0 && mounted) {
        setState(() => _cornerRadius = v);
      }
    } catch (_) {
      // No rounded corners reported (or old Android): keep the fallback.
    }
  }

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
      // Post-frame: rebuilding synchronously inside the focus change
      // eats the tap that opened the keyboard (it took two taps).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
      });
    });
    _fetchCornerRadius();
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

  Widget _likeButton(String ar) {
    final isLiked = liked.contains(ar);
    final count = likeCounts[ar] ?? 0;
    // The count lives in a fixed-width slot that is always present, so
    // liking a word never shifts the row layout.
    return Row(mainAxisSize: MainAxisSize.min, children: [
      SizedBox(
        width: 26,
        child: AnimatedSwitcher(
          duration: Motion.fast,
          transitionBuilder: (child, anim) =>
              FadeTransition(opacity: anim, child: child),
          child: count > 0
              ? Text(
                  faNum(count),
                  key: ValueKey(count),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 12.5),
                )
              : const SizedBox.shrink(key: ValueKey('none')),
        ),
      ),
      CuiIconButton(
        icon: LucideIcons.heart,
        switchKey: isLiked,
        size: 21,
        color: isLiked ? pal.accent : pal.muted,
        tooltip: 'پسندیدن',
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
        top: true,
        bottom: false,
        // Tabs switch INSTANTLY (round 2): no cross-fade, no slide —
        // the user dislikes tab-switch animation. The key only rebuilds
        // the page when font/direction/text size change.
        child: KeyedSubtree(
          key: ValueKey(
            '${settings.font}_${settings.direction}_${settings.textSize}',
          ),
          child: pages[tab],
        ),
      ),
      bottomNavigationBar: _navBar(),
    );
  }

  // Nav bar (round 2): NO glassmorphism — the background is the
  // PREVIOUS opaque color (pal.cardC) again, no BackdropFilter, no
  // transparency. NO animation either: tabs switch instantly — no
  // sliding indicator, no label appear/disappear, no pill morph (the
  // user's standing preference). The selected pill is a static capsule
  // (radius = 90% of max, 0.45 × its height); the bar's outer corners
  // use the phone's own screen corner radius (item 14), and the bar
  // sits flush at the bottom edge (SafeArea clears the gesture bar).
  Widget _navBar() {
    final items = <(IconData, String)>[
      (LucideIcons.house, 'پیشگاه'),
      (LucideIcons.heart, 'پسندیده‌ها'),
      (LucideIcons.grid3x3, 'بخش‌ها'),
      (LucideIcons.bookmark, 'نشان‌شده'),
      (LucideIcons.user, 'نمایه'),
      (LucideIcons.settings, 'پیکربندی'),
    ];
    final selSoft = Color.lerp(pal.sel, pal.bg, 0.38)!;
    // Selected pill: icon 23 + vertical padding 28 = 51 tall.
    const pillH = 51.0;
    const barPadV = 6.0;
    const barH = pillH + barPadV * 2;
    return SafeArea(
      top: false,
      bottom: true,
      left: false,
      right: false,
      child: Container(
        height: barH,
        margin: const EdgeInsets.fromLTRB(22, 6, 22, 0),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: barPadV),
        decoration: BoxDecoration(
          color: pal.cardC,
          borderRadius: BorderRadius.circular(_cornerRadius),
          border: Border.all(color: pal.div.withValues(alpha: 0.6)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var i = 0; i < items.length; i++)
              GestureDetector(
                onTap: () => _go(i),
                child: Container(
                  height: pillH,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: tab == i ? selSoft : Colors.transparent,
                    borderRadius: capRadius(pillH),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        items[i].$1,
                        size: 23,
                        color: tab == i
                            ? pal.bg
                            : pal.ink.withValues(alpha: .72),
                      ),
                      if (tab == i) ...[
                        const SizedBox(width: 7),
                        Text(
                          items[i].$2,
                          style: TextStyle(
                            color: pal.bg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ---------- پیشگاه ----------
  // Home is bottom-anchored (item 13): from the bottom — nav bar, then a
  // row (section buttons LEFT, word list RIGHT, the list exactly as tall
  // as the buttons), then the search capsule. The capsule is a positioned
  // overlay so it can slide toward the centre and unfold its results
  // like a roller blind (item 7d), above the strong blur.
  Widget _home(Dictionary d) {
    final frequent = d.entries.where((e) => e.hasFa).take(60).toList();
    final results = query.isEmpty
        ? const <Entry>[]
        : d.entries
              .where(
                (e) =>
                    e.ar.contains(query) || e.fa.any((f) => f.contains(query)),
              )
              .toList();
    _measureHome();
    return LayoutBuilder(
      builder: (context, c) {
        final bodyH = c.maxHeight;
        const capsuleH = 58.0;
        const gap = 14.0;
        // Resting capsule top: just above the row (the row's bottom
        // clears the nav bar by kNavClearance). Far from the top edge
        // (item 6) because the whole stack is bottom-anchored.
        final restingTop = bodyH - kNavClearance - _homeRowH - gap - capsuleH;
        // While searching the capsule slides toward the centre of the
        // screen so the roller-blind results have room below it.
        final focusedTop = bodyH * 0.18;
        final capTop = _searchFocused ? focusedTop : restingTop;
        final dropH = _searchFocused
            ? (query.isEmpty
                  ? 96.0
                  : (results.length * 51.0 + 28).clamp(96.0, 360.0))
            : 0.0;
        return Stack(
          children: [
            // Main content: the row, bottom-anchored above the nav bar.
            Positioned(
              left: 24,
              right: 24,
              bottom: kNavClearance,
              child: Row(
                key: _homeRowKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Word list on the RIGHT (first child in RTL).
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'پرکاربردترین واژگان فارسی',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 17.5,
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            height: _homeListH,
                            child: _pairList(frequent, bottomPad: 0),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Section buttons on the LEFT.
                    SizedBox(
                      width: 124,
                      child: Column(
                        key: _homeButtonsKey,
                        children: [
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
                          // Word of the Day on Home too (item 12).
                          _sidePill(
                            'واژهٔ روز',
                            () => _pushPage(_dailyPage(d)),
                          ),
                          _sidePill(
                            'ریشه‌شناسی',
                            () => _open(EtymologyPage(dict: d)),
                          ),
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(top: 12),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            decoration: BoxDecoration(
                              color: pal.pillC,
                              borderRadius: BorderRadius.circular(20),
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
                  ],
                ),
              ),
            // Strong blur + dim over the whole page while searching
            // (item 7a: several times stronger than round 1's sigma 10).
            if (_searchFocused)
              Positioned.fill(
                child: GestureDetector(
                  onTap: () => _searchFocus.unfocus(),
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                    child: ColoredBox(
                      color: pal.bg.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ),
            // Search capsule: slides toward the centre while searching.
            // One tap focuses AND shows the keyboard (item 7b): the
            // opaque tap handler requests focus and forces the input
            // open, and the focus listener rebuilds post-frame so the
            // rebuild never eats the tap.
            AnimatedPositioned(
              duration: Motion.base,
              curve: Motion.curve,
              top: capTop,
              left: 24,
              right: 24,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _searchFocus.requestFocus();
                  SystemChannels.textInput.invokeMethod('TextInput.show');
                },
                child: SizedBox(
                  height: capsuleH,
                  child: CuiTextField(
                    controller: _searchCtl,
                    focusNode: _searchFocus,
                    hint: 'واژه‌ای را جستجو کنید',
                    icon: LucideIcons.search,
                    search: true,
                    height: capsuleH,
                    onChanged: (v) => setState(() => query = v.trim()),
                  ),
                ),
              ),
            ),
            // Roller-blind results: unfold downward from under the
            // capsule, in the capsule's own layer — ABOVE the blur
            // (item 7d). The panel grows from 0 height, its content
            // clipped at the bottom edge as it opens.
            if (_searchFocused)
              AnimatedPositioned(
                duration: Motion.base,
                curve: Motion.curve,
                top: capTop + capsuleH,
                left: 24,
                right: 24,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Motion.curve,
                  height: dropH,
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(26),
                    ),
                    child: ColoredBox(
                      color: pal.cardC,
                      child: query.isEmpty
                          ? Center(
                              child: Text(
                                'واژه‌ای بنویسید تا نتیجه‌ها اینجا بیایند',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : results.isEmpty
                          ? Center(
                              child: Text(
                                '«${_searchCtl.text.trim()}» پیدا نشد',
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 14,
                                ),
                              ),
                            )
                          : edgeFade(
                              child: ListView.separated(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  8,
                                  18,
                                  14,
                                ),
                                itemCount: results.length,
                                separatorBuilder: (_, __) =>
                                    Divider(height: 1, color: pal.div),
                                itemBuilder: (_, i) =>
                                    _pairRow(results[i]),
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            // Back button: fades + slides in when searching (item 7c).
            // Same Lucide arrow as every other back button (item 11).
            Positioned(
              top: 6,
              right: 18,
              child: AnimatedSwitcher(
                duration: Motion.base,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.4),
                      end: Offset.zero,
                    ).animate(
                      CurvedAnimation(parent: anim, curve: Motion.curve),
                    ),
                    child: ScaleTransition(
                      scale: Tween<double>(
                        begin: 0.8,
                        end: 1,
                      ).animate(
                        CurvedAnimation(parent: anim, curve: Motion.curve),
                      ),
                      child: child,
                    ),
                  ),
                ),
                child: _searchFocused
                    ? CuiBackButton(
                        key: const ValueKey('back'),
                        onPressed: () => _searchFocus.unfocus(),
                      )
                    : const SizedBox.shrink(key: ValueKey('no-back')),
              ),
            ),
          ],
        );
      },
    );
  }

  // Section pill on Home: fixed height 54 so its radius is computed
  // from its own height (90% of max, 0.45 × 54).
  Widget _sidePill(String label, VoidCallback onTap) {
    const h = 54.0;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: h,
        margin: const EdgeInsets.only(bottom: 11),
        decoration: BoxDecoration(
          color: pal.pillC,
          borderRadius: capRadius(h),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: pal.ink),
        ),
      ),
    );
  }

  /// Pair list with the shared top+bottom scroll fade and the unified
  /// entrance. [bottomPad] clears the floating nav bar on tab pages.
  Widget _pairList(List<Entry> items, {double bottomPad = 0}) {
    if (items.isEmpty) {
      return Center(
        child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)),
      );
    }
    return edgeFade(
      child: ListView.separated(
        padding: EdgeInsets.only(top: 6, bottom: bottomPad),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
        itemBuilder: (_, i) => Enter(index: i, child: _pairRow(items[i])),
      ),
    );
  }

  /// عربی درشت و پررنگ (سر‌واژه)، فارسی کوچک و کم‌رنگ (برابر).
  Widget _pairRow(Entry e) {
    return InkWell(
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
                e.hasFa ? e.fa.join('، ') : 'برابر فارسی ثبت نشده',
                style: TextStyle(
                  color: e.hasFa ? pal.muted : pal.faint,
                  fontSize: 13.5,
                ),
              ),
            ),
            _likeButton(e.ar),
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
    // Opening a detail sheet dismisses the search (keyboard + blur).
    _searchFocus.unfocus();
    cuiShowSheet(
      context,
      DetailSheet(
        title: e.ar,
        body: e.hasFa
            ? 'برابر فارسی: ${e.fa.join('، ')}'
            : 'برای این واژه هنوز برابر فارسی ثبت نشده است.',
        liked: liked.contains(e.ar),
        faved: favorites.contains(e.ar),
        onToggleLike: () => _toggleLike(e.ar),
        onToggleFav: () => _toggleFav(e.ar),
        copyLabel: 'کپی برابر فارسی',
        copyText: e.hasFa ? e.fa.first : e.ar,
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
    final tiles = <(IconData, String, VoidCallback)>[
      (
        LucideIcons.fileText,
        'گنجینهٔ واژه‌ها',
        () => _open(LexiconPage(dict: d, onTapEntry: _showEntry)),
      ),
      (
        LucideIcons.squarePen,
        'درست‌نویسی',
        () => _open(CorrectorPage(dict: d)),
      ),
      (
        LucideIcons.type,
        'نیم‌فاصله',
        () => _open(const NimeFaselePage()),
      ),
      (LucideIcons.messageSquare, 'پندواژه', () => _open(_pandvazhePage())),
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
      (LucideIcons.heart, 'پسندیده‌ها', () => _go(1)),
      (LucideIcons.bookmark, 'نشان‌شده', () => _go(3)),
      (LucideIcons.star, 'واژهٔ روز', () => _pushPage(_dailyPage(d))),
      (
        LucideIcons.notebookPen,
        'یادگیری من',
        () => _pushPage(_learningPage()),
      ),
      (LucideIcons.user, 'نمایهٔ کاربری', () => _go(4)),
      (
        LucideIcons.keyboard,
        'کیبورد سورن',
        () => _open(const KeyboardGuidePage()),
      ),
      (LucideIcons.refreshCw, 'به‌روزرسانی پایگاه', () => _go(5)),
      (LucideIcons.settings, 'پیکربندی', () => _go(5)),
    ];
    return _pageShell(
      'بخش‌ها',
      edgeFade(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 14),
                child: Enter(
                  index: 0,
                  child: CuiCard(
                    onTap: () => _pushPage(_categoriesPage(d)),
                    color: pal.pillC,
                    height: 98,
                    padding: const EdgeInsets.symmetric(horizontal: 22),
                    child: Row(
                        children: [
                          Icon(
                            LucideIcons.layoutDashboard,
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
                      child: CuiCard(
                        onTap: tiles[i].$3,
                        color: pal.pillC,
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
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          children: [
            for (var i = 0; i < catOrder.length; i++)
              Enter(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: CuiCard(
                    onTap: () =>
                        _pushPage(_categoryWordsPage(d, catOrder[i])),
                    color: pal.pillC,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
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
              CuiButton(
                label: 'دیدن واژه',
                variant: CuiButtonVariant.outline,
                onPressed: () => _showEntry(e),
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
          return edgeFade(
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
                CuiButton(
                  label: 'پاک‌کردن آموخته‌ها',
                  variant: CuiButtonVariant.outline,
                  fullWidth: true,
                  onPressed: () async {
                    final f = await SharedFiles.file('learned.json');
                    if (await f.exists()) await f.delete();
                    setState(() {});
                  },
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
      LucideIcons.archive,
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
      edgeFade(
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
            CuiCard(
              color: pal.cardC,
              padding: const EdgeInsets.all(20),
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
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final id in badgeIds)
                  Builder(
                    builder: (_) {
                      final earned = badgeEarned(
                        id,
                        loggedIn: user != null,
                        favorites: favorites.length,
                        likes: liked.length,
                        corrections: learnedCorrections,
                        score: score,
                      );
                      final meta = _badgeMeta[id]!;
                      return CuiChip(
                        label: meta.$2,
                        icon: meta.$1,
                        selected: earned,
                        onTap: null,
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 6),
            for (final id in badgeIds)
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: Text(
                  '• ${_badgeMeta[id]!.$2}: ${_badgeMeta[id]!.$3}',
                  style: TextStyle(fontSize: 12.5, color: pal.muted),
                ),
              ),
            const SizedBox(height: 24),
            CuiCard(
              color: pal.cardC,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
              CuiButton(
                label: 'همگام‌سازی اکنون',
                variant: CuiButtonVariant.outline,
                fullWidth: true,
                onPressed: () async {
                  await AuthService.pushProfile(favorites, liked);
                  await _syncAfterLogin();
                  if (mounted) CuiToast.show(context, 'همگام‌سازی انجام شد');
                },
              ),
              const SizedBox(height: 11),
              CuiButton(
                label: 'خروج از نمایه',
                variant: CuiButtonVariant.danger,
                fullWidth: true,
                onPressed: () async {
                  await AuthService.logout();
                  if (mounted) setState(() {});
                },
              ),
            ],
            const SizedBox(height: 10),
            CuiListItem(
              icon: LucideIcons.notebookPen,
              title: 'آموخته‌های کیبورد',
              subtitle: 'آنچه کیبورد سورن از شما آموخته است',
              trailing: Icon(
                LucideIcons.chevronLeft,
                size: 18,
                color: pal.muted,
              ),
              onTap: () => _pushPage(_learningPage()),
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
    return Column(
      children: [
        CuiButton(
          label: 'ورود به نمایه',
          variant: CuiButtonVariant.primary,
          fullWidth: true,
          onPressed: () => setState(() {
            showAuthForm = true;
            authRegister = false;
            authError = null;
          }),
        ),
        const SizedBox(height: 11),
        CuiButton(
          label: 'ساخت نمایهٔ تازه',
          variant: CuiButtonVariant.outline,
          fullWidth: true,
          onPressed: () => setState(() {
            showAuthForm = true;
            authRegister = true;
            authError = null;
          }),
        ),
      ],
    );
  }

  Widget _authForm() {
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
          if (authRegister) ...[
            CuiTextField(
              controller: _nameCtl,
              hint: 'نام نمایشی (مانند: سورن)',
              icon: LucideIcons.user,
            ),
            const SizedBox(height: 11),
          ],
          CuiTextField(
            controller: _userCtl,
            hint: 'نام کاربری',
            icon: LucideIcons.user,
          ),
          const SizedBox(height: 11),
          CuiTextField(
            controller: _passCtl,
            hint: 'گذرواژه (دست‌کم ۶ نویسه)',
            icon: LucideIcons.lock,
            obscureText: true,
            error: authError,
          ),
          const SizedBox(height: 15),
          CuiButton(
            label: authRegister ? 'ساختن نمایه' : 'ورود',
            variant: CuiButtonVariant.primary,
            fullWidth: true,
            loading: authBusy,
            onPressed: authBusy ? null : _authSubmit,
          ),
          CuiButton(
            label: authRegister ? 'نمایه دارید؟ وارد شوید' : 'نمایه ندارید؟ یکی بسازید',
            variant: CuiButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => setState(() {
              authRegister = !authRegister;
              authError = null;
            }),
          ),
          CuiButton(
            label: 'پس‌نمایش',
            variant: CuiButtonVariant.ghost,
            fullWidth: true,
            onPressed: () => setState(() => showAuthForm = false),
          ),
        ],
      ),
    );
  }

  /// CUI segmented control (replaces the old hand-rolled capsule
  /// group and Material SegmentedButton): two-spring highlight.
  Widget _capsuleGroup<T>({
    required List<(T, String)> options,
    required T value,
    required ValueChanged<T> onChanged,
  }) {
    return CuiSegmented<T>(
      options: options,
      value: value,
      onChanged: onChanged,
    );
  }

  /// CUI toggle row: title + subtitle with the CUI switch (stretching
  /// thumb, overshoot, press dip) — replaces Material SwitchListTile.
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
            CuiSwitch(value: value, onChanged: onChanged),
          ],
        ),
      ),
    );
  }

  // ---------- تنظیمات ----------
  Widget _settingsPage(Dictionary d) {
    return _pageShell(
      'پیکربندی',
      edgeFade(
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
            CuiListItem(
              icon: LucideIcons.keyboard,
              title: 'فعال‌کردن کیبورد سورن',
              subtitle: 'تنظیمات کیبورد اندروید باز می‌شود',
              onTap: () => SharedFiles.openInputSettings(),
            ),
            CuiListItem(
              icon: LucideIcons.repeat,
              title: 'برگزیدن کیبورد سورن به‌عنوان کیبورد کنونی',
              onTap: () => SharedFiles.showKeyboardPicker(),
            ),
            const Divider(height: 32),
            CuiListItem(
              icon: LucideIcons.refreshCw,
              title: 'به‌روزرسانی پایگاه واژه‌ها',
              subtitle:
                  'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — فایل JSON یا CSV برگزینید',
              onTap: () => _importDb(),
            ),
            CuiListItem(
              icon: LucideIcons.download,
              title: 'به‌روزرسانی آنلاین از سرور',
              subtitle:
                  'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — با اینترنت، تازه‌ترین پایگاه از سرور گرفته می‌شود؛ آفلاین، آرشیو روی گوشی به کار می‌رود',
              trailing: dbSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: dbSyncing ? null : () => _syncDbNow(d),
            ),
            CuiListItem(
              icon: LucideIcons.upload,
              title: 'خروجی از پایگاه واژه‌ها',
              subtitle:
                  'JSON پایگاه در حافظهٔ برنامه ذخیره و مسیرش نشان داده می‌شود',
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
      CuiToast.show(
        context,
        updated
            ? 'پایگاه واژه‌ها به‌روز شد'
            : 'پایگاه به‌روز است یا ارتباط با سرور برقرار نشد',
      );
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
              'fa': parts
                  .sublist(1)
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList(),
            });
          }
        }
        data = {'version': (dict?.version ?? 1) + 1, 'entries': entries};
      }
      await SharedFiles.writeJson('dataset_updated.json', data);
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
        CuiToast.show(context, 'پایگاه واژه‌ها به‌روز شد');
      }
    } catch (e) {
      if (mounted) {
        CuiToast.show(
          context,
          'این فایل خوانا نیست؛ JSON یا CSV درست برگزینید',
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
      CuiToast.show(context, 'ذخیره شد: ${f.path}');
    }
  }

  Widget _pageShell(String title, Widget body, {bool back = false}) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
        child: Row(children: [
          if (back) ...[
            const CuiBackButton(),
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
                  const CuiBackButton(),
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
          child: edgeFade(
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
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'متن بنویسید تا با همان موتوری که در کیبورد سورن کار می‌کند، درست شود:',
              style: TextStyle(color: pal.muted, height: 1.8),
            ),
            const SizedBox(height: 14),
            CuiTextField(
              controller: _ctrl,
              onChanged: _run,
              maxLines: 4,
              hint: 'مثلاً: میخام عالیترین کتابها رو به همه افراد بدم، سوال دارم',
            ),
            const SizedBox(height: 18),
            CuiCard(
              color: pal.pillC,
              padding: const EdgeInsets.all(18),
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
                        CuiButton(
                          label: 'کپی متن درست‌شده',
                          icon: LucideIcons.copy,
                          variant: CuiButtonVariant.primary,
                          fullWidth: true,
                          onPressed: () =>
                              Clipboard.setData(ClipboardData(text: _out)),
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
      edgeFade(
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
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 13),
                  child: CuiCard(
                    color: pal.pillC,
                    padding: const EdgeInsets.all(18),
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

  Widget _likeButton(String key) {
    final isLiked = _liked.contains(key);
    final count = _counts[key] ?? 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (count > 0)
          Text(
            faNum(count),
            style: TextStyle(color: pal.muted, fontSize: 12.5),
          ),
        CuiIconButton(
          icon: LucideIcons.heart,
          switchKey: isLiked,
          size: 21,
          color: isLiked ? pal.accent : pal.muted,
          tooltip: 'پسندیدن',
          onPressed: () => _toggleLike(key),
        ),
      ],
    );
  }

  Widget _favButton(String key) {
    final isFav = _faved.contains(key);
    return CuiIconButton(
      icon: LucideIcons.bookmark,
      switchKey: isFav,
      size: 21,
      color: pal.ink,
      tooltip: 'نشان کردن',
      onPressed: () => _toggleFav(key),
    );
  }

  // The proverb popup is EXACTLY the word-entry popup (item 10):
  // same DetailSheet — same size, shape and options.
  void _proverbSheet(BuildContext context, String title, String meaning) {
    cuiShowSheet(
      context,
      DetailSheet(
        title: title,
        body: meaning,
        liked: _liked.contains(title),
        faved: _faved.contains(title),
        onToggleLike: () => _toggleLike(title),
        onToggleFav: () => _toggleFav(title),
        copyLabel: 'کپی ضرب‌المثل',
        copyText: title,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      'پندواژه — ضرب‌المثل‌های فارسی',
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
          children: [
            for (var i = 0; i < PandvazhePage.proverbs.length; i++)
              Enter(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: GestureDetector(
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
                                  _likeButton(PandvazhePage.proverbs[i].$1),
                                  _favButton(PandvazhePage.proverbs[i].$1),
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
            CuiButton(
              label: 'واژهٔ روز',
              icon: LucideIcons.star,
              variant: CuiButtonVariant.secondary,
              height: 54,
              fullWidth: true,
              onPressed: widget.onWordOfDay,
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
                  : edgeFade(
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
            CuiTextField(
              controller: _ctrl,
              onChanged: _onChanged,
              hint: 'واژه‌ای بنویسید تا ریشه‌اش را ببینید',
              icon: LucideIcons.search,
              search: true,
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: Motion.base,
              transitionBuilder: enterTransition,
              child: _result.isEmpty
                  ? const SizedBox.shrink(key: ValueKey('no-result'))
                  : Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: CuiCard(
                        key: ValueKey(_result),
                        color: pal.pillC,
                        padding: const EdgeInsets.all(18),
                        child: Text(
                          _result,
                          style: const TextStyle(fontSize: 17, height: 1.9),
                        ),
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
                  : edgeFade(
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
      edgeFade(
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
            CuiButton(
              label: 'بازکردن تنظیمات کیبورد اندروید',
              variant: CuiButtonVariant.primary,
              fullWidth: true,
              onPressed: () => SharedFiles.openInputSettings(),
            ),
            const SizedBox(height: 12),
            CuiButton(
              label: 'برگزیدن کیبورد کنونی',
              variant: CuiButtonVariant.outline,
              fullWidth: true,
              onPressed: () => SharedFiles.showKeyboardPicker(),
            ),
          ],
        ),
      ),
    );
  }
}
