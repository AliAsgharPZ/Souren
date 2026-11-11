import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_drawing/path_drawing.dart';

import 'lucide.dart';
import 'share.dart';

import 'data/store.dart';
import 'data/ganjoor_pack.dart';
import 'data/persian_roots.dart';
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

/// Souren motion tokens: concise, purposeful and driven by direct
/// manipulation. Keep timings consistent; avoid decorative movement.
/// Souren's own visual language with purposeful, restrained motion:
/// short ease-out transitions, subtle press feedback and no decorative bounce.
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 420);
  static const curve = Cubic(0.22, 1.0, 0.36, 1.0);
  static const pop = Curves.easeOutBack;
  static const staggerStep = Duration(milliseconds: 22);

  /// Short, interrupt-friendly interaction timings inspired by Apple's
  /// continuity-first motion guidance. Keep overshoot subtle and optional.
  static const pressDown = Duration(milliseconds: 100);
  static const pressUp = Duration(milliseconds: 300);
  static const spring = Cubic(0.2, 1.08, 0.32, 1.0);
}

/// Keep pushed pages on the known-good v0.4.1.1 route behavior.
/// The app theme supplies the same restrained page transition; do not add
/// a second custom fade/slide/scale layer here.
PageRoute<T> _softRoute<T>(Widget page) =>
    MaterialPageRoute<T>(builder: (_) => page);

/// Capsule roundness (round 3): 90% of the maximum — the radius is
/// 45% of the capsule's height, so a capsule is almost a pill but
/// keeps a whisper of its corners.
double capR(double height) => height * 0.45;

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
        begin: const Offset(0, 0.014),
        end: Offset.zero,
      ).animate(curved),
      child: ScaleTransition(
        scale: Tween<double>(begin: 0.985, end: 1.0).animate(curved),
        child: child,
      ),
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

/// Scroll-aware top+bottom fade, shared by every scrollable list in
/// the app. The fade zones are long and soft (16% of the viewport,
/// eased multi-stop gradient) and start right at the viewport's top
/// and bottom edges. The TOP fade is hidden at offset 0 and fades in
/// smoothly over the first ~48px of scrolling, so a fresh page shows
/// its first rows at full strength.
class ScrollFade extends StatefulWidget {
  final Widget child;
  final bool alwaysVisible;
  final double fadeExtent;
  final double fadeStrength;
  const ScrollFade({
    super.key,
    required this.child,
    this.alwaysVisible = false,
    this.fadeExtent = 0.22,
    this.fadeStrength = 0.94,
  });
  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade> {
  double _top = 0;
  double _bottom = 0;

  void _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final topProgress = (n.metrics.pixels / 48).clamp(0.0, 1.0);
      final bottomProgress = n.metrics.maxScrollExtent > 1
          ? (1 - n.metrics.extentAfter / 48).clamp(0.0, 1.0)
          : 0.0;
      // Smoothstep keeps both edge fades tied to the actual scroll edges.
      double smooth(double value) => value * value * (3 - 2 * value);
      final top = smooth(topProgress);
      final bottom = smooth(bottomProgress);
      if ((top - _top).abs() > 0.005 ||
          (bottom - _bottom).abs() > 0.005) {
        setState(() {
          _top = top;
          _bottom = bottom;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (n) {
        _onScroll(n);
        return false;
      },
      child: ShaderMask(
        shaderCallback: (rect) {
          final top = widget.alwaysVisible ? widget.fadeStrength : _top;
          final bottom = widget.alwaysVisible ? widget.fadeStrength : _bottom;
          final fade = widget.fadeExtent;
          // Preserve the first and last rows; fade the next rows as
          // scrolling brings them to the viewport edges.
          return LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.fromRGBO(0, 0, 0, 1 - top),
              Color.fromRGBO(0, 0, 0, 1 - top * 0.55),
              Colors.black,
              Colors.black,
              Color.fromRGBO(0, 0, 0, 1 - bottom),
              Colors.black,
            ],
            stops: [
              0,
              fade * 0.45,
              fade * 0.9,
              1 - fade * 0.9,
              1 - fade * 0.45,
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

/// The name every scrollable in the app already wraps in; the
/// implementation is now the scroll-aware ScrollFade.
Widget edgeFade({
  required Widget child,
  bool alwaysVisible = false,
  double fadeExtent = 0.22,
  double fadeStrength = 0.94,
}) => ScrollFade(
  alwaysVisible: alwaysVisible,
  fadeExtent: fadeExtent,
  fadeStrength: fadeStrength,
  child: child,
);

/// Apple-like press feedback for every custom button: the control
/// dips subtly (scale 0.975 + slight dim) the moment the finger lands and
/// springs back on release. Material buttons already do their own
/// splash; this is for the GestureDetector-based controls that had
/// no reaction at all when held.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scale = 0.975,
  });
  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  bool _pressed = false;
  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    lowerBound: .92,
    upperBound: 1.02,
    value: 1,
  );

  void _set(bool value) {
    if (_pressed == value) return;
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    setState(() => _pressed = value);
    if (reduceMotion) {
      _scaleController.value = 1;
      return;
    }
    final target = value ? widget.scale.clamp(.92, 1.02).toDouble() : 1.0;
    _scaleController.animateWith(
      SpringSimulation(
        const SpringDescription(
          mass: 1,
          stiffness: 420,
          damping: 30,
        ),
        _scaleController.value,
        target,
        _scaleController.velocity,
      ),
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    final duration = reduceMotion
        ? Duration.zero
        : (_pressed ? Motion.pressDown : Motion.pressUp);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onLongPressEnd: (_) => _set(false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress ?? widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleController,
        child: AnimatedOpacity(
          opacity: reduceMotion ? 1.0 : (_pressed ? 0.84 : 1.0),
          duration: duration,
          child: widget.child,
        ),
        builder: (context, child) => Transform.scale(
          scale: reduceMotion ? 1.0 : _scaleController.value,
          child: child,
        ),
      ),
    );
  }
}

/// One pressable outline icon: never filled. Inactive = one faded
/// color; active = [activeColor] (red for like, black for bookmark).
Widget pressIcon({
  required bool active,
  required IconData icon,
  required Color activeColor,
  required VoidCallback onTap,
}) {
  final inactive = pal.muted.withValues(alpha: 0.55);
  return Pressable(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Icon(
        icon,
        size: 21,
        color: active ? activeColor : inactive,
        fill: active ? 1 : 0,
        weight: active ? 600 : 400,
      ),
    ),
  );
}

/// Like + bookmark actions, side by side everywhere: outline icons only.
/// Personal state is stored per account; no global like totals are requested
/// or rendered.
class LikeBookmarkButtons extends StatelessWidget {
  final bool liked;
  final bool bookmarked;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;
  const LikeBookmarkButtons({
    super.key,
    required this.liked,
    required this.bookmarked,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    void runToggle({
      required bool wasActive,
      required String message,
      required VoidCallback action,
    }) {
      action();
      if (!wasActive) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 10),
          content: Text(message),
          action: SnackBarAction(
            label: 'واگردانی',
            onPressed: action,
          ),
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pressIcon(
          active: liked,
          icon: Symbols.favorite_rounded,
          activeColor: pal.accent,
          onTap: () => runToggle(
            wasActive: liked,
            message: 'از پسندیده‌ها حذف شد',
            action: onToggleLike,
          ),
        ),
        pressIcon(
          active: bookmarked,
          icon: Symbols.bookmark_rounded,
          activeColor: pal.ink,
          onTap: () => runToggle(
            wasActive: bookmarked,
            message: 'از نشان‌شده‌ها حذف شد',
            action: onToggleBookmark,
          ),
        ),
      ],
    );
  }
}

/// A short description slides down from the top of the screen like a
/// notification, then slides back up. Used for badge descriptions.
void showTopBanner(
  BuildContext context, {
  required String title,
  required String message,
}) {
  final overlay = Overlay.of(context);
  var gone = false;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) => _TopBanner(
      title: title,
      message: message,
      onDone: () {
        if (!gone) {
          gone = true;
          entry.remove();
        }
      },
    ),
  );
  overlay.insert(entry);
}

class _TopBanner extends StatefulWidget {
  final String title;
  final String message;
  final VoidCallback onDone;
  const _TopBanner({
    required this.title,
    required this.message,
    required this.onDone,
  });
  @override
  State<_TopBanner> createState() => _TopBannerState();
}

class _TopBannerState extends State<_TopBanner> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) setState(() => _visible = true);
    });
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) setState(() => _visible = false);
    });
    Future.delayed(const Duration(milliseconds: 3000), () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : const Offset(0, -1.2),
        duration: Motion.base,
        curve: Motion.curve,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: Motion.fast,
          child: GestureDetector(
            onTap: () {
              setState(() => _visible = false);
              Future.delayed(Motion.base, widget.onDone);
            },
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: pal.cardC,
                  borderRadius: BorderRadius.circular(capR(52)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 12,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.badgeCheck, size: 20, color: pal.sel),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.title,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: pal.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.message,
                            style: TextStyle(
                              fontSize: 12.5,
                              color: pal.muted,
                              height: 1.5,
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

/// The meaning text for a row: all meanings joined, or just the
/// first one when [single] (home rows show one meaning, one line).
String meaningText(Entry e, {bool single = false}) {
  if (!e.hasFa) return 'برابر فارسی ثبت نشده';
  return single ? e.fa.first : e.fa.join('، ');
}

/// The ONE detail card for words and proverbs alike (round 3): same
/// size, shape and options — like, bookmark, share, copy. The sheet
/// keeps its own visual state and updates in place, so toggling like
/// or bookmark never closes it and never opens another card.
class DetailSheet extends StatefulWidget {
  final ShareCardData card;
  final bool initialLiked;
  final bool initialBookmarked;
  final Future<void> Function() onToggleLike;
  final Future<void> Function() onToggleBookmark;
  final VoidCallback? onOpenEtymology;
  final String? etymologyWord;
  final List<String> relatedPersianWords;
  final String? relatedPoemTitle;
  final List<Entry> relatedEntries;
  final void Function(Entry)? onOpenRelatedEntry;
  final List<String> copyableLines;
  final bool showActions;
  const DetailSheet({
    super.key,
    required this.card,
    required this.initialLiked,
    required this.initialBookmarked,
    required this.onToggleLike,
    required this.onToggleBookmark,
    this.onOpenEtymology,
    this.etymologyWord,
    this.relatedPersianWords = const [],
    this.relatedPoemTitle,
    this.relatedEntries = const [],
    this.onOpenRelatedEntry,
    this.copyableLines = const [],
    this.showActions = true,
  });
  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet> {
  late bool _liked = widget.initialLiked;
  late bool _bookmarked = widget.initialBookmarked;

  Future<void> _copyText(String value, String message) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: pal.muted.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(capR(7)),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: widget.copyableLines.isEmpty
                    ? Text(
                        widget.card.title,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: const TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (var i = 0; i < widget.copyableLines.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: SelectableText(
                                widget.copyableLines[i],
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
                                style: const TextStyle(
                                  fontSize: 25,
                                  fontWeight: FontWeight.w700,
                                  height: 1.7,
                                ),
                              ),
                            ),
                        ],
                      ),
              ),
              if (widget.showActions)
                LikeBookmarkButtons(
                  liked: _liked,
                  bookmarked: _bookmarked,
                  onToggleLike: () async {
                    setState(() => _liked = !_liked);
                    await widget.onToggleLike();
                  },
                  onToggleBookmark: () async {
                    setState(() => _bookmarked = !_bookmarked);
                    await widget.onToggleBookmark();
                  },
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.card.breadcrumb != null) ...[
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.card.breadcrumb!,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: pal.faint, fontSize: 11.5, height: 1.6),
              ),
            ),
          ],
          if (widget.card.meaning != null) ...[
            const SizedBox(height: 9),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.card.meaning!,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: pal.muted, fontSize: 14, height: 1.8),
              ),
            ),
          ],
          if (widget.card.lines.isNotEmpty)
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.card.lines.join('\n'),
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(color: pal.muted, fontSize: 14, height: 1.8),
              ),
            ),
          if (widget.copyableLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'برای کپی بیت از دکمهٔ کپی و برای واژه یا مصراع، متن را انتخاب کنید.',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.faint, fontSize: 10.5),
                ),
              ),
            ),
          if (widget.card.caption != null) ...[
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                widget.card.caption!,
                style: TextStyle(color: pal.faint, fontSize: 12.5),
              ),
            ),
          ],
          if (widget.relatedEntries.isNotEmpty) ...[
            const SizedBox(height: 14),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                'واژه‌های موجود در این بیت',
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.end,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in widget.relatedEntries)
                  GestureDetector(
                    onLongPress: () => _copyText(entry.ar, 'واژه کپی شد'),
                    child: ActionChip(
                      label: Text(entry.ar),
                      onPressed: widget.onOpenRelatedEntry == null
                          ? null
                          : () => widget.onOpenRelatedEntry!(entry),
                      backgroundColor: pal.pillC,
                      side: BorderSide(color: pal.div),
                      labelStyle: TextStyle(
                        color: pal.ink,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: Pressable(
                  onTap: () {
                    showModalBottomSheet<void>(
                      context: context,
                      backgroundColor: pal.bg,
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(26),
                        ),
                      ),
                      builder: (_) => _ShareSheet(card: widget.card),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: pal.sel,
                      borderRadius: BorderRadius.circular(capR(48)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(LucideIcons.share2, size: 18, color: pal.bg),
                        const SizedBox(width: 8),
                        Text(
                          'اشتراک‌گذاری',
                          style: TextStyle(
                            color: pal.bg,
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Pressable(
                onTap: () async {
                  final copyText = widget.copyableLines.isEmpty
                      ? buildShareText(widget.card)
                      : widget.copyableLines.join('\n');
                  await Clipboard.setData(ClipboardData(text: copyText));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          widget.copyableLines.isEmpty ? 'کپی شد' : 'بیت کپی شد',
                        ),
                      ),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    vertical: 14,
                    horizontal: 18,
                  ),
                  decoration: BoxDecoration(
                    color: pal.pillC,
                    borderRadius: BorderRadius.circular(capR(48)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.copy, size: 18, color: pal.ink),
                      const SizedBox(width: 8),
                      Text(
                        'کپی',
                        style: TextStyle(color: pal.ink, fontSize: 14.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          if (widget.etymologyWord != null)
            _RootInfoCard(word: widget.etymologyWord!),
          if (widget.relatedPersianWords.isNotEmpty)
            _PoemUsageCard(
              words: widget.relatedPersianWords,
              title: widget.relatedPoemTitle ?? 'شعرهایی که این واژه در آن‌ها آمده',
            ),
          if (widget.onOpenEtymology != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: pal.ink,
                  side: BorderSide(color: pal.div),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(capR(48)),
                  ),
                ),
                onPressed: widget.onOpenEtymology,
                icon: Icon(LucideIcons.gitBranch, size: 18, color: pal.sel),
                label: const Text('دیدن ریشه‌شناسی واژه'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The shareable image for a word or proverb: everything we know
/// about it, laid out as a card. Rendered inside a RepaintBoundary
/// and captured to PNG for sharing/saving.
class ShareCardImage extends StatelessWidget {
  final ShareCardData card;
  const ShareCardImage({super.key, required this.card});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(22, 24, 22, 20),
      decoration: BoxDecoration(
        color: pal.bg,
        borderRadius: BorderRadius.zero,
        border: Border.all(color: pal.div),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (card.isProfile) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: pal.sel, borderRadius: BorderRadius.circular(capR(52))),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 48, height: 48, decoration: BoxDecoration(color: pal.bg.withValues(alpha: .16), borderRadius: BorderRadius.circular(capR(48)), border: Border.all(color: pal.bg.withValues(alpha: .35))), child: Icon(LucideIcons.user, color: pal.bg, size: 25)),
                  const Spacer(),
                  Icon(LucideIcons.sparkles, color: pal.bg.withValues(alpha: .8), size: 20),
                ]),
                const SizedBox(height: 18),
                Text(card.title, style: TextStyle(color: pal.bg, fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(card.profileLevel ?? 'سطح آغازین', style: TextStyle(color: pal.bg.withValues(alpha: .8), fontSize: 13)),
                const SizedBox(height: 16),
                Text(faNum(card.profileScore ?? 0), style: TextStyle(color: pal.bg, fontSize: 38, fontWeight: FontWeight.w800)),
                Text('امتیاز کل', style: TextStyle(color: pal.bg.withValues(alpha: .78), fontSize: 12)),
              ]),
            ),
            const SizedBox(height: 16),
          ] else
            Text(
              card.title,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: pal.ink,
              height: 1.75,
            ),
          ),
          const SizedBox(height: 10),
          if (card.breadcrumb != null) ...[
            const SizedBox(height: 4),
            Text(
              card.breadcrumb!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12, color: pal.faint, height: 1.6),
            ),
          ],
          if (card.meaning != null) ...[
            const SizedBox(height: 8),
            Text(
              card.meaning!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 15, color: pal.muted, height: 1.8),
            ),
          ],
          for (final line in card.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 15, color: pal.muted, height: 1.8),
              ),
            ),
          if (card.caption != null) ...[
            const SizedBox(height: 8),
            Text(
              card.caption!,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(fontSize: 12.5, color: pal.faint),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: pal.div),
          const SizedBox(height: 10),
          Row(
            textDirection: TextDirection.rtl,
            children: [
              const SourenLogo(width: 34, animate: false),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  '، دیکشنری عربی به فارسی',
                  textDirection: TextDirection.rtl,
                  style: TextStyle(fontSize: 12, color: pal.muted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Share sheet: pick a format (text / image / text + image) and what
/// to do with it (share / save to phone / copy). The image format
/// shows a live preview of the card that will be shared.
class _ShareSheet extends StatefulWidget {
  final ShareCardData card;
  const _ShareSheet({required this.card});
  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  ShareFormat _format = ShareFormat.image;
  final _cardKey = GlobalKey();
  bool _busy = false;

  Future<Uint8List?> _capturePng() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }

  String _doneMessage(ShareAction action) => switch (action) {
    ShareAction.share => 'فرستاده شد',
    ShareAction.save => 'در گوشی ذخیره شد',
    ShareAction.copy => 'کپی شد',
  };

  Future<void> _run(ShareAction action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final text = buildShareText(widget.card);
      Uint8List? png;
      if (_format != ShareFormat.text) {
        // Let the preview paint once before capturing it.
        await Future.delayed(const Duration(milliseconds: 60));
        png = await _capturePng();
      }
      final name = 'souren-${DateTime.now().millisecondsSinceEpoch}.png';
      var ok = false;
      switch ((_format, action)) {
        case (ShareFormat.text, ShareAction.share):
          ok = await ShareService.shareText(text);
        case (ShareFormat.text, ShareAction.save):
          ok = await ShareService.saveText(
            text,
            name.replaceAll('.png', '.txt'),
          );
        case (ShareFormat.text, ShareAction.copy):
          await Clipboard.setData(ClipboardData(text: text));
          ok = true;
        case (ShareFormat.image, ShareAction.share):
          ok = png != null && await ShareService.shareImage(png, name);
        case (ShareFormat.image, ShareAction.save):
          ok = png != null && await ShareService.saveImage(png, name);
        case (ShareFormat.image, ShareAction.copy):
          // Images cannot go on the clipboard: save to the gallery.
          ok = png != null && await ShareService.saveImage(png, name);
        case (ShareFormat.textAndImage, ShareAction.share):
          ok =
              png != null &&
              await ShareService.shareTextAndImage(text, png, name);
        case (ShareFormat.textAndImage, ShareAction.save):
          ok = png != null && await ShareService.saveImage(png, name);
        case (ShareFormat.textAndImage, ShareAction.copy):
          await Clipboard.setData(ClipboardData(text: text));
          ok = true;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? _doneMessage(action) : 'انجام نشد؛ دوباره تلاش کنید',
          ),
        ),
      );
      if (ok) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(26, 12, 26, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: pal.muted.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(capR(7)),
            ),
          ),
          const SizedBox(height: 18),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              'اشتراک‌گذاری',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: pal.ink,
              ),
            ),
          ),
          const SizedBox(height: 14),
          capsuleGroup<ShareFormat>(
            options: const [
              (ShareFormat.text, 'متن'),
              (ShareFormat.image, 'عکس'),
              (ShareFormat.textAndImage, 'متن و عکس'),
            ],
            value: _format,
            onChanged: (v) => setState(() => _format = v),
          ),
          if (_format != ShareFormat.text) ...[
            const SizedBox(height: 16),
            RepaintBoundary(
              key: _cardKey,
              child: ShareCardImage(card: widget.card),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _shareActionButton(
                  'اشتراک‌گذاری',
                  LucideIcons.share2,
                  filled: true,
                  onTap: () => _run(ShareAction.share),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _shareActionButton(
                  'ذخیره در گوشی',
                  LucideIcons.download,
                  onTap: () => _run(ShareAction.save),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _shareActionButton(
                  'کپی',
                  LucideIcons.copy,
                  onTap: () => _run(ShareAction.copy),
                ),
              ),
            ],
          ),
          if (_busy) ...[
            const SizedBox(height: 14),
            const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ],
      ),
    );
  }

  Widget _shareActionButton(
    String label,
    IconData icon, {
    bool filled = false,
    required VoidCallback onTap,
  }) {
    return Pressable(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 13),
        decoration: BoxDecoration(
          color: filled ? pal.sel : pal.pillC,
          borderRadius: BorderRadius.circular(capR(46)),
        ),
        child: Column(
          children: [
            Icon(icon, size: 19, color: filled ? pal.bg : pal.ink),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: filled ? pal.bg : pal.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Custom capsule segmented control (replaces Material SegmentedButton):
/// one pill container; the selected option is a capsule of its own.
/// Used by the settings page and the share sheet.
Widget capsuleGroup<T>({
  required List<(T, String)> options,
  required T value,
  required ValueChanged<T> onChanged,
}) {
  return Container(
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: pal.cardC,
      borderRadius: BorderRadius.circular(capR(56)),
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
                  borderRadius: BorderRadius.circular(capR(48)),
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

/// Category display metadata: id -> (icon, Persian title).
const catMeta = <String, (IconData, String)>{
  'health': (LucideIcons.activity, 'پزشکی و تندرستی'),
  'work': (LucideIcons.briefcase, 'پیشه و کار'),
  'money': (LucideIcons.wallet, 'پول و بازار'),
  'edu': (LucideIcons.award, 'آموزش و دانش'),
  'lang': (LucideIcons.messageSquare, 'سخن و نوشتار'),
  'home': (LucideIcons.house, 'خانه و خانواده'),
  'nature': (LucideIcons.sun, 'طبیعت و گیتی'),
  'faith': (LucideIcons.moon, 'باور و آیین'),
  'state': (LucideIcons.building2, 'کشور و داد'),
  'mind': (LucideIcons.zap, 'دل و اندیشه'),
  'time': (LucideIcons.clock, 'زمان و سنجش'),
  'travel': (LucideIcons.compass, 'سفر و جابه‌جایی'),
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


class ArioLessonPage extends StatefulWidget {
  final int lesson;
  final List<Entry> words;
  final Future<void> Function() onComplete;
  const ArioLessonPage({super.key, required this.lesson, required this.words, required this.onComplete});
  @override
  State<ArioLessonPage> createState() => _ArioLessonPageState();
}

class _ArioLessonPageState extends State<ArioLessonPage> {
  int index = 0;
  bool revealed = false;

  @override
  Widget build(BuildContext context) {
    final entry = widget.words[index];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(child: Padding(padding: const EdgeInsets.fromLTRB(22, 12, 22, 24), child: Column(children: [
        Row(children: [
          Pressable(onTap: () => Navigator.of(context).pop(), child: Icon(LucideIcons.arrowRight, color: pal.ink, size: 24)),
          const SizedBox(width: 12),
          Expanded(child: Text('درس ${faNum(widget.lesson)}', style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700, fontSize: 18))),
          Text('${faNum(index + 1)} از ${faNum(widget.words.length)}', style: TextStyle(color: pal.muted, fontSize: 12)),
        ]),
        const SizedBox(height: 14),
        ClipRRect(borderRadius: BorderRadius.circular(capR(18)), child: LinearProgressIndicator(value: (index + (revealed ? 1 : 0)) / widget.words.length, minHeight: 7, backgroundColor: pal.div, color: pal.sel)),
        const Spacer(),
        AnimatedSwitcher(duration: Motion.base, switchInCurve: Motion.curve, child: Container(
          key: ValueKey('${index}_${revealed}'),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 36),
          decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(58))),
          child: Column(children: [
            Text('واژهٔ عربی', style: TextStyle(color: pal.muted, fontSize: 13)),
            const SizedBox(height: 14),
            Text(entry.ar, style: TextStyle(color: pal.ink, fontSize: 36, fontWeight: FontWeight.w800)),
            const SizedBox(height: 20),
            AnimatedSize(duration: Motion.base, curve: Motion.curve, child: revealed
              ? Column(children: [
                  Divider(color: pal.div),
                  const SizedBox(height: 12),
                  Text('برابر فارسی', style: TextStyle(color: pal.muted, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(entry.fa.join('، '), textAlign: TextAlign.center, style: TextStyle(color: pal.sel, fontSize: 20, fontWeight: FontWeight.w700, height: 1.6)),
                ])
              : Text('پیش از دیدن پاسخ، خودت معنی واژه را به یاد بیاور.', textAlign: TextAlign.center, style: TextStyle(color: pal.muted, height: 1.7))),
          ]),
        )),
        const Spacer(),
        SizedBox(width: double.infinity, child: FilledButton(onPressed: () async {
          if (!revealed) {
            setState(() => revealed = true);
          } else if (index + 1 < widget.words.length) {
            setState(() { index++; revealed = false; });
          } else {
            await widget.onComplete();
            if (context.mounted) Navigator.of(context).pop();
          }
        }, child: Text(!revealed ? 'نمایش پاسخ' : index + 1 < widget.words.length ? 'واژهٔ بعدی' : 'پایان درس'))),
      ]))),
    ));
  }
}

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
        fontFamily: 'Abar',
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
                  body: Center(child: SourenLogo(width: 190)),
                ),
              ),
      ),
    );
  }
}

/// The complete official Souren wordmark, revealed as a filled silhouette.
class SourenLogo extends StatefulWidget {
  final double width;
  final bool animate;
  final Color? color;
  const SourenLogo({
    super.key,
    required this.width,
    this.animate = true,
    this.color,
  });

  @override
  State<SourenLogo> createState() => _SourenLogoState();
}

class _SourenLogoState extends State<SourenLogo>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const ratio = 980.05 / 291.68;
    final height = widget.width / ratio;
    return SizedBox(
      width: widget.width,
      height: height,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          painter: _SourenLogoPainter(
            progress: widget.animate
                ? Curves.easeInOutCubic.transform(_controller.value)
                : 1.0,
            color: widget.color ?? pal.ink,
          ),
        ),
      ),
    );
  }
}

class _SourenLogoPainter extends CustomPainter {
  final double progress;
  final Color color;
  _SourenLogoPainter({required this.progress, required this.color});

  static const Size _viewBox = Size(980.05, 291.68);
  static final List<Path> _paths = [
    parseSvgPathData(
      'M932.05,27.17v96.3c0,13.24-10.77,24-24,24h-11.67c-13.23,0-24-10.76-24-24V51.22h-48v72.25c0,13.24-10.76,24-24,24h-12.79c-13.24,0-24-10.76-24-24V36.44h-48v72.99c-23.25,12.09-83.09,38.04-168.41,38.04h-.05V57.91c0-14.89-6.73-28.68-18.46-37.84-11.73-9.16-26.74-12.34-41.19-8.73l-29.94,7.49c-32.16,8.03-54.62,36.8-54.62,69.94v58.7c0,26.47,21.53,48,48,48h48.21v31.71c-.16.33-.44.73-.68,1-15.06,5.91-43.77,15.5-71.53,15.5v48c34.33,0,67.81-10.41,89.85-19.13,17.59-6.96,30.36-25.74,30.36-44.64v-32.44h.05c82.82,0,144.23-21.58,177.52-36.98,12.32,22.04,35.89,36.98,62.89,36.98h12.79c18.42,0,35.25-6.95,48-18.38,12.75,11.43,29.58,18.38,48,18.38h11.67c39.7,0,72-32.3,72-72V27.17h-48ZM499.13,147.47h-48.21v-58.7c0-11.08,7.51-20.69,18.26-23.38l29.95-7.48v89.56Z',
    ),
    parseSvgPathData(
      'M268.56,290.86v-48c28.17,0,57.32-9.87,72.19-15.76l.02-200.75h48v200.74c0,19.82-11.91,37.34-30.35,44.64-22.05,8.73-55.53,19.13-89.85,19.13Z',
    ),
    parseSvgPathData(
      'M144.26,290.86h-24.05c-21.45,0-45.04-4.06-70.11-12.08C20.13,269.21,0,241.64,0,210.19V51.22h48v158.98c0,10.48,6.71,19.67,16.71,22.87,20.06,6.41,39.25,9.8,55.5,9.8h24.05c16.25,0,35.44-3.39,55.5-9.8,9.99-3.19,16.71-12.38,16.71-22.87V26.35h48v183.85c0,31.45-20.13,59.01-50.09,68.59-25.07,8.01-48.66,12.08-70.11,12.08Z',
    ),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / _viewBox.width, size.height / _viewBox.height);
    final reveal = progress.clamp(0.0, 1.0);
    canvas.clipRect(Rect.fromLTWH(
      _viewBox.width * (1 - reveal),
      0,
      _viewBox.width * reveal,
      _viewBox.height,
    ));
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;
    for (final path in _paths) {
      canvas.drawPath(path, paint);
    }
    canvas.drawRect(
      const Rect.fromLTWH(108.18, 0, 48.1, 48.1),
      paint,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _SourenLogoPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// Soft fade + gentle rise, staggered by [index] for list items only.
/// Tab switches are intentionally immediate; only the home search expansion
/// keeps its spring animation.
class Enter extends StatelessWidget {
  final int index;
  final Widget child;
  const Enter({super.key, required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.base + Duration(milliseconds: (index % 10) * 22),
      curve: Motion.curve,
      builder: (_, v, c) => Opacity(
        opacity: v,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - v)),
          child: Transform.scale(scale: 0.99 + (0.01 * v), child: c),
        ),
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
  List<(String, String)> proverbs = const [];
  Categories categories = const Categories({});
  int learnedWords = 0;
  int learnedCorrections = 0;
  int tab = 0;
  // Geometry tracking for the original v0.4.1 expanding navigation bar.
  final List<GlobalKey> _tabKeys = List.generate(6, (_) => GlobalKey());
  final GlobalKey _navStackKey = GlobalKey();
  double _indLeft = 0;
  double _indWidth = 0;
  String query = '';
  int _homeCollection = 0; // words, proverbs, poets, books
  Future<List<Map<String, dynamic>>>? _homePoets;
  Future<List<Map<String, dynamic>>>? _homePoems;
  Future<List<Map<String, dynamic>>>? _homeBooks;
  Future<List<Map<String, dynamic>>>? _savedBookCatalog;
  int _metricIndex = 0;
  int _likedFilter = 0; // words, proverbs, poems, books, roots
  int _favoritesFilter = 0; // words, proverbs, poems, books, roots

  // Search focus state (home): the word column expands and the back control appears.
  final _searchCtl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searchFocused = false;

  bool arioEnabled = false;
  bool dbSyncing = false;
  bool arioMode = false;
  bool ganjoorPackInstalled = false;
  bool ganjoorPackBusy = false;
  int ganjoorPackReceived = 0;
  int ganjoorPackTotal = 0;
  final Set<int> arioCompletedLessons = {};
  final Set<String> arioKnownWords = {};
  int arioLastLesson = 0;
  int arioQuizIndex = 0;
  String? arioSelectedAnswer;
  bool? arioAnswerCorrect;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() {
      if (mounted) setState(() => _searchFocused = _searchFocus.hasFocus);
    });
    _load();
    _loadArioState();
    _loadGanjoorPackState();
    SharedFiles.setArioLaunchHandler(() {
      _searchFocus.unfocus();
      if (mounted) setState(() { arioMode = true; tab = 0; });
    });
    SharedFiles.consumeArioLaunch().then((open) {
      if (open && mounted) {
        _searchFocus.unfocus();
        setState(() { arioMode = true; tab = 0; });
      }
    });
  }

  Future<void> _loadArioState() async {
    final enabled = await SharedFiles.isArioLauncherEnabled();
    if (mounted) setState(() => arioEnabled = enabled);
  }

  Future<void> _setArioState(bool value) async {
    try {
      final enabled = await SharedFiles.setArioLauncherEnabled(value);
      if (mounted) setState(() => arioEnabled = enabled);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تغییر وضعیت Ario انجام نشد')),
      );
    }
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final d = await Dictionary.load();
    final s = await SettingsStore.ensureLoaded();
    final cats = await Categories.load();
    final loadedProverbs = await Proverbs.load();
    final fav = await SharedFiles.readJson('favorites.json');
    final lk = await SharedFiles.readJson('liked.json');
    final learned = await SharedFiles.readJson('learned.json');
    final ario = await SharedFiles.readJson('ario_learning.json');
    setState(() {
      dict = d;
      settings = s;
      categories = cats;
      proverbs = loadedProverbs;
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
      if (ario != null) {
        arioCompletedLessons..clear()..addAll(((ario['completedLessons'] as List?) ?? []).map((e) => (e as num).toInt()));
        arioKnownWords..clear()..addAll(((ario['knownWords'] as List?) ?? []).map((e) => e.toString()));
        arioLastLesson = (ario['lastLesson'] as num?)?.toInt() ?? 0;
        arioQuizIndex = (ario['quizIndex'] as num?)?.toInt() ?? 0;
      }
    });
    _syncDictionary(d);
  }

  bool _dictSyncDone = false;
  Future<void> _syncDictionary(Dictionary current) async {
    if (_dictSyncDone) return;
    _dictSyncDone = true;
    final updated = await DictionarySync.syncFromServer(current);
    if (updated && mounted) {
      final refreshed = await Dictionary.load();
      setState(() => dict = refreshed);
    }
  }

  Future<void> _toggleFav(String word) async {
    setState(() {
      favorites.contains(word) ? favorites.remove(word) : favorites.add(word);
    });
    await SharedFiles.writeJson('favorites.json', {
      'words': favorites.toList(),
    });
  }

  Future<void> _toggleLike(String word) async {
    setState(() {
      liked.contains(word) ? liked.remove(word) : liked.add(word);
    });
    await SharedFiles.writeJson('liked.json', {'words': liked.toList()});
  }

  void _go(int i) => setState(() => tab = i);

  @override
  Widget build(BuildContext context) {
    final d = dict;
    if (d == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final pages = arioMode
        ? <Widget>[_arioHome(d), _arioPath(d), _arioPractice(d), _arioReview(d), _arioWords(d), _arioProgress(d)]
        : <Widget>[_home(d), _likedPage(d), _sectionsPage(d), _favoritesPage(d), _profilePage(d), _settingsPage(d)];
    return Scaffold(
      extendBody: true,
      body: SafeArea(
        top: true,
        bottom: false,
        child: KeyedSubtree(
          key: ValueKey(
            '${tab}_${settings.direction}_${settings.textSize}',
          ),
          child: pages[tab],
        ),
      ),
      bottomNavigationBar: _searchFocused && !arioMode
          ? const SizedBox.shrink()
          : Container(
              color: Colors.transparent,
              child: _navBar(),
            ),
    );
  }

  /// Original v0.4.1 navigation structure: the active item expands,
  /// its label is revealed, and one capsule slides behind the active item.
  /// The surface is solid; the measured capsule is clipped to the nav row
  /// to prevent the lower-edge paint protrusion from the previous version.
  void _measureIndicator() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final stackBox =
          _navStackKey.currentContext?.findRenderObject() as RenderBox?;
      final tabBox =
          _tabKeys[tab].currentContext?.findRenderObject() as RenderBox?;
      if (stackBox == null || tabBox == null || !stackBox.hasSize || !tabBox.hasSize) {
        return;
      }
      final pos = tabBox.localToGlobal(Offset.zero, ancestor: stackBox);
      // A one-logical-pixel inset keeps antialiased edges inside the measured
      // tab bounds and prevents the indicator from hanging below the capsule.
      final left = (pos.dx + 1).clamp(0.0, stackBox.size.width).toDouble();
      final right = (pos.dx + tabBox.size.width - 1)
          .clamp(left, stackBox.size.width)
          .toDouble();
      final width = right - left;
      if ((left - _indLeft).abs() > .5 ||
          (width - _indWidth).abs() > .5) {
        setState(() {
          _indLeft = left;
          _indWidth = width;
        });
      }
    });
  }

  Widget _navBar() {
    final items = arioMode
        ? <(IconData, String)>[
            (Symbols.home_rounded, 'خانه'),
            (Symbols.grid_view_rounded, 'مسیر'),
            (Symbols.favorite_rounded, 'تمرین'),
            (Symbols.bookmark_rounded, 'مرور'),
            (Symbols.person_rounded, 'واژه‌ها'),
            (Symbols.settings_rounded, 'پیشرفت'),
          ]
        : <(IconData, String)>[
            (Symbols.home_rounded, 'پیشگاه'),
            (Symbols.favorite_rounded, 'پسندیده‌ها'),
            (Symbols.grid_view_rounded, 'بخش‌ها'),
            (Symbols.bookmark_rounded, 'نشان‌شده'),
            (Symbols.person_rounded, 'نمایه'),
            (Symbols.settings_rounded, 'پیکربندی'),
          ];

    Widget navItem(int i) => GestureDetector(
      key: _tabKeys[i],
      behavior: HitTestBehavior.opaque,
      onTap: () => _go(i),
      child: AnimatedContainer(
        duration: Motion.base,
        curve: Motion.curve,
        padding: EdgeInsets.symmetric(
          horizontal: tab == i ? 17 : 12,
          vertical: 14,
        ),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(capR(45)),
        ),
        child: AnimatedSize(
          duration: Motion.base,
          curve: Motion.curve,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: Motion.fast,
                switchInCurve: Motion.curve,
                switchOutCurve: Motion.curve,
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: 0.8, end: 1).animate(anim),
                    child: child,
                  ),
                ),
                child: Icon(
                  key: ValueKey<bool>(tab == i),
                  items[i].$1,
                  size: 23,
                  fill: tab == i ? 1 : 0,
                  weight: tab == i ? 600 : 400,
                  color: tab == i
                      ? pal.bg
                      : pal.ink.withValues(alpha: .72),
                ),
              ),
              if (tab == i)
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: Motion.base,
                  curve: Motion.curve,
                  builder: (_, v, c) => Opacity(opacity: v, child: c),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    _measureIndicator();
    final selSoft = Color.lerp(pal.sel, pal.bg, 0.38)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 6, 22, 14),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(capR(63)),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: pal.cardC,
            borderRadius: BorderRadius.circular(capR(63)),
            border: Border.all(color: pal.div.withValues(alpha: 0.6)),
          ),
          child: Stack(
            key: _navStackKey,
            clipBehavior: Clip.hardEdge,
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                left: _indLeft,
                top: 0,
                bottom: 0,
                width: _indWidth,
                child: Center(
                  child: SizedBox(
                    height: 44,
                    width: double.infinity,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(capR(42)),
                      child: ColoredBox(color: selSoft),
                    ),
                  ),
                ),
              ),
              Row(
                children: [
                  // Edge actions stay anchored; only the middle four redistribute.
                  navItem(0),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        navItem(1),
                        navItem(2),
                        navItem(3),
                        navItem(4),
                      ],
                    ),
                  ),
                  navItem(5),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------- پیشگاه ----------
  Widget _home(Dictionary d) {
    final frequent = d.entries.where((e) => e.hasFa).toList();
    final results = query.isEmpty
        ? frequent
        : d.entries
            .where(
              (e) =>
                  e.ar.contains(query) || e.fa.any((f) => f.contains(query)),
            )
            .toList();

    return LayoutBuilder(
      builder: (context, constraints) {
        const logoGap = 116.0;
        const searchH = 58.0;
        const gapAfterSearch = 18.0;
        const searchLift = searchH * 1.5;
        // Keep the logo's original position; only the search and home content
        // move down by half the search capsule's height.
        const logoBottom = logoGap + searchH - searchLift;
        const searchTop = logoBottom + searchH * 0.5;
        const contentTop = searchTop + searchH + gapAfterSearch;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: contentTop),
                  Expanded(
                    child: Padding(
                      // End the home viewport above the floating nav bar.
                      padding: EdgeInsets.only(bottom: _searchFocused ? 0 : kNavClearance),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: Padding(
                              // Keep the list just a little shorter than the action column;
                              // in search mode let it use the full screen height.
                              padding: EdgeInsets.only(bottom: _searchFocused ? 0 : 5),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  _homeCollectionHeader(),
                                  const SizedBox(height: 6),
                                  Expanded(
                                    child: KeyedSubtree(
                                      key: ValueKey(
                                        'home-$_homeCollection-$_searchFocused',
                                      ),
                                      child: _homeCollectionView(d, results),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          AnimatedContainer(
                            duration: Motion.slow,
                            curve: Motion.spring,
                            width: _searchFocused ? 0 : 16,
                          ),
                          AnimatedContainer(
                            duration: Motion.slow,
                            curve: Motion.spring,
                            width: _searchFocused ? 0 : 124,
                            child: ClipRect(
                              child: AnimatedOpacity(
                                opacity: _searchFocused ? 0 : 1,
                                duration: Motion.fast,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  alignment: Alignment.topCenter,
                                  child: SizedBox(
                                    width: 124,
                                    child: Column(
                                      children: [
                                        _sidePill(
                                          'گنجینهٔ واژه‌ها',
                                          () => _open(
                                            LexiconPage(
                                              dict: d,
                                              onTapEntry: _showEntry,
                                            ),
                                          ),
                                        ),
                                        _sidePill(
                                          'درست‌نویسی',
                                          () => _open(CorrectorPage(dict: d)),
                                        ),
                                        _sidePill(
                                          'پندواژه',
                                          () => _open(_pandvazhePage(d)),
                                        ),
                                        _sidePill(
                                          'واژه‌های تازه',
                                          () => _open(_freshPage(d)),
                                        ),
                                        _sidePill(
                                          'واژهٔ روز',
                                          () => _pushPage(_dailyPage(d)),
                                        ),
                                        _sidePill(
                                          'کتابخانهٔ شعر',
                                          () => _open(_ganjoorPage(d)),
                                        ),
                                        _sidePill(
                                          'ریشه‌شناسی',
                                          () => _open(EtymologyPage(
                                            dict: d,
                                            liked: liked,
                                            favorites: favorites,
                                            onToggleLike: _toggleLike,
                                            onToggleBookmark: _toggleFav,
                                          )),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 118,
                                          child: _homeMetrics(d),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          )
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: logoBottom,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: SourenLogo(
                      width: 112,
                      animate: false,
                      color: pal.sel,
                    ),
                  ),
                ),
              ),
              Positioned(
                top: searchTop,
                left: 0,
                right: 0,
                child: _searchCapsule(),
              ),
              Positioned(
                top: 20,
                right: 0,
                child: AnimatedSwitcher(
                  duration: Motion.fast,
                  transitionBuilder: (child, anim) => FadeTransition(
                    opacity: anim,
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.82, end: 1).animate(anim),
                      child: child,
                    ),
                  ),
                  child: _searchFocused
                      ? IconButton(
                          key: const ValueKey('back'),
                          icon: Icon(
                            LucideIcons.arrowLeft,
                            color: pal.ink,
                            size: 24,
                          ),
                          onPressed: () => _searchFocus.unfocus(),
                        )
                      : const SizedBox.shrink(key: ValueKey('none')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _homeCollectionHeader() {
    const labels = [
      'گنجینۀ واژه‌ها',
      'گنجینۀ پندواژه‌ها',
      'گنجینۀ شاعران',
      'گنجینۀ کتاب‌ها',
    ];
    const icons = <IconData>[
      Symbols.translate_rounded,
      Symbols.format_quote_rounded,
      Symbols.person_rounded,
      Symbols.menu_book_rounded,
    ];
    return MenuAnchor(
      alignmentOffset: const Offset(0, 8),
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll(pal.cardC),
        elevation: const WidgetStatePropertyAll(12),
        padding: const WidgetStatePropertyAll(EdgeInsets.all(8)),
        shape: WidgetStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(capR(54)),
            side: BorderSide(color: pal.div),
          ),
        ),
      ),
      menuChildren: [
        for (var i = 0; i < labels.length; i++)
          MenuItemButton(
            onPressed: () {
              setState(() {
                _homeCollection = i;
                if (i == 2) {
                  _homePoets = _loadHomePoets();
                } else if (i == 3) {
                  _homeBooks = GanjoorData.bookCatalog();
                }
              });
            },
            style: ButtonStyle(
              minimumSize: const WidgetStatePropertyAll(Size(190, 48)),
              padding: const WidgetStatePropertyAll(
                EdgeInsets.symmetric(horizontal: 12),
              ),
              backgroundColor: WidgetStatePropertyAll(
                i == _homeCollection ? pal.pillC : Colors.transparent,
              ),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(capR(46)),
                ),
              ),
            ),
            child: SizedBox(
              width: 190,
              height: 48,
              child: Row(
                textDirection: TextDirection.rtl,
                children: [
                  Icon(
                    icons[i],
                    size: 19,
                    color: i == _homeCollection ? pal.sel : pal.muted,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      labels[i],
                      textDirection: TextDirection.rtl,
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: i == _homeCollection ? pal.ink : pal.muted,
                        fontSize: 13.5,
                        fontWeight: i == _homeCollection
                            ? FontWeight.w800
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                  if (i == _homeCollection) ...[
                    const SizedBox(width: 8),
                    Icon(Symbols.check_rounded, size: 18, color: pal.sel),
                  ],
                ],
              ),
            ),
          ),
      ],
      builder: (context, controller, child) => Pressable(
        onTap: () => controller.isOpen ? controller.close() : controller.open(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Expanded(
                child: Text(
                  labels[_homeCollection.clamp(0, labels.length - 1).toInt()],
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    color: pal.ink,
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              AnimatedRotation(
                turns: controller.isOpen ? 0.5 : 0,
                duration: Motion.fast,
                curve: Motion.curve,
                child: Icon(
                  Symbols.expand_more_rounded,
                  size: 20,
                  color: pal.muted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadHomePoets() async {
    final manifest = await GanjoorData.json('manifest.json');
    return GanjoorData.rows(manifest['Poets'] ?? manifest['poets']);
  }

  Widget _homeEntityList(
    Future<List<Map<String, dynamic>>> future, {
    required bool poets,
  }) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return _ganjoorError(
            'بارگذاری این گنجینه انجام نشد.',
            () => setState(() {
              if (poets) {
                _homePoets = _loadHomePoets();
              } else {
                _homeBooks = GanjoorData.bookCatalog();
              }
            }),
          );
        }
        final rows = (snapshot.data ?? const <Map<String, dynamic>>[])
            .where((row) {
          final title = (row['Nickname'] ?? row['Title'] ?? row['Name'] ??
                  row['nickname'] ?? row['title'] ?? row['name'] ?? '')
              .toString();
          final subtitle = (row['Name'] ?? row['PoetName'] ??
                  row['PoetNickname'] ?? row['name'] ?? '')
              .toString();
          return query.isEmpty || title.contains(query) || subtitle.contains(query);
        }).toList(growable: false);
        if (rows.isEmpty) {
          return Center(
            child: Text(
              poets ? 'شاعری پیدا نشد' : 'کتابی پیدا نشد',
              style: TextStyle(color: pal.muted),
            ),
          );
        }
        return edgeFade(
                    fadeExtent: 0.22,
          fadeStrength: 0.94,
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            itemCount: rows.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
            itemBuilder: (_, i) {
              final row = rows[i];
              String value(List<String> keys) {
                for (final key in keys) {
                  final v = row[key];
                  if (v != null && v.toString().trim().isNotEmpty) {
                    return v.toString();
                  }
                }
                return '';
              }
              final title = value(
                poets
                    ? ['Nickname', 'nickname', 'Name', 'name']
                    : ['Title', 'title', 'Name', 'name'],
              );
              final subtitle = value(
                poets
                    ? ['Name', 'name']
                    : ['PoetName', 'PoetNickname', 'poetName'],
              );
              final full = value(['FullUrl', 'fullUrl', 'Url', 'url'])
                  .replaceFirst(RegExp(r'^/'), '');
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: Icon(
                  poets ? LucideIcons.user : LucideIcons.notebookPen,
                  color: pal.sel,
                ),
                title: Text(
                  title.isEmpty ? (poets ? 'شاعر' : 'کتاب') : title,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  subtitle,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.muted, fontSize: 11.5),
                ),
                trailing: Icon(LucideIcons.chevronLeft, size: 17, color: pal.muted),
                onTap: full.isEmpty
                    ? null
                    : () => _open(GanjoorNodePage(
                          title: title,
                          path: full,
                          depth: poets ? 0 : 1,
                          dictionary: dict,
                          liked: liked,
                          favorites: favorites,
                          onToggleLike: _toggleLike,
                          onToggleBookmark: _toggleFav,
                          onOpenEntry: _showEntry,
                        )),
              );
            },
          ),
        );
      },
    );
  }

  Widget _homeCollectionView(Dictionary d, List<Entry> wordResults) {
    if (_homeCollection == 0) {
      return _pairList(
        wordResults,
        bottomPad: 0,
        singleLine: true,
      );
    }
    if (_homeCollection == 1) {
      final rows = proverbs.where((item) =>
        query.isEmpty || item.$1.contains(query) || item.$2.contains(query)
      ).toList();
      if (rows.isEmpty) {
        return Center(
          child: Text('پندواژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)),
        );
      }
      return edgeFade(
                fadeExtent: 0.22,
        fadeStrength: 0.94,
        child: ListView.separated(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: rows.length,
          separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
          itemBuilder: (_, i) => InkWell(
            onTap: () => _showProverb(rows[i].$1, rows[i].$2),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(rows[i].$1,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700, fontSize: 15)),
                  const SizedBox(height: 4),
                  Text(rows[i].$2,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pal.muted, fontSize: 12.5)),
                ],
              ),
            ),
          ),
        ),
      );
    }
    if (_homeCollection == 2) {
      return _homeEntityList(_homePoets ??= _loadHomePoets(), poets: true);
    }
    if (_homeCollection == 3) {
      return _homeEntityList(_homeBooks ??= GanjoorData.bookCatalog(), poets: false);
    }
    final future = _homePoems ??= query.isEmpty
        ? GanjoorData.searchPoemsForTerms(['عشق', 'دل', 'زندگی'])
        : GanjoorData.searchPoems(query);
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final poems = snapshot.data ?? const <Map<String, dynamic>>[];
        if (poems.isEmpty) {
          return Center(
            child: Text('شعری پیدا نشد', style: TextStyle(color: pal.muted)),
          );
        }
        return edgeFade(
                    fadeExtent: 0.22,
          fadeStrength: 0.94,
          child: ListView.separated(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            itemCount: poems.length,
            separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
            itemBuilder: (_, i) {
              final poem = poems[i];
              String value(List<String> keys) {
                for (final key in keys) {
                  final v = poem[key];
                  if (v != null && v.toString().trim().isNotEmpty) return v.toString();
                }
                return '';
              }
              final title = value(['Title', 'title']).isEmpty ? 'شعر' : value(['Title', 'title']);
              final poet = value(['PoetName', 'PoetNickname', 'poetName']);
              final full = value(['FullUrl', 'fullUrl', 'Url', 'url']).replaceFirst(RegExp(r'^/'), '');
              return ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                title: Text(title, textAlign: TextAlign.right,
                    style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)),
                subtitle: Text(poet, textAlign: TextAlign.right,
                    style: TextStyle(color: pal.muted, fontSize: 11.5)),
                trailing: Icon(LucideIcons.chevronLeft, size: 17, color: pal.muted),
                onTap: full.isEmpty ? null : () => _open(GanjoorPoemPage(
                  title: title,
                  path: 'poets/$full.json',
                  dictionary: d,
                  liked: liked,
                  favorites: favorites,
                  onToggleLike: _toggleLike,
                  onToggleBookmark: _toggleFav,
                  onOpenEntry: _showEntry,
                )),
              );
            },
          ),
        );
      },
    );
  }

  Widget _searchCapsule() {
    return SizedBox(
      height: 58,
      child: TextField(
        scrollPadding: EdgeInsets.zero,
        controller: _searchCtl,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() {
          query = v.trim();
          _homePoems = null;
        }),
        decoration: InputDecoration(
          hintText: const [
            'واژه‌ای را جستجو کنید',
            'پندواژه‌ای را جستجو کنید',
            'نام شاعری را جستجو کنید',
            'نام کتابی را جستجو کنید',
          ][ _homeCollection.clamp(0, 3).toInt()],
          hintStyle: TextStyle(color: pal.muted, fontSize: 14.5),
          prefixIcon: Transform.translate(
            offset: const Offset(-4, 0),
            child: Icon(LucideIcons.search, color: pal.muted, size: 20),
          ),
          filled: true,
          fillColor: pal.cardC,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(capR(58)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(capR(58)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(capR(58)),
            borderSide: BorderSide.none,
          ),
          disabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(capR(58)),
            borderSide: BorderSide.none,
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(capR(58)),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _homeMetrics(Dictionary d) {
    return SizedBox(
      width: 124,
      child: FutureBuilder<Map<String, int>>(
        future: GanjoorData.stats(),
        builder: (context, snapshot) {
          // Show the last published corpus totals while remote stats load.
          // Never flash a misleading zero for the poem count.
          final stats = snapshot.data ?? GanjoorData.fallbackStats;
          final values = <(String, int)>[
            ('واژه', d.entries.length),
            ('برابر', d.pairCount),
            ('پندواژه', proverbs.length),
            ('شاعر', stats['poets'] ?? 0),
            ('کتاب', stats['books'] ?? 0),
            ('شعر', stats['poems'] ?? 0),
            ('ریشه', PersianRoots.index(d).length),
            ('دسته', catOrder.length),
          ];
          final selected = _metricIndex % values.length;
          final item = values[selected];
          void step(int delta) => setState(() {
            _metricIndex =
                (_metricIndex + delta + values.length) % values.length;
          });
          return Pressable(
            onTap: () => step(1),
            child: GestureDetector(
              onHorizontalDragEnd: (details) {
                final velocity = details.primaryVelocity ?? 0;
                if (velocity.abs() < 80) return;
                step(velocity < 0 ? -1 : 1);
              },
              child: Container(
                width: double.infinity,
                height: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: pal.cardC,
                  borderRadius: BorderRadius.circular(capR(68)),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: Motion.base,
                          switchInCurve: Motion.curve,
                          switchOutCurve: Curves.easeInCubic,
                          transitionBuilder: (child, animation) => FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: Tween<Offset>(
                                begin: const Offset(0, 0.16),
                                end: Offset.zero,
                              ).animate(animation),
                              child: ScaleTransition(
                                scale: Tween<double>(begin: 0.92, end: 1).animate(animation),
                                child: child,
                              ),
                            ),
                          ),
                          child: FittedBox(
                            key: ValueKey(item.$2),
                            fit: BoxFit.scaleDown,
                            child: Text(
                              faNum(item.$2),
                              textDirection: TextDirection.ltr,
                              style: TextStyle(
                                color: pal.ink,
                                fontSize: 27,
                                fontWeight: FontWeight.w800,
                                height: 1.05,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      flex: 1,
                      child: Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection: TextDirection.rtl,
                          children: [
                            Flexible(
                              child: Text(
                                item.$1,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: pal.muted,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                for (var i = 0; i < values.length; i++)
                                  AnimatedContainer(
                                    duration: Motion.base,
                                    curve: Motion.spring,
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 1.5,
                                    ),
                                    width: i == selected ? 8 : 3,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: i == selected
                                          ? pal.sel
                                          : pal.faint.withValues(alpha: .55),
                                      borderRadius: BorderRadius.circular(capR(9)),
                                    ),
                                  ),
                              ],
                            ),
                          ],
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
    );
  }

  Widget _sidePill(
    String label,
    VoidCallback onTap, {
    bool compact = false,
  }) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        alignment: Alignment.center,
        margin: EdgeInsets.only(bottom: compact ? 0 : 11),
        padding: EdgeInsets.symmetric(vertical: compact ? 6 : 17),
        decoration: BoxDecoration(
          color: pal.pillC,
          borderRadius: BorderRadius.circular(capR(54)),
        ),
        child: Text(
          label,
          maxLines: 1,
          softWrap: false,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: pal.ink),
        ),
      ),
    );
  }

  /// Word list with fades physically anchored to the top and bottom
  /// edges of its own visible viewport, below the collection header.
  /// [bottomPad] clears the floating nav bar on tab pages.
  /// [singleLine] (home): word right-aligned, meaning left-aligned.
  Widget _pairList(
    List<Entry> items, {
    double bottomPad = 0,
    bool singleLine = false,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text('واژه‌ای پیدا نشد', style: TextStyle(color: pal.muted)),
      );
    }
    return edgeFade(
            fadeExtent: 0.22,
      fadeStrength: 0.94,
      child: ListView.separated(
        padding: EdgeInsets.only(top: 6, bottom: bottomPad),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
        itemBuilder: (_, i) => _pairRow(items[i], singleLine: singleLine),
      ),
    );
  }

  /// عربی درشت و پررنگ (سر‌واژه)، فارسی کوچک و کم‌رنگ (برابر).
  Widget _pairRow(Entry e, {bool singleLine = false}) {
    final wordStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 17.5,
      color: pal.ink,
    );
    final meaningStyle = TextStyle(
      color: e.hasFa ? pal.muted : pal.faint,
      fontSize: 13.5,
    );
    final actions = LikeBookmarkButtons(
      liked: liked.contains(e.ar),
      bookmarked: favorites.contains(e.ar),
      onToggleLike: () => _toggleLike(e.ar),
      onToggleBookmark: () => _toggleFav(e.ar),
    );
    if (singleLine) {
      return InkWell(
        onTap: () => _showEntry(e),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: Text(
                  e.ar,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: wordStyle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 6,
                child: Text(
                  meaningText(e, single: true),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.left,
                  style: meaningStyle,
                ),
              ),
            ],
          ),
        ),
      );
    }
    return InkWell(
      onTap: () => _showEntry(e),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Text(e.ar, style: wordStyle),
            const SizedBox(width: 12),
            Expanded(child: Text(meaningText(e), style: meaningStyle)),
            actions,
          ],
        ),
      ),
    );
  }

  void _open(Widget page) {
    Navigator.of(context).push(_softRoute(page));
  }

  /// Proverb page wired to the shell's like/favorite storage.
  Widget _pandvazhePage(Dictionary d) => PandvazhePage(
    proverbs: proverbs,
    dict: d,
    onOpenEntry: _showEntry,
    liked: liked,
    favorites: favorites,
    onToggleLike: _toggleLike,
    onToggleFav: _toggleFav,
  );

  /// Fresh-words page (new words of the latest update) + Word of the Day.
  Widget _freshPage(Dictionary d) =>
      FreshPage(dict: d, onWordOfDay: () => _pushPage(_dailyPage(d)));

  /// Pushes a shell-built page (pageShell column) as its own route.
  void _pushPage(Widget body) {
    Navigator.of(context).push(
      _softRoute(Scaffold(body: SafeArea(child: body))),
    );
  }

  /// Word detail card (round 3): the shared DetailSheet — the same
  /// card as a proverb's. Like/bookmark update in place; the sheet is
  /// never closed and re-opened (that was the "another card opens"
  /// bug: the old handlers did Navigator.pop + _showEntry again).
  void _showProverb(String title, String meaning) {
    final key = 'proverb:$title';
    final card = ShareCardData(
      title: title,
      lines: [meaning],
      caption: 'پندواژه فارسی',
    );
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.bg,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: card,
          initialLiked: liked.contains(key) || liked.contains(title),
          initialBookmarked: favorites.contains(key) || favorites.contains(title),
          onToggleLike: () => _toggleLike(key),
            onToggleBookmark: () => _toggleFav(key),
          ),
        ),
      ),
    );
  }

  void _showRootPopup(String word) {
    final current = dict;
    if (current == null || word.trim().isEmpty) return;
    final key = 'root:$word';
    final rows = PersianRoots.index(current);
    final base = PersianRoots.baseOf(word);
    final related = PersianRoots.sameBase(rows, word);
    final lines = <String>[
      'بن‌واژه: $base',
      if (related.isNotEmpty)
        'واژه‌های هم‌بن: ${related.map((item) => item.word).join('، ')}',
      'این بن‌واژه از ساخت صرفی واژه به‌دست آمده و لزوماً خاستگاه تاریخی آن نیست.',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: ShareCardData(
              title: word,
              lines: lines,
              caption: 'ریشه‌شناسی فارسی · بن‌واژهٔ ساختاری',
            ),
            initialLiked: liked.contains(key),
            initialBookmarked: favorites.contains(key),
            onToggleLike: () => _toggleLike(key),
            onToggleBookmark: () => _toggleFav(key),
          ),
        ),
      ),
    );
  }

  void _showEntry(Entry e) {
    final catId = categories.categoryOf(e.ar);
    final card = ShareCardData(
      title: e.ar,
      lines: [
        e.hasFa
            ? 'برابر فارسی: ${e.fa.join('، ')}'
            : 'برای این واژه هنوز برابر فارسی ثبت نشده است.',
      ],
      caption: catId == null ? null : 'دسته: ${catMeta[catId]?.$2 ?? catId}',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: card,
        initialLiked: liked.contains(e.ar),
        initialBookmarked: favorites.contains(e.ar),
        onToggleLike: () => _toggleLike(e.ar),
        onToggleBookmark: () => _toggleFav(e.ar),
        etymologyWord: e.hasFa ? e.fa.first : null,
        relatedPersianWords: e.fa,
        onOpenEtymology: () {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && e.hasFa) {
              _showRootPopup(e.fa.first);
            }
          });
        },
          ),
        ),
      ),
    );
  }

  Widget _savedFilterBar({
    required int selected,
    required ValueChanged<int> onChanged,
  }) {
    const labels = ['واژه', 'پندواژه', 'شعر', 'کتاب', 'ریشه‌شناسی'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++)
          Expanded(
            child: Pressable(
              onTap: () => onChanged(i),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 2),
                child: Text(
                  labels[i],
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: selected == i
                        ? pal.ink
                        : pal.muted.withValues(alpha: 0.62),
                    fontSize: 11.5,
                    fontWeight: selected == i
                        ? FontWeight.w800
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  // ---------- پسندیده‌ها ----------
  Widget _likedPage(Dictionary d) {
    final mine = d.entries.where((e) => liked.contains(e.ar)).toList();
    final savedRoots = PersianRoots.index(d)
        .where((row) => liked.contains('root:${row.word}'))
        .toList();
    final savedProverbs = proverbs.where((p) =>
      liked.contains('proverb:${p.$1}') || liked.contains(p.$1)
    ).toList();
    final savedPoems = liked.where((key) => key.startsWith('poem:')).toList();
    final savedBooks = liked.where((key) => key.startsWith('book:')).toList();
    final wordsVisible = _likedFilter == 0;
    final proverbsVisible = _likedFilter == 1;
    final poemsVisible = _likedFilter == 2;
    final booksVisible = _likedFilter == 3;
    final rootsVisible = _likedFilter == 4;
    final isEmpty = (!wordsVisible || mine.isEmpty) &&
        (!proverbsVisible || savedProverbs.isEmpty) &&
        (!poemsVisible || savedPoems.isEmpty) &&
        (!booksVisible || savedBooks.isEmpty) &&
        (!rootsVisible || savedRoots.isEmpty);

    return _pageShell(
      'پسندیده‌ها',
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _savedFilterBar(
              selected: _likedFilter,
              onChanged: (value) => setState(() => _likedFilter = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isEmpty
                  ? Center(
                      child: Text(
                        'موردی در این دسته پسندیده نشده است.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted, height: 1.9),
                      ),
                    )
                  : edgeFade(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: kNavClearance),
                        children: [
                          if (wordsVisible)
                            for (final e in mine) _pairRow(e),
                          if (rootsVisible)
                            for (final row in savedRoots) _savedRootRow(row),
                          if (proverbsVisible)
                            for (final p in savedProverbs) _savedProverbRow(p),
                          if (poemsVisible)
                            for (final poem in savedPoems) _savedPoemRow(poem, d),
                          if (booksVisible)
                            for (final book in savedBooks) _savedBookRow(book, d),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- نشان‌شده ----------
  Widget _favoritesPage(Dictionary d) {
    final favs = d.entries.where((e) => favorites.contains(e.ar)).toList();
    final savedRoots = PersianRoots.index(d)
        .where((row) => favorites.contains('root:${row.word}'))
        .toList();
    final savedProverbs = proverbs.where((p) =>
      favorites.contains('proverb:${p.$1}') || favorites.contains(p.$1)
    ).toList();
    final savedPoems = favorites.where((key) => key.startsWith('poem:')).toList();
    final savedBooks = favorites.where((key) => key.startsWith('book:')).toList();
    final wordsVisible = _favoritesFilter == 0;
    final proverbsVisible = _favoritesFilter == 1;
    final poemsVisible = _favoritesFilter == 2;
    final booksVisible = _favoritesFilter == 3;
    final rootsVisible = _favoritesFilter == 4;
    final isEmpty = (!wordsVisible || favs.isEmpty) &&
        (!proverbsVisible || savedProverbs.isEmpty) &&
        (!poemsVisible || savedPoems.isEmpty) &&
        (!booksVisible || savedBooks.isEmpty) &&
        (!rootsVisible || savedRoots.isEmpty);

    return _pageShell(
      'نشان‌شده',
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            _savedFilterBar(
              selected: _favoritesFilter,
              onChanged: (value) => setState(() => _favoritesFilter = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: isEmpty
                  ? Center(
                      child: Text(
                        'موردی در این دسته نشان نشده است.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.muted, height: 1.9),
                      ),
                    )
                  : edgeFade(
                      child: ListView(
                        padding: const EdgeInsets.only(bottom: kNavClearance),
                        children: [
                          if (wordsVisible)
                            for (final e in favs) _pairRow(e),
                          if (rootsVisible)
                            for (final row in savedRoots) _savedRootRow(row),
                          if (proverbsVisible)
                            for (final p in savedProverbs) _savedProverbRow(p),
                          if (poemsVisible)
                            for (final poem in savedPoems) _savedPoemRow(poem, d),
                          if (booksVisible)
                            for (final book in savedBooks) _savedBookRow(book, d),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _savedRootRow(PersianLexeme row) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
      leading: Icon(LucideIcons.gitBranch, color: pal.sel),
      title: Text(
        row.word,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        'بن‌واژه: ${row.base}',
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: TextStyle(color: pal.muted, fontSize: 11.5),
      ),
      trailing: Icon(LucideIcons.chevronLeft, color: pal.muted, size: 17),
      onTap: () => _showRootPopup(row.word),
    );
  }

  Widget _savedBookRow(String key, Dictionary dictionary) {
    final path = key.substring('book:'.length);
    final future = _savedBookCatalog ??= GanjoorData.bookCatalog();
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: future,
      builder: (context, snapshot) {
        Map<String, dynamic>? row;
        for (final item in snapshot.data ?? const <Map<String, dynamic>>[]) {
          final full = (item['FullUrl'] ?? item['fullUrl'] ?? '')
              .toString()
              .replaceFirst(RegExp(r'^/'), '');
          if (full == path) {
            row = item;
            break;
          }
        }
        final title = (row?['Title'] ?? row?['title'] ?? row?['Name'] ??
                row?['name'] ?? path.split('/').last)
            .toString();
        final poet = (row?['PoetName'] ?? row?['PoetNickname'] ??
                row?['poetName'] ?? '')
            .toString();
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          leading: Icon(LucideIcons.notebookPen, color: pal.sel),
          title: Text(
            title,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700),
          ),
          subtitle: poet.isEmpty
              ? null
              : Text(
                  poet,
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: TextStyle(color: pal.muted, fontSize: 11.5),
                ),
          trailing: Icon(LucideIcons.chevronLeft, color: pal.muted, size: 17),
          onTap: () => _open(GanjoorNodePage(
            title: title,
            path: path,
            depth: 1,
            dictionary: dictionary,
            liked: liked,
            favorites: favorites,
            onToggleLike: _toggleLike,
            onToggleBookmark: _toggleFav,
            onOpenEntry: _showEntry,
          )),
        );
      },
    );
  }

  Widget _savedPoemRow(String key, Dictionary dictionary) {
    final value = key.substring('poem:'.length);
    final marker = value.lastIndexOf('#');
    if (marker <= 0) return const SizedBox.shrink();
    final path = value.substring(0, marker);
    final coupletIndex = int.tryParse(value.substring(marker + 1)) ?? 0;
    return FutureBuilder<Map<String, dynamic>>(
      future: GanjoorData.json(path),
      builder: (context, snapshot) {
        final data = snapshot.data;
        final poemTitle = data?['Title']?.toString() ?? 'شعر ذخیره‌شده';
        final fullTitle = data?['FullTitle']?.toString() ?? poemTitle;
        final pathParts = fullTitle
            .split(RegExp(r'\s*[»›>]+\s*'))
            .where((part) => part.trim().isNotEmpty)
            .toList();
        final breadcrumb = pathParts.join('  ›  ');
        final bookTitle = pathParts.length > 1 ? pathParts[1] : poemTitle;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 5),
          leading: Icon(LucideIcons.fileText, color: pal.sel),
          title: Text(
            bookTitle,
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '$breadcrumb  ·  بیت ${faNum(coupletIndex + 1)}',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: pal.muted, fontSize: 11.5, height: 1.6),
          ),
          trailing: Icon(LucideIcons.chevronLeft, color: pal.muted, size: 17),
          onTap: () => _open(GanjoorPoemPage(
            title: poemTitle,
            path: path,
            dictionary: dictionary,
            liked: liked,
            favorites: favorites,
            onToggleLike: _toggleLike,
            onToggleBookmark: _toggleFav,
            onOpenEntry: _showEntry,
          )),
        );
      },
    );
  }

  Widget _savedProverbRow((String, String) proverb) {
    final key = 'proverb:${proverb.$1}';
    return InkWell(
      onTap: () => _showProverb(proverb.$1, proverb.$2),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(proverb.$1,
                    textAlign: TextAlign.right,
                    style: TextStyle(color: pal.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(proverb.$2,
                    textAlign: TextAlign.right,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pal.muted, fontSize: 12.5)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            LikeBookmarkButtons(
              liked: liked.contains(key) || liked.contains(proverb.$1),
              bookmarked: favorites.contains(key) || favorites.contains(proverb.$1),
              onToggleLike: () => _toggleLike(key),
              onToggleBookmark: () => _toggleFav(key),
            ),
          ],
        ),
      ),
    );
  }

  // ---------- بخش‌ها (همهٔ قابلیت‌ها) ----------
  Widget _ganjoorPage(Dictionary d) => GanjoorPage(
    dictionary: d,
    liked: liked,
    favorites: favorites,
    onToggleLike: _toggleLike,
    onToggleBookmark: _toggleFav,
    onOpenEntry: _showEntry,
  );

  Widget _sectionsPage(Dictionary d) {
    final tiles = <(IconData, String, VoidCallback)>[
      (
        LucideIcons.notebookPen,
        'گنجینهٔ واژه‌ها',
        () => _open(LexiconPage(dict: d, onTapEntry: _showEntry)),
      ),
      (LucideIcons.type, 'درست‌نویسی', () => _open(CorrectorPage(dict: d))),
      (LucideIcons.alignLeft, 'نیم‌فاصله', () => _open(const NimeFaselePage())),
      (LucideIcons.fileText, 'پندواژه', () => _open(_pandvazhePage(d))),
      (
        LucideIcons.gitBranch,
        'ریشه‌شناسی',
        () => _open(
          EtymologyPage(
            dict: d,
            liked: liked,
            favorites: favorites,
            onToggleLike: _toggleLike,
            onToggleBookmark: _toggleFav,
          ),
        ),
      ),
      (LucideIcons.sparkles, 'واژه‌های تازه', () => _open(_freshPage(d))),
      (LucideIcons.star, 'واژهٔ روز', () => _pushPage(_dailyPage(d))),
      (
        LucideIcons.fileText,
        'کتابخانهٔ شعر',
        () => _open(_ganjoorPage(d)),
      ),
      (LucideIcons.award, 'یادگیری من', () => _pushPage(_learningPage())),
      (
        LucideIcons.keyboard,
        'کیبورد سورن',
        () => _open(const KeyboardGuidePage()),
      ),
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
                  child: Pressable(
                    onTap: () => _pushPage(_categoriesPage(d)),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        // Same height as the grid tiles: tile width is
                        // (row - 14 spacing) / 2, height = width / 1.25.
                        final tileH = ((constraints.maxWidth - 14) / 2) / 1.25;
                        return Container(
                          height: tileH,
                          decoration: BoxDecoration(
                            color: pal.pillC,
                            borderRadius: BorderRadius.circular(capR(54)),
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
                        );
                      },
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
                      child: Pressable(
                        onTap: tiles[i].$3,
                        child: Container(
                          decoration: BoxDecoration(
                            color: pal.pillC,
                            borderRadius: BorderRadius.circular(capR(54)),
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
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
          children: [
            for (var i = 0; i < catOrder.length; i++)
              Enter(
                index: i,
                child: Pressable(
                  onTap: () => _pushPage(_categoryWordsPage(d, catOrder[i])),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: pal.pillC,
                      borderRadius: BorderRadius.circular(capR(49)),
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
      back: true,
    );
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
      back: true,
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
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: pal.div),
                ),
                onPressed: () => _showEntry(e),
                child: const Text('دیدن واژه'),
              ),
            ],
          ),
        ),
      ),
      back: true,
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
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: pal.div),
                  ),
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
      back: true,
    );
  }

  // ---------- نمایهٔ کاربری ----------
  static const _badgeMeta = <String, (IconData, String, String)>{
    'member': (LucideIcons.badgeCheck, 'عضو سورن', 'با نمایه وارد شده‌اید'),
    'firstBookmark': (LucideIcons.bookmark, 'نخستین نشان', 'یک واژه نشان کنید'),
    'liker': (LucideIcons.heart, 'دل‌باختهٔ واژه', '۱۰ واژه را بپسندید'),
    'keyboardStudent': (
      LucideIcons.keyboard,
      'شاگرد کیبورد',
      '۲۰ اصلاح کیبورد را بپذیرید',
    ),
    'hundred': (LucideIcons.star, 'باشگاه صدتایی‌ها', 'به ۱۰۰ امتیاز برسید'),
    'collector': (LucideIcons.archive, 'گنجینه‌دار', '۲۵ واژه نشان کنید'),
  };

  /// One badge tile: full-width row cell, earned = filled with a
  /// check. Tapping it slides its description down from the top of
  /// the screen like a notification (round 3 §17).
  Widget _badgeTile(
    String id, {
    required bool loggedIn,
    required int favorites,
    required int likes,
    required int corrections,
    required int score,
  }) {
    final earned = badgeEarned(
      id,
      loggedIn: loggedIn,
      favorites: favorites,
      likes: likes,
      corrections: corrections,
      score: score,
    );
    final meta = _badgeMeta[id]!;
    return Pressable(
      onTap: () => showTopBanner(context, title: meta.$2, message: meta.$3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: earned ? pal.sel : pal.pillC,
          borderRadius: BorderRadius.circular(capR(46)),
        ),
        child: Row(
          children: [
            Icon(meta.$1, size: 19, color: earned ? pal.bg : pal.muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                meta.$2,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 13.5,
                  color: earned ? pal.bg : pal.muted,
                  fontWeight: earned ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
            if (earned) Icon(LucideIcons.check, size: 16, color: pal.bg),
          ],
        ),
      ),
    );
  }

  Widget _profilePage(Dictionary d) {
    final score = profileScore(favorites: favorites.length, likes: liked.length, learnedWords: learnedWords, corrections: learnedCorrections);
    final next = nextLevelAt(score);
    final levelIndex = levelThresholds.lastIndexWhere((t) => score >= t.$1);
    final currentLevel = levelThresholds[levelIndex];
    final previousLevel = levelIndex > 0 ? levelThresholds[levelIndex - 1] : null;
    final followingLevel = levelIndex + 1 < levelThresholds.length ? levelThresholds[levelIndex + 1] : null;
    final profileCard = ShareCardData(
      title: 'نمایهٔ من',
      lines: [
        'امتیاز کل: ${faNum(score)}',
        'سطح فعلی: ${currentLevel.$2}',
        'موارد نشان‌شده: ${faNum(favorites.length)}',
        'موارد پسندیده: ${faNum(liked.length)}',
        'واژه‌های آموخته‌شده: ${faNum(learnedWords)}',
        'اصلاح‌های پذیرفته‌شده: ${faNum(learnedCorrections)}',
      ],
      caption: 'نمایهٔ شخصی سورن · ذخیره‌شده فقط روی دستگاه',
      isProfile: true,
      profileScore: score,
      profileLevel: currentLevel.$2,
    );
    final progress = next == null ? 1.0 : (score - currentLevel.$1) / (next - currentLevel.$1);
    return _pageShell(
      'نمایهٔ کاربری',
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 10, 24, 24 + kNavClearance),
          children: [
            Row(children: [
              CircleAvatar(radius: 33, backgroundColor: pal.sel, child: Icon(LucideIcons.user, color: pal.bg, size: 32)),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('نمایهٔ محلی', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: pal.ink)),
                const SizedBox(height: 4),
                Text('اطلاعات و پیشرفت شما فقط روی همین دستگاه نگهداری می‌شود.', style: TextStyle(color: pal.muted, fontSize: 13, height: 1.7)),
              ])),
            ]),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(52))),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('امتیاز شما', style: TextStyle(fontSize: 14.5, color: pal.muted)),
                  Text('سطح: ${currentLevel.$2}', style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: pal.ink)),
                ]),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: AnimatedValue(value: score.toDouble(), builder: (v) => Text(faNum(v.round()), style: TextStyle(fontSize: 38, fontWeight: FontWeight.w700, color: pal.ink)))),
                const SizedBox(height: 10),
                AnimatedValue(value: progress, builder: (v) => ClipRRect(borderRadius: BorderRadius.circular(capR(18)), child: LinearProgressIndicator(value: v, minHeight: 9, backgroundColor: pal.div, color: pal.sel))),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: Text(next == null ? 'به بالاترین سطح رسیده‌اید' : 'تا سطح بعد ${faNum(next - score)} امتیاز دیگر', style: TextStyle(fontSize: 12.5, color: pal.muted))),
              ]),
            ),
            const SizedBox(height: 14),
            Row(children: [
              _levelInfoTile('سطح قبلی', previousLevel),
              const SizedBox(width: 8),
              _levelInfoTile('سطح فعلی', currentLevel, active: true),
              const SizedBox(width: 8),
              _levelInfoTile('سطح بعدی', followingLevel),
            ]),
            const SizedBox(height: 14),
            SizedBox(width: double.infinity, child: OutlinedButton.icon(
              icon: const Icon(Symbols.share_rounded, size: 19),
              label: const Text('اشتراک‌گذاری نمایه'),
              onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (_) => _ShareSheet(card: profileCard)),
            )),
            const SizedBox(height: 24),
            Text('نشان‌ها', style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: pal.ink)),
            const SizedBox(height: 12),
            Column(children: [
              for (var r = 0; r < (badgeIds.length + 1) ~/ 2; r++)
                Padding(padding: const EdgeInsets.only(bottom: 10), child: Row(children: [
                  Expanded(child: _badgeTile(badgeIds[r * 2], loggedIn: false, favorites: favorites.length, likes: liked.length, corrections: learnedCorrections, score: score)),
                  const SizedBox(width: 10),
                  if (r * 2 + 1 < badgeIds.length)
                    Expanded(child: _badgeTile(badgeIds[r * 2 + 1], loggedIn: false, favorites: favorites.length, likes: liked.length, corrections: learnedCorrections, score: score))
                  else
                    const Spacer(),
                ])),
            ]),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(52))),
              child: Column(children: [
                _statRow('واژه‌های نشان‌شده', favorites.length),
                _statRow('واژه‌های پسندیده', liked.length),
                _statRow('واژه‌های آموختهٔ کیبورد', learnedWords),
                _statRow('اصلاح‌های پذیرفته‌شده', learnedCorrections, last: true),
              ]),
            ),
            const SizedBox(height: 24),
            ListTile(leading: Icon(LucideIcons.award, color: pal.ink), title: const Text('آموخته‌های کیبورد'), subtitle: const Text('آنچه کیبورد سورن روی همین دستگاه آموخته است'), onTap: () => _pushPage(_learningPage())),
          ],
        ),
      ),
    );
  }

  Widget _levelInfoTile(
    String label,
    (int, String)? level, {
    bool active = false,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 11),
        decoration: BoxDecoration(
          color: active ? pal.pillC : Colors.transparent,
          borderRadius: BorderRadius.circular(capR(42)),
          border: Border.all(color: active ? pal.div : pal.div.withValues(alpha: .5)),
        ),
        child: Column(
          children: [
            Text(label, style: TextStyle(fontSize: 10.5, color: pal.muted)),
            const SizedBox(height: 5),
            Text(
              level?.$2 ?? '—',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                color: active ? pal.ink : pal.muted,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              level == null ? '—' : '${faNum(level.$1)} امتیاز',
              style: TextStyle(fontSize: 9.5, color: pal.faint),
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
                borderRadius: BorderRadius.circular(capR(32)),
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
                    borderRadius: BorderRadius.circular(capR(26)),
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
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22 + kNavClearance),
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('قابلیت‌ها', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            ),
            const SizedBox(height: 8),
            _toggleRow(
              title: 'جایگزینی حروف و اعداد عربی با فارسی',
              subtitle: 'حروف عربی و رقم‌های عربی‌هندی هنگام تایپ به شکل فارسی تبدیل می‌شوند',
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
            _toggleRow(
              title: 'فعال‌سازی Ario',
              subtitle: 'نمایش آیکون مستقل Ario در فهرست برنامه‌ها؛ داده‌های آن جدا نگهداری می‌شوند',
              value: arioEnabled,
              onChanged: _setArioState,
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'رفتار کیبورد',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: capsuleGroup<String>(
                options: const [
                  ('short', 'کوتاه'),
                  ('normal', 'معمولی'),
                  ('tall', 'بلند'),
                ],
                value: settings.kbHeight,
                onChanged: (v) async {
                  setState(() => settings.kbHeight = v);
                  await SettingsStore.update(settings);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'ارتفاع کیبورد با بازشدن دوبارهٔ کیبورد اعمال می‌شود',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'ظاهر و نمایش',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: capsuleGroup<String>(
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
                'اندازهٔ نوشته‌ها',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: capsuleGroup<String>(
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
              child: capsuleGroup<String>(
                options: const [('rtl', 'راست‌چین'), ('ltr', 'چپ‌چین')],
                value: settings.direction,
                onChanged: (v) async {
                  setState(() => settings.direction = v);
                  await SettingsStore.update(settings);
                },
              ),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('مدیریت کیبورد', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.keyboard),
              title: const Text('فعال‌کردن کیبورد سورن'),
              subtitle: const Text('تنظیمات کیبورد اندروید باز می‌شود'),
              onTap: () => SharedFiles.openInputSettings(),
            ),
            ListTile(
              leading: const Icon(LucideIcons.repeat),
              title: const Text('برگزیدن کیبورد سورن به‌عنوان کیبورد کنونی'),
              onTap: () => SharedFiles.showKeyboardPicker(),
            ),
            const Divider(height: 32),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('پایگاه واژه‌ها', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5)),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(LucideIcons.refreshCw),
              title: const Text('به‌روزرسانی پایگاه واژه‌ها'),
              subtitle: Text(
                'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — فایل JSON یا CSV برگزینید',
              ),
              onTap: () => _importDb(),
            ),
            ListTile(
              leading: const Icon(LucideIcons.download),
              title: const Text('به‌روزرسانی آنلاین پایگاه واژه‌ها'),
              subtitle: Text(
                'نسخهٔ کنونی: ${faNum(d.version)} — دریافت نسخهٔ تازه؛ هیچ دادهٔ شخصی ارسال نمی‌شود',
              ),
              trailing: dbSyncing
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : null,
              onTap: dbSyncing ? null : () => _syncDbNow(d),
            ),
            ListTile(
              leading: Icon(ganjoorPackInstalled ? LucideIcons.database : LucideIcons.download, color: pal.ink),
              title: const Text('پایگاه آفلاین گنجور'),
              subtitle: Text(ganjoorPackBusy
                  ? '${faNum(ganjoorPackReceived ~/ (1024 * 1024))} از ${faNum(ganjoorPackTotal ~/ (1024 * 1024))} مگابایت دریافت شده'
                  : ganjoorPackInstalled
                      ? 'نصب‌شده؛ شعرها و کتاب‌ها از پایگاه محلی خوانده می‌شوند'
                      : 'دانلود پایگاه کامل شعر و کتاب · حدود ۱۹۴ مگابایت'),
              trailing: ganjoorPackBusy
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : TextButton(
                      onPressed: ganjoorPackInstalled ? _removeGanjoorPack : _downloadGanjoorPack,
                      child: Text(ganjoorPackInstalled ? 'حذف' : 'دانلود'),
                    ),
            ),
            if (ganjoorPackBusy)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 18),
                child: LinearProgressIndicator(
                  value: ganjoorPackTotal > 0 ? ganjoorPackReceived / ganjoorPackTotal : null,
                  minHeight: 6,
                  borderRadius: BorderRadius.circular(capR(12)),
                ),
              ),
            ListTile(
              leading: const Icon(LucideIcons.share2),
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
                'درباره: سورن دیکشنری عربی به فارسی با کیبوردی برای درست‌نویسی فارسی است. داده‌های نمایه، پسندیده‌ها، نشان‌شده‌ها و یادگیری کیبورد فقط روی دستگاه نگهداری می‌شوند و به سرور ارسال نمی‌شوند.',
                style: TextStyle(color: pal.muted, height: 1.9, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncDbNow(Dictionary current) async {
    setState(() => dbSyncing = true);
    final updated = await DictionarySync.syncFromServer(current);
    if (updated) {
      final refreshed = await Dictionary.load();
      if (mounted) setState(() => dict = refreshed);
    }
    if (mounted) {
      setState(() => dbSyncing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(updated ? 'پایگاه واژه‌ها به‌روز شد' : 'پایگاه به‌روز است یا دریافت آن ممکن نشد')),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('پایگاه واژه‌ها به‌روز شد')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('این فایل خوانا نیست؛ JSON یا CSV درست برگزینید'),
          ),
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


  Future<void> _saveArioProgress() async => SharedFiles.writeJson('ario_learning.json', {
    'completedLessons': arioCompletedLessons.toList()..sort(),
    'knownWords': arioKnownWords.toList(),
    'lastLesson': arioLastLesson,
    'quizIndex': arioQuizIndex,
  });

  Future<void> _loadGanjoorPackState() async {
    final installed = await GanjoorPack.isInstalled();
    if (mounted) setState(() => ganjoorPackInstalled = installed);
  }

  Future<void> _downloadGanjoorPack() async {
    if (ganjoorPackBusy) return;
    setState(() { ganjoorPackBusy = true; ganjoorPackReceived = 0; ganjoorPackTotal = 0; });
    try {
      await GanjoorPack.download(onProgress: (received, total) {
        if (mounted) setState(() { ganjoorPackReceived = received; ganjoorPackTotal = total; });
      });
      final installed = await GanjoorPack.isInstalled();
      if (mounted) {
        setState(() { ganjoorPackInstalled = installed; ganjoorPackBusy = false; });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(installed ? 'پایگاه آفلاین گنجور نصب شد' : 'نصب پایگاه گنجور تأیید نشد')));
      }
    } catch (error) {
      if (mounted) {
        setState(() => ganjoorPackBusy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('دریافت پایگاه گنجور ناموفق بود: $error')));
      }
    }
  }

  Future<void> _removeGanjoorPack() async {
    if (ganjoorPackBusy) return;
    await GanjoorPack.remove();
    final installed = await GanjoorPack.isInstalled();
    if (mounted) {
      setState(() => ganjoorPackInstalled = installed);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('پایگاه آفلاین گنجور حذف شد')));
    }
  }

  Widget _arioPageShell(String title, Widget body) => Directionality(
    textDirection: TextDirection.rtl,
    child: Column(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 20, 8),
        child: Row(children: [
          Expanded(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w700))),
          Pressable(onTap: () => setState(() { arioMode = false; tab = 0; }), child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(color: pal.pillC, borderRadius: BorderRadius.circular(capR(42))),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.arrowRight, size: 16, color: pal.ink),
              const SizedBox(width: 6),
              Text('سورن', style: TextStyle(fontSize: 13, color: pal.ink, fontWeight: FontWeight.w600)),
            ]),
          )),
        ]),
      ),
      Expanded(child: body),
    ]),
  );

  Widget _arioHome(Dictionary d) {
    final words = d.entries.where((e) => e.hasFa).toList();
    final lessonCount = (words.length + 11) ~/ 12;
    final completed = arioCompletedLessons.length;
    final progress = lessonCount == 0 ? 0.0 : (completed / lessonCount).clamp(0.0, 1.0).toDouble();
    final currentLesson = arioLastLesson.clamp(0, lessonCount == 0 ? 0 : lessonCount - 1).toInt();
    final daily = words.isEmpty ? null : words[(DateTime.now().year * 372 + DateTime.now().month * 31 + DateTime.now().day) % words.length];
    return _arioPageShell('آریو', edgeFade(child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28 + kNavClearance),
      children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: pal.sel, borderRadius: BorderRadius.circular(capR(54))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('یادگیری، قدم‌به‌قدم', style: TextStyle(color: pal.bg.withValues(alpha: .8), fontSize: 13)),
          const SizedBox(height: 8),
          Text('هر روز یک واژه؛ هر روز یک قدم جلوتر.', style: TextStyle(color: pal.bg, fontSize: 22, fontWeight: FontWeight.w800, height: 1.5)),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(child: Text('${faNum(completed)} از ${faNum(lessonCount)} درس کامل شده', style: TextStyle(color: pal.bg, fontSize: 13))),
            Text('${faNum((progress * 100).round())}٪', style: TextStyle(color: pal.bg, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(borderRadius: BorderRadius.circular(capR(18)), child: LinearProgressIndicator(value: progress, minHeight: 8, backgroundColor: pal.bg.withValues(alpha: .2), color: pal.bg)),
        ])),
        const SizedBox(height: 18),
        if (daily != null) Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(48))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('واژهٔ امروز', style: TextStyle(color: pal.muted, fontSize: 13)),
          const SizedBox(height: 10),
          Center(child: Text(daily.ar, style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: pal.ink))),
          const SizedBox(height: 6),
          Center(child: Text(daily.fa.join('، '), style: TextStyle(fontSize: 17, color: pal.sel, fontWeight: FontWeight.w600))),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: () => setState(() => tab = 2), child: const Text('تمرین واژه‌ها'))),
        ])),
        const SizedBox(height: 14),
        _arioAction('ادامهٔ مسیر یادگیری', 'درس ${faNum(currentLesson + 1)} · ${faNum(words.skip(currentLesson * 12).take(12).length)} واژه', LucideIcons.gitBranch, () => _openArioLesson(d, currentLesson)),
        _arioAction('تمرین کوتاه', 'چهارگزینه‌ای از واژه‌های سورن', LucideIcons.target, () => setState(() => tab = 2)),
        _arioAction('مرور آموخته‌ها', '${faNum(arioKnownWords.length)} واژه در حافظهٔ یادگیری', LucideIcons.repeat, () => setState(() => tab = 3)),
        _arioAction('کتابخانهٔ گنجور', 'خواندن شعر و متن ادبی از پایگاه مشترک سورن', LucideIcons.notebookPen, () => _open(_ganjoorPage(d))),
      ],
    )));
  }

  Widget _arioAction(String title, String subtitle, IconData icon, VoidCallback onTap) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Pressable(onTap: onTap, child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
      decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(46))),
      child: Row(children: [
        Container(width: 42, height: 42, decoration: BoxDecoration(color: pal.pillC, borderRadius: BorderRadius.circular(capR(40))), child: Icon(icon, color: pal.ink, size: 20)),
        const SizedBox(width: 13),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700, fontSize: 15)),
          const SizedBox(height: 3),
          Text(subtitle, style: TextStyle(color: pal.muted, fontSize: 12.5)),
        ])),
        Icon(LucideIcons.chevronLeft, color: pal.muted, size: 18),
      ]),
    )),
  );

  Widget _arioPath(Dictionary d) {
    final words = d.entries.where((e) => e.hasFa).toList();
    final count = (words.length + 11) ~/ 12;
    return _arioPageShell('مسیر یادگیری', edgeFade(child: ListView.separated(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 30 + kNavClearance),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final done = arioCompletedLessons.contains(i);
        final unlocked = i == 0 || arioCompletedLessons.contains(i - 1);
        final subset = words.skip(i * 12).take(12).toList();
        return Pressable(onTap: unlocked ? () => _openArioLesson(d, i) : null, child: Opacity(opacity: unlocked ? 1 : .45, child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(46))),
          child: Row(children: [
            Container(width: 42, height: 42, decoration: BoxDecoration(color: done ? pal.sel : pal.pillC, borderRadius: BorderRadius.circular(capR(40))), child: Center(child: done ? Icon(LucideIcons.check, color: pal.bg, size: 19) : Text(faNum(i + 1), style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)))),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('درس ${faNum(i + 1)}', style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(height: 3),
              Text('${faNum(subset.length)} واژه · ${subset.isEmpty ? '' : subset.first.ar} تا ${subset.isEmpty ? '' : subset.last.ar}', style: TextStyle(color: pal.muted, fontSize: 12.5)),
            ])),
            Icon(unlocked ? LucideIcons.chevronLeft : LucideIcons.lock, color: pal.muted, size: 18),
          ]),
        )));
      },
    )));
  }

  void _openArioLesson(Dictionary d, int lesson) {
    final words = d.entries.where((e) => e.hasFa).skip(lesson * 12).take(12).toList();
    if (words.isEmpty) return;
    setState(() => arioLastLesson = lesson);
    _saveArioProgress();
    _open(ArioLessonPage(lesson: lesson + 1, words: words, onComplete: () async {
      setState(() { arioCompletedLessons.add(lesson); arioKnownWords.addAll(words.map((e) => e.ar)); });
      await _saveArioProgress();
    }));
  }

  Widget _arioPractice(Dictionary d) {
    final words = d.entries.where((e) => e.hasFa).toList();
    if (words.isEmpty) return _arioPageShell('تمرین', const SizedBox.shrink());
    final index = arioQuizIndex % words.length;
    final current = words[index];
    final options = <String>{current.fa.first};
    for (var step = 1; options.length < 4 && step < words.length; step++) {
      options.add(words[(index * 7 + step * 17) % words.length].fa.first);
    }
    return _arioPageShell('تمرین واژه‌ها', edgeFade(child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 30 + kNavClearance),
      children: [
        Text('تمرین ${faNum(arioQuizIndex + 1)}', style: TextStyle(color: pal.muted, fontSize: 13)),
        const SizedBox(height: 18),
        Container(padding: const EdgeInsets.all(26), decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(52))), child: Column(children: [
          Text('برابر فارسی این واژه کدام است؟', style: TextStyle(color: pal.muted, fontSize: 14)),
          const SizedBox(height: 18),
          Text(current.ar, style: TextStyle(color: pal.ink, fontSize: 34, fontWeight: FontWeight.w800)),
        ])),
        const SizedBox(height: 16),
        for (final choice in options)
          Padding(padding: const EdgeInsets.only(bottom: 9), child: Pressable(onTap: arioSelectedAnswer == null ? () {
            final correct = current.fa.contains(choice);
            setState(() { arioSelectedAnswer = choice; arioAnswerCorrect = correct; if (correct) arioKnownWords.add(current.ar); });
            _saveArioProgress();
          } : null, child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 16),
            decoration: BoxDecoration(color: arioSelectedAnswer == choice ? (arioAnswerCorrect == true ? pal.sel : pal.accent) : pal.cardC, borderRadius: BorderRadius.circular(capR(42))),
            child: Text(choice, style: TextStyle(color: arioSelectedAnswer == choice ? pal.bg : pal.ink, fontWeight: FontWeight.w600)),
          ))),
        if (arioSelectedAnswer != null) ...[
          const SizedBox(height: 8),
          Text(arioAnswerCorrect == true ? 'درست است؛ آفرین!' : 'پاسخ درست: ${current.fa.join('، ')}', style: TextStyle(color: arioAnswerCorrect == true ? pal.sel : pal.accent, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          FilledButton(onPressed: () { setState(() { arioQuizIndex++; arioSelectedAnswer = null; arioAnswerCorrect = null; }); _saveArioProgress(); }, child: const Text('سؤال بعدی')),
        ],
      ],
    )));
  }

  Widget _arioReview(Dictionary d) {
    final words = d.entries.where((e) => e.hasFa && arioKnownWords.contains(e.ar)).toList();
    return _arioPageShell('مرور آموخته‌ها', words.isEmpty
      ? Center(child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(LucideIcons.notebookPen, size: 38, color: pal.muted),
          const SizedBox(height: 12),
          Text('هنوز واژه‌ای برای مرور نداری', style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('با گذراندن درس‌ها یا پاسخ درست به تمرین‌ها، واژه‌ها اینجا جمع می‌شوند.', textAlign: TextAlign.center, style: TextStyle(color: pal.muted, height: 1.7)),
        ])))
      : _pairList(words, bottomPad: kNavClearance, singleLine: true));
  }

  Widget _arioWords(Dictionary d) => _arioPageShell('واژه‌های سورن', _pairList(d.entries.where((e) => e.hasFa).toList(), bottomPad: kNavClearance, singleLine: true));

  Widget _arioProgress(Dictionary d) {
    final total = (d.entries.where((e) => e.hasFa).length + 11) ~/ 12;
    final ratio = total == 0 ? 0.0 : (arioCompletedLessons.length / total).clamp(0.0, 1.0).toDouble();
    return _arioPageShell('پیشرفت یادگیری', edgeFade(child: ListView(
      padding: const EdgeInsets.fromLTRB(22, 14, 22, 28 + kNavClearance),
      children: [
        Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(52))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('پیشرفت مسیر', style: TextStyle(color: pal.muted, fontSize: 13)),
          const SizedBox(height: 8),
          Text('${faNum((ratio * 100).round())}٪', style: TextStyle(color: pal.ink, fontSize: 36, fontWeight: FontWeight.w800)),
          const SizedBox(height: 10),
          ClipRRect(borderRadius: BorderRadius.circular(capR(18)), child: LinearProgressIndicator(value: ratio, minHeight: 9, backgroundColor: pal.div, color: pal.sel)),
        ])),
        const SizedBox(height: 12),
        _statCard('درس‌های کامل‌شده', arioCompletedLessons.length),
        _statCard('واژه‌های آموخته‌شده', arioKnownWords.length),
        _statCard('تمرین‌های انجام‌شده', arioQuizIndex),
      ],
    )));
  }

  Widget _statCard(String title, int value) => Container(
    margin: const EdgeInsets.only(bottom: 9),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    decoration: BoxDecoration(color: pal.cardC, borderRadius: BorderRadius.circular(capR(42))),
    child: Row(children: [Expanded(child: Text(title, style: TextStyle(color: pal.ink))), Text(faNum(value), style: TextStyle(color: pal.ink, fontWeight: FontWeight.w800, fontSize: 18))]),
  );

  Widget _pageShell(String title, Widget body, {bool back = false}) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: Row(
              children: [
                if (back) ...[const BackIconButton(), const SizedBox(width: 4)],
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      ),
    );
  }
}

/// The one back button everywhere: a Lucide arrow with press
/// feedback. Material's BackButton needs the Material icons font,
/// which this app does not bundle (uses-material-design is false).
class BackIconButton extends StatelessWidget {
  const BackIconButton({super.key});
  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: () => Navigator.of(context).maybePop(),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(LucideIcons.arrowLeft, color: pal.ink, size: 24),
      ),
    );
  }
}

/// Plain sub-page scaffold: a transparent, right-aligned title row
/// without a background strip or rectangle beneath the tab title.
Widget subScaffold(String title, Widget body) {
  return Scaffold(
    backgroundColor: pal.bg,
    body: SafeArea(
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: Column(
          children: [
            SizedBox(
              height: 58,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    const BackIconButton(),
                    const SizedBox(width: 2),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          color: pal.ink,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
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
      _scroll.animateTo(
        target,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
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
      Row(
        children: [
          // Alphabet rail — first in the RTL row, so it sits on the RIGHT.
          SizedBox(
            width: 30,
            child: LayoutBuilder(
              builder: (context, c) {
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
                        Text(
                          l,
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.muted,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
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
                          child: Text(
                            it,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                              color: pal.accent,
                            ),
                          ),
                        ),
                      ),
                    );
                  }
                  final e = it as Entry;
                  return SizedBox(
                    height: _rowH,
                    child: Column(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => widget.onTapEntry(e),
                            child: Row(
                              textDirection: TextDirection.rtl,
                              children: [
                                Text(
                                  e.ar,
                                  textDirection: TextDirection.rtl,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15.5,
                                    color: pal.ink,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    e.fa.join('، '),
                                    textDirection: TextDirection.rtl,
                                    textAlign: TextAlign.left,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Icon(
                                  LucideIcons.chevronLeft,
                                  size: 13,
                                  color: pal.muted,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Divider(
                          height: 1,
                          color: pal.ink.withValues(alpha: .07),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
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
  Map<String, int> _learnedPairs = const {};

  @override
  void initState() {
    super.initState();
    _loadLearningModel();
  }

  Future<void> _loadLearningModel() async {
    final learned = await SharedFiles.readJson('learned.json');
    if (learned == null) return;
    final model = <String, int>{};
    for (final key in ['pairs', 'sharedPairs']) {
      final values = learned[key];
      if (values is Map) {
        for (final entry in values.entries) {
          final count = entry.value;
          if (count is num) {
            model[entry.key.toString()] =
                (model[entry.key.toString()] ?? 0) + count.toInt();
          }
        }
      }
    }
    if (!mounted) return;
    setState(() => _learnedPairs = model);
    if (_ctrl.text.isNotEmpty) _run(_ctrl.text);
  }

  void _run(String v) {
    setState(
      () => _out = correctText(
        v,
        dictionary: widget.dict.map,
        replaceArabic: true,
        learnedPairs: _learnedPairs,
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
            TextField(
              controller: _ctrl,
              onChanged: _run,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'مثلاً: میخام عالیترین کتابها رو به همه افراد بدم، سوال دارم',
                filled: true,
                fillColor: pal.cardC,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(capR(56)),
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
                borderRadius: BorderRadius.circular(capR(54)),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: SizedBox(
                  key: ValueKey(_out),
                  width: double.infinity,
                  child: Text(
                    _out.isEmpty ? '…' : _out,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(fontSize: 17.5, height: 1.8),
                  ),
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
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: pal.sel,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(capR(50)),
                              ),
                            ),
                            onPressed: () =>
                                Clipboard.setData(ClipboardData(text: _out)),
                            child: const Text('کپی متن درست‌شده'),
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
                child: Container(
                  margin: const EdgeInsets.only(bottom: 13),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: pal.pillC,
                    borderRadius: BorderRadius.circular(capR(54)),
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
  final List<(String, String)> proverbs;
  final Dictionary dict;
  final ValueChanged<Entry> onOpenEntry;
  final Set<String> liked;
  final Set<String> favorites;
  final Future<void> Function(String) onToggleLike;
  final Future<void> Function(String) onToggleFav;

  const PandvazhePage({
    super.key,
    required this.proverbs,
    required this.dict,
    required this.onOpenEntry,
    required this.liked,
    required this.favorites,
    required this.onToggleLike,
    required this.onToggleFav,
  });



  @override
  State<PandvazhePage> createState() => _PandvazhePageState();
}

class _PandvazhePageState extends State<PandvazhePage> {
  late final Set<String> _liked = {...widget.liked};
  late final Set<String> _faved = {...widget.favorites};

  void _toggleLike(String title) {
    final key = 'proverb:$title';
    final current = _liked.contains(key) || _liked.contains(title);
    setState(() {
      current ? _liked.remove(key) : _liked.add(key);
      _liked.remove(title);
    });
    widget.onToggleLike(key);
  }

  void _toggleFav(String title) {
    final key = 'proverb:$title';
    final current = _faved.contains(key) || _faved.contains(title);
    setState(() {
      current ? _faved.remove(key) : _faved.add(key);
      _faved.remove(title);
    });
    widget.onToggleFav(key);
  }

  /// Like + bookmark side by side, outline only — the same widget
  /// word rows use (round 3).
  Widget _actions(String title) {
    final key = 'proverb:$title';
    return LikeBookmarkButtons(
      liked: _liked.contains(key) || _liked.contains(title),
      bookmarked: _faved.contains(key) || _faved.contains(title),
      onToggleLike: () => _toggleLike(title),
      onToggleBookmark: () => _toggleFav(title),
    );
  }

  /// Proverb detail card: EXACTLY the word card (round 3) — the
  /// shared DetailSheet, same size, shape and options.
  void _proverbSheet(BuildContext context, String title, String meaning) {
    final card = ShareCardData(
      title: title,
      lines: [meaning],
      caption: 'ضرب‌المثل فارسی',
    );
    final tokens = normalizeLetters('$title $meaning')
        .split(RegExp(r'[\s،,.؟!؛:()«»]+'))
        .where((word) => word.length > 1)
        .where((word) => !const {
              'از', 'به', 'در', 'که', 'و', 'را', 'با', 'این', 'آن',
              'هر', 'هم', 'تا', 'می', 'است', 'برای', 'بر', 'یک',
            }.contains(word))
        .toSet();
    final relatedEntries = widget.dict.entries.where((entry) {
      final terms = <String>[entry.ar, ...entry.fa]
          .expand((term) => normalizeLetters(term)
              .split(RegExp(r'[\\s،,.؟!؛:()«»]+')));
      return terms.any(tokens.contains);
    }).take(8).toList();
    final relatedWords = relatedEntries
        .expand((entry) => entry.fa)
        .where((word) => word.trim().isNotEmpty)
        .take(2)
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: card,
            initialLiked: _liked.contains('proverb:$title') || _liked.contains(title),
            initialBookmarked: _faved.contains('proverb:$title') || _faved.contains(title),
            onToggleLike: () async => _toggleLike(title),
            onToggleBookmark: () async => _toggleFav(title),
            relatedEntries: relatedEntries,
            relatedPersianWords: [title, ...relatedWords],
            relatedPoemTitle: 'شعرهای مرتبط با این پندواژه',
            onOpenRelatedEntry: (entry) {
              Navigator.of(sheetContext).pop();
              widget.onOpenEntry(entry);
            },
          ),
        ),
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
            for (var i = 0; i < widget.proverbs.length; i++)
              Enter(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Pressable(
                    onTap: () => _proverbSheet(
                      context,
                      widget.proverbs[i].$1,
                      widget.proverbs[i].$2,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(capR(54)),
                      child: BackdropFilter(
                        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.fromLTRB(22, 22, 22, 20),
                          decoration: BoxDecoration(
                            color: pal.pillC.withValues(alpha: 0.55),
                            borderRadius: BorderRadius.circular(capR(54)),
                            border: Border.all(
                              color: pal.div.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Row(
                                textDirection: TextDirection.rtl,
                                children: [
                                  Expanded(
                                    child: Text(
                                      widget.proverbs[i].$1,
                                      textAlign: TextAlign.right,
                                      textDirection: TextDirection.rtl,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 19,
                                      ),
                                    ),
                                  ),
                                  _actions(widget.proverbs[i].$1),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                widget.proverbs[i].$2,
                                textAlign: TextAlign.right,
                                textDirection: TextDirection.rtl,
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
                    borderRadius: BorderRadius.circular(capR(54)),
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

// ================= ریشه‌شناسی فارسی =================

class _RootInfoCard extends StatelessWidget {
  final String word;
  const _RootInfoCard({required this.word});

  @override
  Widget build(BuildContext context) {
    final base = PersianRoots.baseOf(word);
    final isInflected = base != PersianRoots.normalize(word);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: pal.cardC,
        borderRadius: BorderRadius.circular(capR(54)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('بن‌واژهٔ فارسی',
              textAlign: TextAlign.right,
              style: TextStyle(color: pal.muted, fontSize: 12.5,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(base,
              textAlign: TextAlign.right,
              textDirection: TextDirection.rtl,
              style: TextStyle(color: pal.ink, fontSize: 19,
                  fontWeight: FontWeight.w700, height: 1.6)),
          const SizedBox(height: 5),
          Text(
            isInflected
                ? 'این بن‌واژه از ساخت صرفی واژه به‌دست آمده و یک پیشنهاد ساختاری است.'
                : 'این واژه در دادهٔ فعلی به‌صورت پایه ثبت شده است.',
            textAlign: TextAlign.right,
            style: TextStyle(color: pal.faint, fontSize: 10.5, height: 1.7),
          ),
          Text('بن‌واژه با خاستگاه تاریخی یا ریشه‌شناسی تطبیقی یکسان نیست.',
              textAlign: TextAlign.right,
              style: TextStyle(color: pal.faint, fontSize: 10.5, height: 1.7)),
        ],
      ),
    );
  }
}

class EtymologyPage extends StatefulWidget {
  final Dictionary dict;
  final String? initialWord;
  final Set<String>? liked;
  final Set<String>? favorites;
  final Future<void> Function(String)? onToggleLike;
  final Future<void> Function(String)? onToggleBookmark;
  const EtymologyPage({
    super.key,
    required this.dict,
    this.initialWord,
    this.liked,
    this.favorites,
    this.onToggleLike,
    this.onToggleBookmark,
  });
  @override
  State<EtymologyPage> createState() => _EtymologyPageState();
}

class _EtymologyPageState extends State<EtymologyPage> {
  final _ctrl = TextEditingController();
  late final List<PersianLexeme> _rows = PersianRoots.index(widget.dict);
  String _query = '';

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWord?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _query = PersianRoots.normalize(initial);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _showLexeme(PersianLexeme row) {
    final related = PersianRoots.sameBase(_rows, row.word);
    final key = 'root:${row.word}';
    final lines = <String>[
      'بن‌واژه: ${row.base}',
      '${faNum(row.sourceCount)} پیوند به مدخل‌های واژگان',
      if (related.length > 1)
        'واژه‌های هم‌بن: ${related.map((item) => item.word).join('، ')}',
      'این بن‌واژه از ساخت صرفی واژه به‌دست آمده و لزوماً خاستگاه تاریخی آن نیست.',
    ];
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: ShareCardData(
              title: row.word,
              lines: lines,
              caption: 'ریشه‌شناسی فارسی · بن‌واژهٔ ساختاری',
            ),
            initialLiked: widget.liked?.contains(key) ?? false,
            initialBookmarked: widget.favorites?.contains(key) ?? false,
            onToggleLike: () async {
              final callback = widget.onToggleLike;
              if (callback != null) await callback(key);
            },
            onToggleBookmark: () async {
              final callback = widget.onToggleBookmark;
              if (callback != null) await callback(key);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = PersianRoots.search(_rows, _query);
    return subScaffold(
      'ریشه‌شناسی فارسی',
      Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: _ctrl,
                onChanged: (value) => setState(
                  () => _query = PersianRoots.normalize(value),
                ),
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.right,
                decoration: InputDecoration(
                  hintText: 'یک واژهٔ فارسی جست‌وجو کنید',
                  prefixIcon: Icon(LucideIcons.search, color: pal.muted, size: 22),
                  filled: true,
                  fillColor: pal.cardC,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(capR(54)),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${faNum(matches.length)} واژهٔ فارسی',
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.muted, fontSize: 12),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: matches.isEmpty
                    ? Center(
                        child: Text(
                          'واژه‌ای در برابرهای فارسی پیدا نشد.',
                          textAlign: TextAlign.right,
                          style: TextStyle(color: pal.muted, height: 1.8),
                        ),
                      )
                    : edgeFade(
                        child: ListView.separated(
                          padding: const EdgeInsets.only(top: 4, bottom: 24),
                          itemCount: matches.length,
                          separatorBuilder: (_, __) =>
                              Divider(height: 1, color: pal.div),
                          itemBuilder: (_, i) {
                            final row = matches[i];
                            return Enter(
                              index: i,
                              child: Pressable(
                                onTap: () => _showLexeme(row),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 4,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(
                                        row.word,
                                        textDirection: TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: pal.ink,
                                          fontSize: 16.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        'بن‌واژه: ${row.base}',
                                        textDirection: TextDirection.rtl,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          color: pal.sel,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
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
      ),
    );
  }
}

// ================= کتابخانهٔ شعر =================

/// Ganjoor static corpus for reading and the official API for full-text
/// poem search and the book catalogue.
class GanjoorData {
  static const _base =
      'https://cdn.jsdelivr.net/gh/ganjoor/ganjoor-data@main/';
  static const _apiBase = 'https://api.ganjoor.net';
  static Future<Map<String, int>>? _statsFuture;
  static const int fallbackPoemCount = 139042;
  static const Map<String, int> fallbackStats = {
    'poets': 245,
    'books': 0,
    'poems': fallbackPoemCount,
  };
  static final Map<String, Future<List<Map<String, dynamic>>>> _poemSearchCache = {};

  static String _cacheName(String path) =>
      'ganjoor_${base64Url.encode(utf8.encode(path))}.json';

  static Future<Map<String, dynamic>> json(String path) async {
    try {
      final packed = await GanjoorPack.readJson(path);
      if (packed != null) return packed;
    } catch (_) {
      // A missing or damaged pack entry must not break the online fallback.
    }
    final cached = await SharedFiles.readJson(_cacheName(path));
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final request = await client.getUrl(Uri.parse('$_base$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close();
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Ganjoor returned HTTP ${response.statusCode}',
            uri: Uri.parse('$_base$path'));
      }
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      try { await SharedFiles.writeJson(_cacheName(path), decoded); } catch (_) {}
      return decoded;
    } catch (_) {
      if (cached != null) return cached;
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static List<Map<String, dynamic>> rows(dynamic value) {
    dynamic list = value;
    if (value is Map) {
      for (final key in ['Poems', 'poems', 'Books', 'books', 'Items',
        'items', 'Results', 'results', 'Data', 'data']) {
        if (value[key] is List) { list = value[key]; break; }
      }
    }
    if (list is! List) return const [];
    return list.whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e)).toList(growable: false);
  }

  static Future<dynamic> _apiJson(String path) async {
    final cacheKey = _cacheName('api_$path');
    final cached = await SharedFiles.readJson(cacheKey);
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 12);
    try {
      final request = await client.getUrl(Uri.parse('$_apiBase/$path'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
          const Duration(seconds: 18));
      final body = await utf8.decoder.bind(response).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw HttpException('Ganjoor API HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(body);
      try { await SharedFiles.writeJson(cacheKey, {'payload': decoded}); }
      catch (_) {}
      return decoded;
    } catch (_) {
      if (cached != null && cached['payload'] != null) return cached['payload'];
      rethrow;
    } finally {
      client.close(force: true);
    }
  }

  static Future<List<Map<String, dynamic>>> bookCatalog() async {
    try {
      final packed = await GanjoorPack.readJson('catalog/books.json');
      if (packed != null) return rows(packed);
    } catch (_) {}
    final data = await _apiJson('api/ganjoor/book-catalog');
    return rows(data);
  }

  static Future<List<Map<String, dynamic>>> searchPoems(String term) {
    final q = term.trim();
    if (q.isEmpty) return Future.value(const []);
    return _poemSearchCache.putIfAbsent(q, () async {
      final uri = Uri(
        path: '/api/ganjoor/poems/search',
        queryParameters: {'term': q, 'page': '1', 'pageSize': '40'},
      );
      final data = await _apiJson(uri.toString().replaceFirst('/', ''));
      return rows(data);
    });
  }

  static Future<List<Map<String, dynamic>>> searchPoemsForTerms(
    List<String> terms,
  ) async {
    final uniqueTerms = terms.map((e) => e.trim())
        .where((e) => e.isNotEmpty).toSet().take(3).toList();
    if (uniqueTerms.isEmpty) return const [];
    final groups = await Future.wait(uniqueTerms.map(searchPoems));
    final merged = <String, Map<String, dynamic>>{};
    for (final group in groups) {
      for (final poem in group) {
        final key = (poem['FullUrl'] ?? poem['fullUrl'] ??
            poem['Title'] ?? poem['title'] ?? '').toString();
        if (key.isNotEmpty) merged.putIfAbsent(key, () => poem);
      }
    }
    return merged.values.take(5).toList(growable: false);
  }

  static Future<Map<String, int>> stats() =>
      _statsFuture ??= _loadStats();

  static int _manifestCount(
    Map<String, dynamic> manifest,
    List<String> keys, {
    required int fallback,
  }) {
    for (final key in keys) {
      final raw = manifest[key];
      final value = raw is num
          ? raw.toInt()
          : int.tryParse(raw?.toString().replaceAll(',', '').trim() ?? '');
      if (value != null && value > 0) return value;
    }
    return fallback;
  }

  static Future<Map<String, int>> _loadStats() async {
    var poets = fallbackStats['poets']!;
    var books = fallbackStats['books']!;
    var poems = fallbackPoemCount;
    try {
      final manifest = await json('manifest.json');
      poets = _manifestCount(
        manifest,
        const ['PoetsCount', 'poetsCount'],
        fallback: rows(manifest['Poets'] ?? manifest['poets']).length,
      );
      poems = _manifestCount(
        manifest,
        const [
          'PoemsCount',
          'poemsCount',
          'PoemCount',
          'poemCount',
          'TotalPoems',
          'totalPoems',
        ],
        fallback: fallbackPoemCount,
      );
    } catch (_) {
      // Keep the last published corpus count instead of replacing it with 0.
    }
    try {
      books = (await bookCatalog()).length;
    } catch (_) {}
    return {'poets': poets, 'books': books, 'poems': poems};
  }
}

class _PoemUsageCard extends StatelessWidget {
  final List<String> words;
  final String title;
  const _PoemUsageCard({
    required this.words,
    this.title = 'شعرهایی که این واژه در آن‌ها آمده',
  });

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: GanjoorData.searchPoemsForTerms(words),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done ||
            !snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }
        final poems = snapshot.data!.take(3).toList();
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.cardC,
            borderRadius: BorderRadius.circular(capR(54)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(title,
                  textAlign: TextAlign.right,
                  style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700,
                      fontSize: 13.5)),
              const SizedBox(height: 6),
              for (final poem in poems)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    poem['Title']?.toString() ?? poem['title']?.toString() ?? 'شعر',
                    textAlign: TextAlign.right,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pal.ink, fontSize: 12.5),
                  ),
                  subtitle: Text(
                    poem['PoetName']?.toString() ??
                        poem['PoetNickname']?.toString() ??
                        poem['poetName']?.toString() ?? '',
                    textAlign: TextAlign.right,
                    style: TextStyle(color: pal.muted, fontSize: 11),
                  ),
                  trailing: Icon(LucideIcons.chevronLeft,
                      size: 16, color: pal.muted),
                  onTap: () {
                    final full = (poem['FullUrl'] ?? poem['fullUrl'] ?? '')
                        .toString().replaceFirst(RegExp(r'^/'), '');
                    if (full.isEmpty) return;
                    Navigator.of(context).push(_softRoute(GanjoorPoemPage(
                      title: poem['Title']?.toString() ?? 'شعر',
                      path: 'poets/$full.json',
                    )));
                  },
                ),
            ],
          ),
        );
      },
    );
  }
}

class GanjoorPage extends StatefulWidget {
  final Dictionary? dictionary;
  final Set<String>? liked;
  final Set<String>? favorites;
  final Future<void> Function(String)? onToggleLike;
  final Future<void> Function(String)? onToggleBookmark;
  final void Function(Entry)? onOpenEntry;

  const GanjoorPage({
    super.key,
    this.dictionary,
    this.liked,
    this.favorites,
    this.onToggleLike,
    this.onToggleBookmark,
    this.onOpenEntry,
  });
  @override
  State<GanjoorPage> createState() => _GanjoorPageState();
}

class _GanjoorPageState extends State<GanjoorPage> {
  late Future<Map<String, dynamic>> _manifest = GanjoorData.json('manifest.json');
  late final Future<List<Map<String, dynamic>>> _books = GanjoorData.bookCatalog();
  String _query = '';
  int _filter = 0; // poets, books
  int _view = 0; // list, two columns, cards

  String _value(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key];
      if (value != null && value.toString().trim().isNotEmpty) return value.toString();
    }
    return '';
  }

  bool _matches(Map<String, dynamic> row, String query) {
    if (query.isEmpty) return true;
    return row.values.any((v) => v != null &&
        v.toString().toLowerCase().contains(query.toLowerCase()));
  }

  void _queryChanged(String value) {
    setState(() => _query = value.trim());
  }

  Future<void> _manageOfflinePack() async {
    var installed = await GanjoorPack.isInstalled();
    if (!mounted) return;
    var downloading = false;
    var received = 0;
    var total = 0;
    String? error;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          backgroundColor: pal.cardC,
          title: Text('محتوای آفلاین گنجور',
              textAlign: TextAlign.right,
              style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                installed
                    ? 'بستهٔ شعر روی دستگاه نصب است. فایل فشرده باقی می‌ماند و فقط قطعهٔ لازم هنگام خواندن باز می‌شود.'
                    : 'با دانلود این بسته، متن شعرها و فهرست کتاب‌ها از حافظهٔ دستگاه خوانده می‌شوند؛ کل دیتابیس استخراج نمی‌شود.',
                textAlign: TextAlign.right,
                style: TextStyle(color: pal.muted, height: 1.8),
              ),
              if (downloading) ...[
                const SizedBox(height: 16),
                LinearProgressIndicator(
                  value: total > 0 ? received / total : null,
                  color: pal.sel,
                  backgroundColor: pal.div,
                ),
                const SizedBox(height: 8),
                Text(
                  total > 0
                      ? '${(received / (1024 * 1024)).toStringAsFixed(1)} از ${(total / (1024 * 1024)).toStringAsFixed(1)} مگابایت'
                      : 'در حال دریافت…',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, fontSize: 11),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                Text(error!, textAlign: TextAlign.right,
                    style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
          actions: [
            if (installed && !downloading)
              TextButton(
                onPressed: () async {
                  await GanjoorPack.remove();
                  if (dialogContext.mounted) Navigator.pop(dialogContext);
                  if (mounted) setState(() {});
                },
                child: const Text('حذف بسته'),
              ),
            TextButton(
              onPressed: downloading ? null : () => Navigator.pop(dialogContext),
              child: const Text('بستن'),
            ),
            FilledButton(
              onPressed: downloading
                  ? null
                  : () async {
                      setDialogState(() {
                        downloading = true;
                        received = 0;
                        total = 0;
                        error = null;
                      });
                      try {
                        await GanjoorPack.download(
                          onProgress: (value, length) {
                            if (!dialogContext.mounted) return;
                            setDialogState(() {
                              received = value;
                              total = length;
                            });
                          },
                        );
                        installed = true;
                        if (dialogContext.mounted) Navigator.pop(dialogContext);
                        if (mounted) setState(() {});
                      } catch (e) {
                        if (dialogContext.mounted) {
                          setDialogState(() {
                            error = 'دانلود بسته انجام نشد: $e';
                          });
                        }
                      } finally {
                        if (dialogContext.mounted) {
                          setDialogState(() => downloading = false);
                        }
                      }
                    },
              child: Text(installed ? 'به‌روزرسانی' : 'دانلود بسته'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSourceInfo() {
    showTopBanner(
      context,
      title: 'داده‌های کتابخانهٔ شعر',
      message: 'با نصب بسته، متن‌ها و فهرست کتاب‌ها از فایل فشردهٔ محلی خوانده می‌شوند. در نبود بسته، مسیر آنلاین فعلی حفظ می‌شود؛ جست‌وجوی متن شعر همچنان از API گنجور است.',
    );
  }

  void _openPoet(Map<String, dynamic> poet) {
    final full = _value(poet, ['FullUrl', 'fullUrl', 'Url', 'url']);
    if (full.isEmpty) return;
    Navigator.of(context).push(_softRoute(GanjoorNodePage(
      title: _value(poet, ['Nickname', 'nickname', 'Name', 'name']).isEmpty
          ? 'شاعر' : _value(poet, ['Nickname', 'nickname', 'Name', 'name']),
      path: full.replaceFirst(RegExp(r'^/'), ''),
      dictionary: widget.dictionary,
      liked: widget.liked,
      favorites: widget.favorites,
      onToggleLike: widget.onToggleLike,
      onToggleBookmark: widget.onToggleBookmark,
      onOpenEntry: widget.onOpenEntry,
    )));
  }

  void _openBook(Map<String, dynamic> book) {
    final full = _value(book, ['FullUrl', 'fullUrl', 'Url', 'url']);
    if (full.isEmpty) return;
    Navigator.of(context).push(_softRoute(GanjoorNodePage(
      title: _value(book, ['Title', 'title', 'Name', 'name']).isEmpty
          ? 'کتاب' : _value(book, ['Title', 'title', 'Name', 'name']),
      path: full.replaceFirst(RegExp(r'^/'), ''),
      dictionary: widget.dictionary,
      liked: widget.liked,
      favorites: widget.favorites,
      onToggleLike: widget.onToggleLike,
      onToggleBookmark: widget.onToggleBookmark,
      onOpenEntry: widget.onOpenEntry,
    )));
  }

  Widget _resultTile({
    required Map<String, dynamic> item,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    if (_view == 2) {
      return Pressable(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.cardC,
            borderRadius: BorderRadius.circular(capR(52)),
            border: Border.all(color: pal.div.withValues(alpha: .7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(icon, color: pal.sel, size: 20),
              const SizedBox(height: 8),
              Text(title, textAlign: TextAlign.right, maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700)),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(subtitle, textAlign: TextAlign.right, maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: pal.muted, fontSize: 11.5)),
              ],
            ],
          ),
        ),
      );
    }
    return Pressable(
      onTap: onTap,
      child: Container(
        height: _view == 1 ? 76 : 64,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: _view == 1 ? pal.cardC : Colors.transparent,
          borderRadius: BorderRadius.circular(capR(49)),
          border: _view == 1 ? Border.all(color: pal.div) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: pal.sel, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(title, textAlign: TextAlign.right, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: pal.ink, fontWeight: FontWeight.w600)),
                  if (subtitle.isNotEmpty)
                    Text(subtitle, textAlign: TextAlign.right, maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: pal.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(LucideIcons.chevronLeft, color: pal.muted, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _section(
    String title,
    List<Map<String, dynamic>> items,
    IconData icon,
    String Function(Map<String, dynamic>) titleOf,
    String Function(Map<String, dynamic>) subtitleOf,
    void Function(Map<String, dynamic>) onTap,
  ) {
    if (items.isEmpty) return const SizedBox.shrink();
    final grid = _view != 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
          child: Row(
            children: [
              Text(title, textAlign: TextAlign.right,
                  style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700,
                      fontSize: 14)),
              const Spacer(),
              Text(faNum(items.length),
                  style: TextStyle(color: pal.faint, fontSize: 11)),
            ],
          ),
        ),
        if (grid)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: _view == 1 ? 2 : 1,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              mainAxisExtent: _view == 1 ? 82 : 112,
            ),
            itemBuilder: (_, i) => _resultTile(
              item: items[i],
              title: titleOf(items[i]),
              subtitle: subtitleOf(items[i]),
              icon: icon,
              onTap: () => onTap(items[i]),
            ),
          )
        else
          ...items.map((item) => _resultTile(
            item: item,
            title: titleOf(item),
            subtitle: subtitleOf(item),
            icon: icon,
            onTap: () => onTap(item),
          )),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: pal.bg,
      body: SafeArea(
        child: Directionality(
          textDirection: TextDirection.rtl,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
                child: Row(
                  children: [
                    const BackIconButton(),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'کتابخانهٔ شعر',
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: TextStyle(
                          color: pal.ink,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'محتوای آفلاین',
                      onPressed: _manageOfflinePack,
                      icon: Icon(LucideIcons.download, color: pal.muted, size: 20),
                    ),
                    IconButton(
                      tooltip: 'دربارهٔ منبع',
                      onPressed: _showSourceInfo,
                      icon: Icon(LucideIcons.info, color: pal.muted, size: 20),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: TextField(
                  onChanged: _queryChanged,
                  textDirection: TextDirection.rtl,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'جست‌وجو در شاعر و کتاب',
                    prefixIcon: Icon(LucideIcons.search, color: pal.muted),
                    filled: true,
                    fillColor: pal.cardC,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(capR(54)),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
                child: Row(
                  children: [
                    for (var i = 0; i < 2; i++)
                      Expanded(
                        child: Pressable(
                          onTap: () => setState(() => _filter = i),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Text(
                              ['شاعران', 'کتاب‌ها'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _filter == i
                                    ? pal.ink
                                    : pal.muted.withValues(alpha: 0.62),
                                fontSize: 12,
                                fontWeight: _filter == i
                                    ? FontWeight.w800
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 8),
                child: Row(
                  children: [
                    Text(
                      ['فهرست', 'دوستونه', 'کاشی‌ای'][_view],
                      style: TextStyle(color: pal.muted, fontSize: 11),
                    ),
                    const Spacer(),
                    for (var i = 0; i < 3; i++)
                      Pressable(
                        onTap: () => setState(() => _view = i),
                        child: AnimatedContainer(
                          duration: Motion.base,
                          curve: Motion.spring,
                          margin: const EdgeInsets.only(left: 7),
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: _view == i ? pal.pillC : Colors.transparent,
                            borderRadius: BorderRadius.circular(capR(54)),
                          ),
                          child: Icon(
                            [LucideIcons.list, LucideIcons.grid3x3,
                              LucideIcons.panelLeft][i],
                            size: 18,
                            color: _view == i ? pal.sel : pal.muted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: FutureBuilder<Map<String, dynamic>>(
                  future: _manifest,
                  builder: (context, manifestSnapshot) {
                    if (manifestSnapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!manifestSnapshot.hasData || manifestSnapshot.hasError) {
                      return _ganjoorError(
                        'دریافت فهرست شاعران انجام نشد.',
                        () => setState(() => _manifest = GanjoorData.json('manifest.json')),
                      );
                    }
                    final poets = GanjoorData.rows(
                      manifestSnapshot.data!['Poets'],
                    ).where((p) => _matches(p, _query)).toList();
                    return FutureBuilder<List<Map<String, dynamic>>>(
                      future: _books,
                      builder: (context, bookSnapshot) {
                        if (_filter == 1 &&
                            bookSnapshot.connectionState != ConnectionState.done) {
                          return const Center(child: CircularProgressIndicator());
                        }
                        final books = (bookSnapshot.data ??
                                const <Map<String, dynamic>>[])
                            .where((b) => _matches(b, _query))
                            .toList();
                        final showingPoets = _filter == 0;
                        final visibleCount = showingPoets ? poets.length : books.length;
                        if (visibleCount == 0) {
                          return Center(
                            child: Text(
                              showingPoets ? 'شاعری پیدا نشد' : 'کتابی پیدا نشد',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: pal.muted),
                            ),
                          );
                        }
                        return edgeFade(
                          child: ListView(
                            padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                            children: [
                              if (showingPoets)
                                _section(
                                  'شاعران',
                                  poets,
                                  LucideIcons.user,
                                  (p) => _value(p, [
                                    'Nickname', 'nickname', 'Name', 'name',
                                  ]),
                                  (p) => _value(p, [
                                    'Bio', 'bio', 'Period', 'period',
                                  ]),
                                  _openPoet,
                                )
                              else
                                _section(
                                  'کتاب‌ها و مجموعه‌ها',
                                  books,
                                  LucideIcons.notebookPen,
                                  (b) => _value(b, [
                                    'Title', 'title', 'Name', 'name',
                                  ]),
                                  (b) => _value(b, [
                                    'PoetName', 'PoetNickname', 'poetName',
                                  ]),
                                  _openBook,
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget _ganjoorBreadcrumb(
  BuildContext context, {
  required String fullTitle,
  required String path,
  Dictionary? dictionary,
  Set<String>? liked,
  Set<String>? favorites,
  Future<void> Function(String)? onToggleLike,
  Future<void> Function(String)? onToggleBookmark,
  void Function(Entry)? onOpenEntry,
}) {
  final titles = fullTitle
      .split(RegExp(r'\s*[»›>]+\s*'))
      .where((part) => part.trim().isNotEmpty)
      .toList();
  var cleanPath = path.replaceFirst(RegExp(r'^/'), '');
  if (cleanPath.startsWith('poets/')) {
    cleanPath = cleanPath.substring('poets/'.length);
  }
  cleanPath = cleanPath.replaceFirst(RegExp(r'\.json$'), '');
  final segments = cleanPath
      .split('/')
      .where((part) => part.trim().isNotEmpty)
      .toList();

  return SizedBox(
    height: 24,
    child: SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < titles.length; i++) ...[
            if (i < titles.length - 1 && i < segments.length - 1)
              Pressable(
                onTap: () {
                  final target = segments.take(i + 1).join('/');
                  Navigator.of(context).pushAndRemoveUntil(
                    _softRoute(
                      GanjoorNodePage(
                        title: titles[i],
                        path: target,
                        dictionary: dictionary,
                        liked: liked,
                        favorites: favorites,
                        onToggleLike: onToggleLike,
                        onToggleBookmark: onToggleBookmark,
                        onOpenEntry: onOpenEntry,
                      ),
                    ),
                    (route) => route.isFirst,
                  );
                },
                child: Text(
                  titles[i],
                  textDirection: TextDirection.rtl,
                  style: TextStyle(
                    color: pal.sel,
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Text(
                titles[i],
                textDirection: TextDirection.rtl,
                style: TextStyle(
                  color: pal.muted,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            if (i < titles.length - 1)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Icon(
                  LucideIcons.chevronLeft,
                  color: pal.faint,
                  size: 12,
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class GanjoorNodePage extends StatefulWidget {
  final String title;
  final String path;
  final int depth;
  final Dictionary? dictionary;
  final Set<String>? liked;
  final Set<String>? favorites;
  final Future<void> Function(String)? onToggleLike;
  final Future<void> Function(String)? onToggleBookmark;
  final void Function(Entry)? onOpenEntry;

  const GanjoorNodePage({
    super.key,
    required this.title,
    required this.path,
    this.depth = 0,
    this.dictionary,
    this.liked,
    this.favorites,
    this.onToggleLike,
    this.onToggleBookmark,
    this.onOpenEntry,
  });
  @override
  State<GanjoorNodePage> createState() => _GanjoorNodePageState();
}

class _GanjoorNodePageState extends State<GanjoorNodePage> {
  late Future<Map<String, dynamic>> _future = _load();
  bool _bookLiked = false;
  bool _bookmarked = false;

  @override
  void initState() {
    super.initState();
    final key = 'book:${widget.path}';
    _bookLiked = widget.liked?.contains(key) ?? false;
    _bookmarked = widget.favorites?.contains(key) ?? false;
  }

  Future<Map<String, dynamic>> _load() =>
      GanjoorData.json('poets/${widget.path}/_cat.json');

  void _openCategory(Map<String, dynamic> category) {
    final path = category['FullUrl']?.toString() ?? '';
    if (path.isEmpty) return;
    Navigator.of(context).push(
      _softRoute(
        GanjoorNodePage(
          title: category['Title']?.toString() ?? 'مجموعه',
          path: path.replaceFirst(RegExp(r'^/'), ''),
          depth: widget.depth + 1,
          dictionary: widget.dictionary,
          liked: widget.liked,
          favorites: widget.favorites,
          onToggleLike: widget.onToggleLike,
          onToggleBookmark: widget.onToggleBookmark,
          onOpenEntry: widget.onOpenEntry,
        ),
      ),
    );
  }

  void _openPoem(Map<String, dynamic> poem) {
    final path = poem['FullUrl']?.toString() ?? '';
    if (path.isEmpty) return;
    Navigator.of(context).push(
      _softRoute(
        GanjoorPoemPage(
          title: poem['Title']?.toString() ?? 'شعر',
          path: 'poets/${path.replaceFirst(RegExp(r'^/'), '')}.json',
          dictionary: widget.dictionary,
          liked: widget.liked,
          favorites: widget.favorites,
          onToggleLike: widget.onToggleLike,
          onToggleBookmark: widget.onToggleBookmark,
          onOpenEntry: widget.onOpenEntry,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      widget.title,
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ganjoorError(
              'بارگذاری این بخش انجام نشد.',
              () => setState(() => _future = _load()),
            );
          }
          final data = snapshot.data!;
          final fullTitle = data['FullTitle']?.toString() ?? widget.title;
          final categories = (data['ChildCats'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final poems = (data['Poems'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: _ganjoorBreadcrumb(
                          context,
                          fullTitle: fullTitle,
                          path: widget.path,
                          dictionary: widget.dictionary,
                          liked: widget.liked,
                          favorites: widget.favorites,
                          onToggleLike: widget.onToggleLike,
                          onToggleBookmark: widget.onToggleBookmark,
                          onOpenEntry: widget.onOpenEntry,
                        ),
                      ),
                    ),
                    if (widget.depth == 1) ...[
                      const SizedBox(width: 8),
                      LikeBookmarkButtons(
                        liked: _bookLiked,
                        bookmarked: _bookmarked,
                        onToggleLike: () async {
                          setState(() => _bookLiked = !_bookLiked);
                          await widget.onToggleLike?.call('book:${widget.path}');
                        },
                        onToggleBookmark: () async {
                          setState(() => _bookmarked = !_bookmarked);
                          await widget.onToggleBookmark?.call('book:${widget.path}');
                        },
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(
                child: edgeFade(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, kNavClearance),
                    children: [
                      if ((data['Description']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Text(
                            data['Description'].toString(),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: pal.muted,
                              height: 1.9,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      for (var i = 0; i < categories.length; i++)
                        Enter(
                          index: i,
                          child: ListTile(
                            leading: Icon(LucideIcons.folder, color: pal.sel),
                            title: Text(
                              categories[i]['Title']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(color: pal.ink),
                            ),
                            trailing: Icon(
                              LucideIcons.chevronLeft,
                              color: pal.muted,
                              size: 18,
                            ),
                            onTap: () => _openCategory(categories[i]),
                          ),
                        ),
                      if (categories.isNotEmpty && poems.isNotEmpty)
                        Divider(height: 18, color: pal.div),
                      for (var i = 0; i < poems.length; i++)
                        Enter(
                          index: categories.length + i,
                          child: ListTile(
                            leading: Icon(LucideIcons.fileText, color: pal.muted),
                            title: Text(
                              poems[i]['Title']?.toString() ?? '',
                              textAlign: TextAlign.right,
                              textDirection: TextDirection.rtl,
                              style: TextStyle(color: pal.ink),
                            ),
                            trailing: Icon(
                              LucideIcons.chevronLeft,
                              color: pal.muted,
                              size: 18,
                            ),
                            onTap: () => _openPoem(poems[i]),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class GanjoorPoemPage extends StatefulWidget {
  final String title;
  final String path;
  final Dictionary? dictionary;
  final Set<String>? liked;
  final Set<String>? favorites;
  final Future<void> Function(String)? onToggleLike;
  final Future<void> Function(String)? onToggleBookmark;
  final void Function(Entry)? onOpenEntry;

  const GanjoorPoemPage({
    super.key,
    required this.title,
    required this.path,
    this.dictionary,
    this.liked,
    this.favorites,
    this.onToggleLike,
    this.onToggleBookmark,
    this.onOpenEntry,
  });
  @override
  State<GanjoorPoemPage> createState() => _GanjoorPoemPageState();
}

class _GanjoorPoemPageState extends State<GanjoorPoemPage> {
  late Future<Map<String, dynamic>> _future =
      GanjoorData.json(widget.path);

  String _normalizeVerseToken(String value) => value
      .replaceAll('ي', 'ی')
      .replaceAll('ك', 'ک')
      .replaceAll(String.fromCharCode(0x200c), '')
      .trim();

  List<Entry> _relatedEntries(String text) {
    final dictionary = widget.dictionary;
    if (dictionary == null) return const [];
    final tokens = text
        .split(RegExp(r'[\s،؛,.!?؟:()«»\[\]{}…]+'))
        .map(_normalizeVerseToken)
        .where((word) => word.length >= 3)
        .toSet();
    if (tokens.isEmpty) return const [];
    return dictionary.entries.where((entry) {
      if (tokens.contains(_normalizeVerseToken(entry.ar))) return true;
      return entry.fa.any((meaning) {
        final normalized = _normalizeVerseToken(meaning);
        if (tokens.contains(normalized)) return true;
        return normalized
            .split(RegExp(r'[\s،؛,.!?؟:()«»]+'))
            .any(tokens.contains);
      });
    }).take(8).toList(growable: false);
  }

  Future<void> _toggleLocalContent(String file, String key) async {
    final current = await SharedFiles.readJson(file);
    final values = ((current?['words'] as List?) ?? const [])
        .map((value) => value.toString())
        .toSet();
    values.contains(key) ? values.remove(key) : values.add(key);
    await SharedFiles.writeJson(file, {'words': values.toList()});
  }

  void _showCouplet(
    int index,
    List<String> lines, {
    String? meaning,
    String? breadcrumb,
  }) {
    final key = 'poem:${widget.path}#$index';
    final related = _relatedEntries(lines.join(' '));
    final path = (breadcrumb ?? widget.title).replaceAll(' » ', ' > ');
    final summary = meaning?.trim();
    final card = ShareCardData(
      title: lines.join('\n'),
      lines: const [],
      breadcrumb: path,
      meaning: summary == null || summary.isEmpty ? null : summary,
      caption: 'بیت ${faNum(index + 1)} · گنجور',
    );
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * .92,
        ),
        child: SingleChildScrollView(
          child: DetailSheet(
            card: card,
            initialLiked: widget.liked?.contains(key) ?? false,
            initialBookmarked: widget.favorites?.contains(key) ?? false,
            onToggleLike: () async {
              final callback = widget.onToggleLike;
              if (callback != null) {
                await callback(key);
              } else {
                await _toggleLocalContent('liked.json', key);
              }
            },
            onToggleBookmark: () async {
              final callback = widget.onToggleBookmark;
              if (callback != null) {
                await callback(key);
              } else {
                await _toggleLocalContent('favorites.json', key);
              }
            },
            relatedEntries: related,
            copyableLines: lines,
            onOpenRelatedEntry: widget.onOpenEntry == null
                ? null
                : (entry) {
                    Navigator.of(sheetContext).pop();
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      widget.onOpenEntry?.call(entry);
                    });
                  },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return subScaffold(
      widget.title,
      FutureBuilder<Map<String, dynamic>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ganjoorError(
              'دریافت شعر انجام نشد.',
              () => setState(() => _future = GanjoorData.json(widget.path)),
            );
          }
          final data = snapshot.data!;
          final fullTitle = data['FullTitle']?.toString() ?? widget.title;
          final verses = (data['Verses'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final couplets = <int, List<String>>{};
          final coupletMeanings = <int, String>{};
          for (final verse in verses) {
            final index = (verse['CoupletIndex'] as num?)?.toInt() ?? -1;
            if (index < 0) continue;
            couplets.putIfAbsent(index, () => <String>[]);
            couplets[index]!.add(verse['Text']?.toString() ?? '');
            final summary = verse['CoupletSummary']?.toString().trim();
            if (summary != null && summary.isNotEmpty) {
              coupletMeanings.putIfAbsent(index, () => summary);
            }
          }
          final ordered = couplets.keys.toList()..sort();
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: _ganjoorBreadcrumb(
                    context,
                    fullTitle: fullTitle,
                    path: widget.path,
                    dictionary: widget.dictionary,
                    liked: widget.liked,
                    favorites: widget.favorites,
                    onToggleLike: widget.onToggleLike,
                    onToggleBookmark: widget.onToggleBookmark,
                    onOpenEntry: widget.onOpenEntry,
                  ),
                ),
              ),
              Expanded(
                child: edgeFade(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(22, 10, 22, kNavClearance),
                    children: [
                      if ((data['PoemSummary']?.toString() ?? '').isNotEmpty)
                        Container(
                          width: double.infinity,
                          margin: const EdgeInsets.only(bottom: 18),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: pal.cardC,
                            borderRadius: BorderRadius.circular(capR(54)),
                          ),
                          child: Text(
                            data['PoemSummary'].toString(),
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(
                              color: pal.muted,
                              height: 1.9,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      if (data['Metre'] is Map &&
                          (data['Metre']['Rhythm']?.toString() ?? '').isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: Text(
                            'وزن: ${data['Metre']['Rhythm']}',
                            textAlign: TextAlign.right,
                            textDirection: TextDirection.rtl,
                            style: TextStyle(color: pal.faint, fontSize: 12),
                          ),
                        ),
                      for (var i = 0; i < ordered.length; i++)
                        Enter(
                          index: i,
                          child: Hero(
                            tag: 'poem:${widget.path}#${ordered[i]}',
                            child: Material(
                              type: MaterialType.transparency,
                              child: InkWell(
                                onTap: () => _showCouplet(
                                  ordered[i],
                                  couplets[ordered[i]]!,
                                  meaning: coupletMeanings[ordered[i]],
                                  breadcrumb: fullTitle,
                                ),
                                borderRadius: BorderRadius.circular(capR(52)),
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.pillC,
                                    borderRadius: BorderRadius.circular(capR(52)),
                                  ),
                                  child: Column(
                                    children: [
                                      Text(
                                        couplets[ordered[i]]!.first,
                                        textAlign: TextAlign.center,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          color: pal.ink,
                                          fontSize: 16,
                                          height: 1.9,
                                        ),
                                      ),
                                      if (couplets[ordered[i]]!.length > 1) ...[
                                        const SizedBox(height: 4),
                                        Text(
                                          couplets[ordered[i]]![1],
                                          textAlign: TextAlign.center,
                                          textDirection: TextDirection.rtl,
                                          style: TextStyle(
                                            color: pal.ink,
                                            fontSize: 16,
                                            height: 1.9,
                                          ),
                                        ),
                                      ],
                                      if ((coupletMeanings[ordered[i]] ?? '').isNotEmpty) ...[
                                        const SizedBox(height: 8),
                                        Text(
                                          coupletMeanings[ordered[i]]!,
                                          textAlign: TextAlign.right,
                                          textDirection: TextDirection.rtl,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: pal.muted,
                                            fontSize: 12,
                                            height: 1.65,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Text(
                        'متن شعر از گنجور — github.com/hrmoh',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: pal.faint, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

Widget _ganjoorError(String message, VoidCallback retry) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.cloud, size: 30, color: pal.muted),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(color: pal.muted, height: 1.8),
          ),
          const SizedBox(height: 14),
          TextButton.icon(
            onPressed: retry,
            icon: Icon(LucideIcons.refreshCw, color: pal.sel),
            label: const Text('تلاش دوباره'),
          ),
        ],
      ),
    ),
  );
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
              'چیدمان و بازخورد لمسی کیبورد سورن با الهام از Samsung Keyboard بازطراحی شده است:\n\n'
              '• نوار بالا هنگام تایپ جای خود را به پیشنهادها می‌دهد و با پیکان برمی‌گردد.\n'
              '• هنگام زدن فاصله یا اینتر، اصلاح و جایگزینی خودکار انجام می‌شود: میخام ← می‌خوام، سوال ← پرسش.\n'
              '• روی هر کلید نگه دارید: پنجره‌ای بالای کلید باز می‌شود با همهٔ نویسه‌های لایهٔ شیفت و خویشاوندهای آن کلید؛ انگشت را بکشید و رها کنید تا همان نویسه بنشیند.\n'
              '• کلید شیفت لایهٔ اعراب و شکل‌های عربی/همزه‌دار را روی کلیدها نشان می‌دهد؛ نگه‌داشتنش لایه را قفل می‌کند.\n'
              '• برای انگلیسی، روی کلید فاصله به چپ یا راست بکشید؛ زبان عوض می‌شود. نگه‌داشتن فاصله آن را به صفحهٔ حرکتِ نشانگر تبدیل می‌کند.\n'
              '• کلید نیم‌فاصله در ردیف پایین است؛ نگه‌داشتنش «چسبان» (ZWJ) می‌دهد.\n• رقم‌های عربی‌هندی نیز در صورت روشن‌بودن جایگزینی، به رقم‌های فارسی تبدیل می‌شوند.\n'
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
              style: FilledButton.styleFrom(
                backgroundColor: pal.sel,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: () => SharedFiles.openInputSettings(),
              child: const Text('بازکردن تنظیمات کیبورد اندروید'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              style: OutlinedButton.styleFrom(side: BorderSide(color: pal.div)),
              onPressed: () => SharedFiles.showKeyboardPicker(),
              child: const Text('برگزیدن کیبورد کنونی'),
            ),
          ],
        ),
      ),
    );
  }
}
