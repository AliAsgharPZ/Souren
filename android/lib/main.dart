import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'lucide.dart';
import 'share.dart';

import 'data/store.dart';
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

/// Motion language (Claude-inspired feel, Souren's own numbers): one place
/// for every duration/curve so entrances, toggles and transitions match.
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

PageRoute<T> _softRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: Motion.slow,
  reverseTransitionDuration: Motion.base,
  pageBuilder: (_, __, ___) => page,
  transitionsBuilder: (context, animation, secondaryAnimation, child) {
    if (MediaQuery.of(context).disableAnimations) return child;
    final curved = CurvedAnimation(
      parent: animation,
      curve: Motion.curve,
      reverseCurve: Curves.easeInOutCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.028),
          end: Offset.zero,
        ).animate(curved),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.975, end: 1.0).animate(curved),
          child: child,
        ),
      ),
    );
  },
);

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

/// Scroll-aware top+bottom fade, shared by every scrollable list in
/// the app. The fade zones are long and soft (16% of the viewport,
/// eased multi-stop gradient) and start right at the viewport's top
/// and bottom edges. The TOP fade is hidden at offset 0 and fades in
/// smoothly over the first ~48px of scrolling, so a fresh page shows
/// its first rows at full strength.
class ScrollFade extends StatefulWidget {
  final Widget child;
  const ScrollFade({super.key, required this.child});
  @override
  State<ScrollFade> createState() => _ScrollFadeState();
}

class _ScrollFadeState extends State<ScrollFade> {
  double _top = 0;
  double _bottom = 0;

  void _onScroll(ScrollNotification n) {
    if (n is ScrollUpdateNotification || n is OverscrollNotification) {
      final progress = (n.metrics.pixels / 96).clamp(0.0, 1.0);
      // Smoothstep avoids a sudden fade when the finger first moves.
      final eased = progress * progress * (3 - 2 * progress);
      final top = eased;
      final bottom = n.metrics.extentAfter > 1 ? eased : 0.0;
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
        shaderCallback: (rect) => LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.fromRGBO(0, 0, 0, 1 - _top),
            Color.fromRGBO(0, 0, 0, 1 - _top * 0.55),
            Colors.black,
            Colors.black,
            Color.fromRGBO(0, 0, 0, 1 - _bottom * 0.55),
            Color.fromRGBO(0, 0, 0, 1 - _bottom),
          ],
          stops: const [0, 0.10, 0.22, 0.78, 0.90, 1],
        ).createShader(rect),
        blendMode: BlendMode.dstIn,
        child: widget.child,
      ),
    );
  }
}

/// The name every scrollable in the app already wraps in; the
/// implementation is now the scroll-aware ScrollFade.
Widget edgeFade({required Widget child}) => ScrollFade(child: child);

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

class _PressableState extends State<Pressable> {
  bool _pressed = false;

  void _set(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
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
      onTap: widget.onTap,
      onLongPress: widget.onLongPress ?? widget.onTap,
      child: AnimatedScale(
        scale: reduceMotion ? 1.0 : (_pressed ? widget.scale : 1.0),
        duration: duration,
        curve: _pressed ? Curves.easeOut : Motion.spring,
        child: AnimatedOpacity(
          opacity: reduceMotion ? 1.0 : (_pressed ? 0.82 : 1.0),
          duration: duration,
          child: widget.child,
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
      child: PopIcon(
        active: active,
        child: Icon(icon, size: 21, color: active ? activeColor : inactive),
      ),
    ),
  );
}

/// Like + bookmark, side by side, everywhere (round 3): outline
/// icons only; the like count lives in a fixed-width slot that is
/// always present, so liking a word never shifts the row layout.
class LikeBookmarkButtons extends StatelessWidget {
  final bool liked;
  final bool bookmarked;
  final int likeCount;
  final VoidCallback onToggleLike;
  final VoidCallback onToggleBookmark;
  const LikeBookmarkButtons({
    super.key,
    required this.liked,
    required this.bookmarked,
    this.likeCount = 0,
    required this.onToggleLike,
    required this.onToggleBookmark,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        pressIcon(
          active: liked,
          icon: LucideIcons.heart,
          activeColor: pal.accent,
          onTap: onToggleLike,
        ),
        pressIcon(
          active: bookmarked,
          icon: LucideIcons.bookmark,
          activeColor: pal.ink,
          onTap: onToggleBookmark,
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
  final int likeCount;
  final Future<void> Function() onToggleLike;
  final Future<void> Function() onToggleBookmark;
  final VoidCallback? onOpenEtymology;
  final String? etymologyWord;
  final List<String> relatedPersianWords;
  const DetailSheet({
    super.key,
    required this.card,
    required this.initialLiked,
    required this.initialBookmarked,
    this.likeCount = 0,
    required this.onToggleLike,
    required this.onToggleBookmark,
    this.onOpenEtymology,
    this.etymologyWord,
    this.relatedPersianWords = const [],
  });
  @override
  State<DetailSheet> createState() => _DetailSheetState();
}

class _DetailSheetState extends State<DetailSheet> {
  late bool _liked = widget.initialLiked;
  late bool _bookmarked = widget.initialBookmarked;
  late int _count = widget.likeCount;

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
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  widget.card.title,
                  style: const TextStyle(
                    fontSize: 25,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              LikeBookmarkButtons(
                liked: _liked,
                bookmarked: _bookmarked,
                likeCount: _count,
                onToggleLike: () async {
                  final now = !_liked;
                  setState(() {
                    _liked = now;
                    _count = now ? _count + 1 : (_count > 0 ? _count - 1 : 0);
                  });
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
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              widget.card.lines.join('\n'),
              style: TextStyle(color: pal.muted, fontSize: 14, height: 1.8),
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
                  await Clipboard.setData(
                    ClipboardData(text: buildShareText(widget.card)),
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('کپی شد')));
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
          if (widget.etymologyWord != null) ...[
            _RootInfoCard(word: widget.etymologyWord!),
            _PoemUsageCard(words: widget.relatedPersianWords.isNotEmpty
                ? widget.relatedPersianWords : [widget.etymologyWord!]),
          ],
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
          Text(
            card.title,
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w700,
              color: pal.ink,
            ),
          ),
          const SizedBox(height: 10),
          for (final line in card.lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                line,
                style: TextStyle(fontSize: 15, color: pal.muted, height: 1.8),
              ),
            ),
          if (card.caption != null) ...[
            const SizedBox(height: 8),
            Text(
              card.caption!,
              style: TextStyle(fontSize: 12.5, color: pal.faint),
            ),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, color: pal.div),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(LucideIcons.badgeCheck, size: 16, color: pal.sel),
              const SizedBox(width: 6),
              Text(
                'سورن — دیکشنری عربی به فارسی',
                style: TextStyle(fontSize: 12, color: pal.muted),
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
              borderRadius: BorderRadius.circular(3),
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
  Map<String, int> likeCounts = {};
  List<(String, String)> proverbs = const [];
  Categories categories = const Categories({});
  int learnedWords = 0;
  int learnedCorrections = 0;
  int tab = 0;
  String query = '';
  int _homeCollection = 0; // words, proverbs, poems
  Future<List<Map<String, dynamic>>>? _homePoems;

  // Search focus state (home): the word column expands and the back control appears.
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
    final d = await Dictionary.load();
    final s = await SettingsStore.ensureLoaded();
    final cats = await Categories.load();
    final loadedProverbs = await Proverbs.load();
    final fav = await SharedFiles.readJson('favorites.json');
    final lk = await SharedFiles.readJson('liked.json');
    final learned = await SharedFiles.readJson('learned.json');
    await AuthService.restore();
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
      proverbs = loadedProverbs;
      if (fav != null && fav['words'] is List) {
        favorites = (fav['words'] as List).map((e) => e.toString()).toSet();
      }
      if (lk != null && lk['words'] is List) {
        liked = (lk['words'] as List).map((e) => e.toString()).toSet();
      }
      favorites = {...favorites, ...srvFav};
      liked = {...liked, ...srvLiked};
      likeCounts = {};
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
    setState(() {
      liked.contains(word) ? liked.remove(word) : liked.add(word);
    });
    await SharedFiles.writeJson('liked.json', {'words': liked.toList()});
    await AuthService.pushProfile(favorites, liked);
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
      bottomNavigationBar: _searchFocused
          ? const SizedBox.shrink()
          : Container(
              color: Colors.transparent,
              child: _navBar(),
            ),
    );
  }

  /// Floating nav bar (round 3): opaque, no glassmorphism. Six FIXED
  /// slots — the buttons never move when switching tabs; only the
  /// indicator pill slides. The pill is a fixed 42x42 box around the
  /// icon, so its padding is exactly equal on all four sides. The
  /// label fades in/out with opacity only and never changes layout.
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

  /// Restored v0.4.1 navigation geometry and interaction:
  /// the selected item expands to reveal its label and one indicator slides
  /// between tabs. Only the surface changed from glass to a solid color.
  /// Icons remain from the current CUI Lucide pack.
  Widget _navBar() {
    // Original v0.4.1 geometry/behavior, with the current CUI icon pack.
    final items = <(IconData, IconData, String)>[
      (LucideIcons.house, Icons.home_filled, 'پیشگاه'),
      (LucideIcons.heart, Icons.favorite, 'پسندیده‌ها'),
      (LucideIcons.layoutDashboard, Icons.dashboard, 'بخش‌ها'),
      (LucideIcons.bookmark, Icons.bookmark, 'نشان‌شده'),
      (LucideIcons.user, Icons.person, 'نمایه'),
      (LucideIcons.settings, Icons.settings, 'پیکربندی'),
    ];
    _measureIndicator();
    final selSoft = Color.lerp(pal.sel, pal.bg, 0.38)!;
    return Container(
      margin: const EdgeInsets.fromLTRB(22, 6, 22, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: pal.cardC,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: pal.div.withValues(alpha: 0.6)),
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
                    child: SizedBox(
                      width: 42,
                      height: 52,
                      child: Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Align(
                            alignment: Alignment.topCenter,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 5),
                              child: AnimatedSwitcher(
                                duration: Motion.base,
                                switchInCurve: Motion.curve,
                                switchOutCurve: Curves.easeInOut,
                                transitionBuilder: (child, anim) =>
                                    FadeTransition(
                                  opacity: anim,
                                  child: ScaleTransition(
                                    scale: Tween<double>(begin: 0.88, end: 1)
                                        .animate(anim),
                                    child: child,
                                  ),
                                ),
                                child: Icon(
                                  tab == i ? items[i].$2 : items[i].$1,
                                  key: ValueKey<bool>(tab == i),
                                  size: 22,
                                  color: tab == i
                                      ? pal.bg
                                      : pal.ink.withValues(alpha: .72),
                                  fill: tab == i ? 1.0 : 0.0,
                                  weight: tab == i ? 700.0 : 400.0,
                                ),
                              ),
                            ),
                          ),
                          if (tab == i)
                            Positioned(
                              left: -5,
                              right: -5,
                              bottom: 1,
                              child: AnimatedOpacity(
                                opacity: 1,
                                duration: Motion.base,
                                child: Text(
                                  items[i].$3,
                                  maxLines: 1,
                                  softWrap: false,
                                  overflow: TextOverflow.visible,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: pal.ink,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 9,
                                  ),
                                ),
                              ),
                            ),
                        ],
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

    return LayoutBuilder(
      builder: (context, constraints) {
        // Keep the logo and ad reserves, but let the content row consume
        // every remaining pixel. The search capsule moves down by one
        // capsule-height without constraining the page itself.
        const logoGap = 72.0;
        const searchH = 58.0;
        const gapAfterSearch = 18.0;
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: logoGap),
                  const SizedBox(height: searchH),
                  const SizedBox(height: searchH),
                  const SizedBox(height: gapAfterSearch),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _homeCollectionHeader(),
                              const SizedBox(height: 6),
                              Expanded(
                                child: AnimatedSwitcher(
                                  duration: Motion.slow,
                                  switchInCurve: Motion.curve,
                                  switchOutCurve: Curves.easeInOutCubic,
                                  transitionBuilder: (child, animation) =>
                                      FadeTransition(
                                    opacity: animation,
                                    child: SizeTransition(
                                      sizeFactor: animation,
                                      axis: Axis.horizontal,
                                      child: ScaleTransition(
                                        scale: Tween<double>(begin: 0.985, end: 1)
                                            .animate(animation),
                                        child: child,
                                      ),
                                    ),
                                  ),
                                  child: KeyedSubtree(
                                    key: ValueKey(
                                      'home-$_homeCollection-$_searchFocused',
                                    ),
                                    child: _homeCollectionView(d, results),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: Motion.slow,
                          curve: Curves.easeInOutCubic,
                          width: _searchFocused ? 0 : 16,
                        ),
                        AnimatedContainer(
                          duration: Motion.slow,
                          curve: Curves.easeInOutCubic,
                          width: _searchFocused ? 0 : 124,
                          child: ClipRect(
                            child: AnimatedOpacity(
                              opacity: _searchFocused ? 0 : 1,
                              duration: Motion.fast,
                              child: SingleChildScrollView(
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
                                      'واژهٔ روز',
                                      () => _pushPage(_dailyPage(d)),
                                    ),
                                    _sidePill(
                                      'کتابخانهٔ شعر',
                                      () => _open(const GanjoorPage()),
                                    ),
                                    _sidePill(
                                      'ریشه‌شناسی',
                                      () => _open(EtymologyPage(dict: d)),
                                    ),
                                    const SizedBox(height: 4),
                                    _homeMetrics(d),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                top: logoGap + searchH,
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
    final labels = ['گنجینۀ واژه‌ها', 'گنجینۀ پندواژه‌ها', 'گنجینۀ شعرها'];
    return Row(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final base = labels[_homeCollection];
              var best = base;
              for (var count = 1; count <= 18; count++) {
                final candidate = base.replaceFirst(
                  ' ',
                  '\${List<String>.filled(count, 'ـ').join()} ',
                );
                final painter = TextPainter(
                  text: TextSpan(
                    text: candidate,
                    style: TextStyle(
                      color: pal.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                )..layout();
                if (painter.width > constraints.maxWidth) break;
                best = candidate;
              }
              return Text(
                best,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textDirection: TextDirection.rtl,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: pal.ink,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              );
            },
          ),
        ),
        PopupMenuButton<int>(
          tooltip: 'انتخاب گنجینه',
          onSelected: (value) {
            setState(() {
              _homeCollection = value;
              if (value == 2) {
                _homePoems = query.isEmpty
                    ? GanjoorData.searchPoemsForTerms(['عشق', 'دل', 'زندگی'])
                    : GanjoorData.searchPoems(query);
              }
            });
          },
          icon: Icon(LucideIcons.chevronDown, size: 19, color: pal.muted),
          color: pal.cardC,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 0, child: Text('گنجینۀ واژه‌ها')),
            PopupMenuItem(value: 1, child: Text('گنجینۀ پندواژه‌ها')),
            PopupMenuItem(value: 2, child: Text('گنجینۀ شعرها')),
          ],
        ),
      ],
    );
  }

  Widget _homeCollectionView(Dictionary d, List<Entry> wordResults) {
    if (_homeCollection == 0) {
      return _pairList(wordResults, bottomPad: 0, singleLine: true);
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
                trailing: Icon(LucideIcons.chevronRight, size: 17, color: pal.muted),
                onTap: full.isEmpty ? null : () => _open(GanjoorPoemPage(
                  title: title,
                  path: 'poets/$full.json',
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
        controller: _searchCtl,
        focusNode: _searchFocus,
        onChanged: (v) => setState(() {
          query = v.trim();
          if (_homeCollection == 2) {
            _homePoems = query.isEmpty
                ? GanjoorData.searchPoemsForTerms(['عشق', 'دل', 'زندگی'])
                : GanjoorData.searchPoems(query);
          }
        }),
        decoration: InputDecoration(
          hintText: 'واژه‌ای را جستجو کنید',
          hintStyle: TextStyle(color: pal.muted, fontSize: 14.5),
          prefixIcon: Icon(LucideIcons.search, color: pal.muted, size: 23),
          filled: true,
          fillColor: pal.cardC,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          border: OutlineInputBorder(
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
      height: 54,
      child: FutureBuilder<Map<String, int>>(
        future: GanjoorData.stats(),
        builder: (context, snapshot) {
          final stats = snapshot.data ?? const <String, int>{};
          final values = <(String, int)>[
            ('واژه', d.entries.length),
            ('برابر', d.pairCount),
            ('شاعر', stats['poets'] ?? 0),
            ('کتاب', stats['books'] ?? 0),
            ('شعر', stats['poems'] ?? 0),
          ];
          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                for (final item in values)
                  Container(
                    margin: const EdgeInsets.only(left: 6, top: 3, bottom: 3),
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    decoration: BoxDecoration(
                      color: pal.cardC,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(faNum(item.$2),
                            style: TextStyle(color: pal.ink,
                                fontSize: 12, fontWeight: FontWeight.w700)),
                        Text(item.$1,
                            style: TextStyle(color: pal.muted, fontSize: 9.5)),
                      ],
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sidePill(String label, VoidCallback onTap) {
    return Pressable(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 11),
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: pal.pillC,
          borderRadius: BorderRadius.circular(capR(54)),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            var display = label;
            if (label == 'گنجینهٔ واژه‌ها') {
              var best = 'گنجینۀ واژه‌ها';
              for (var count = 1; count <= 12; count++) {
                final kashida = List<String>.filled(count, 'ـ').join();
                final candidate = 'گنجینۀ واژه$kashidaها';
                final painter = TextPainter(
                  text: TextSpan(
                    text: candidate,
                    style: TextStyle(fontSize: 14, color: pal.ink),
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                )..layout();
                if (painter.width > constraints.maxWidth) break;
                best = candidate;
              }
              display = best;
            }
            return Text(
              display,
              maxLines: 1,
              softWrap: false,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: pal.ink),
            );
          },
        ),
      ),
    );
  }

  /// Pair list with the shared top+bottom scroll fade and the unified
  /// entrance. [bottomPad] clears the floating nav bar on tab pages.
  /// [singleLine] (home): word right-aligned, meaning left-aligned,
  /// one line each, showing only the first meaning.
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
      child: ListView.separated(
        padding: EdgeInsets.only(top: 6, bottom: bottomPad),
        itemCount: items.length,
        separatorBuilder: (_, __) => Divider(height: 1, color: pal.div),
        itemBuilder: (_, i) => Enter(
          index: i,
          child: _pairRow(items[i], singleLine: singleLine),
        ),
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
      likeCount: likeCounts[e.ar] ?? 0,
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
  Widget _pandvazhePage() => PandvazhePage(
    proverbs: proverbs,
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
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SingleChildScrollView(
        child: DetailSheet(
          card: card,
          initialLiked: liked.contains(key) || liked.contains(title),
          initialBookmarked: favorites.contains(key) || favorites.contains(title),
          onToggleLike: () => _toggleLike(key),
          onToggleBookmark: () => _toggleFav(key),
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
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => SingleChildScrollView(
        child: DetailSheet(
        card: card,
        initialLiked: liked.contains(e.ar),
        initialBookmarked: favorites.contains(e.ar),
        likeCount: likeCounts[e.ar] ?? 0,
        onToggleLike: () => _toggleLike(e.ar),
        onToggleBookmark: () => _toggleFav(e.ar),
        etymologyWord: e.hasFa ? e.fa.first : null,
        relatedPersianWords: e.fa,
        onOpenEtymology: () {
          Navigator.of(context).pop();
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && dict != null) {
              _open(EtymologyPage(dict: dict!, initialWord: e.hasFa ? e.fa.first : null));
            }
          });
        },
        ),
      ),
    );
  }

  // ---------- پسندیده‌ها ----------
  Widget _likedPage(Dictionary d) {
    final mine = d.entries.where((e) => liked.contains(e.ar)).toList();
    final proverbs = proverbs.where((p) =>
      liked.contains('proverb:\${p.$1}') || liked.contains(p.$1)
    ).toList();
    return _pageShell(
      'پسندیده‌ها',
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: mine.isEmpty && proverbs.isEmpty
            ? Center(
                child: Text(
                  'هنوز چیزی را نپسندیده‌اید.\nبا زدن قلبِ واژه‌ها و پندواژه‌ها آن‌ها را اینجا نگه دارید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, height: 1.9),
                ),
              )
            : edgeFade(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: kNavClearance),
                  children: [
                    for (final e in mine) _pairRow(e),
                    for (final p in proverbs) _savedProverbRow(p),
                  ],
                ),
              ),
      ),
    );
  }

  // ---------- نشان‌شده ----------
  Widget _favoritesPage(Dictionary d) {
    final favs = d.entries.where((e) => favorites.contains(e.ar)).toList();
    final proverbs = proverbs.where((p) =>
      favorites.contains('proverb:\${p.$1}') || favorites.contains(p.$1)
    ).toList();
    return _pageShell(
      'نشان‌شده',
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: favs.isEmpty && proverbs.isEmpty
            ? Center(
                child: Text(
                  'هنوز چیزی را نشان نکرده‌اید.\nبا زدن نشانکِ واژه‌ها و پندواژه‌ها آن‌ها را اینجا نگه دارید.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: pal.muted, height: 1.9),
                ),
              )
            : edgeFade(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: kNavClearance),
                  children: [
                    for (final e in favs) _pairRow(e),
                    for (final p in proverbs) _savedProverbRow(p),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _savedProverbRow((String, String) proverb) {
    final key = 'proverb:\${proverb.$1}';
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
  Widget _sectionsPage(Dictionary d) {
    final tiles = <(IconData, String, VoidCallback)>[
      (
        LucideIcons.notebookPen,
        'گنجینهٔ واژه‌ها',
        () => _open(LexiconPage(dict: d, onTapEntry: _showEntry)),
      ),
      (LucideIcons.type, 'درست‌نویسی', () => _open(CorrectorPage(dict: d))),
      (LucideIcons.alignLeft, 'نیم‌فاصله', () => _open(const NimeFaselePage())),
      (LucideIcons.fileText, 'پندواژه', () => _open(_pandvazhePage())),
      (
        LucideIcons.gitBranch,
        'ریشه‌شناسی',
        () => _open(EtymologyPage(dict: d)),
      ),
      (LucideIcons.sparkles, 'واژه‌های تازه', () => _open(_freshPage(d))),
      (LucideIcons.star, 'واژهٔ روز', () => _pushPage(_dailyPage(d))),
      (
        LucideIcons.fileText,
        'کتابخانهٔ شعر',
        () => _open(const GanjoorPage()),
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
    if (mounted) setState(() => likeCounts = {});
  }

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
                      : Icon(LucideIcons.user, color: pal.bg, size: 32),
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
            // Full-width rows, two badges per row (three rows) —
            // no guide list underneath; tap a badge for its description.
            Column(
              children: [
                for (var r = 0; r < 3; r++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _badgeTile(
                            badgeIds[r * 2],
                            loggedIn: user != null,
                            favorites: favorites.length,
                            likes: liked.length,
                            corrections: learnedCorrections,
                            score: score,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _badgeTile(
                            badgeIds[r * 2 + 1],
                            loggedIn: user != null,
                            favorites: favorites.length,
                            likes: liked.length,
                            corrections: learnedCorrections,
                            score: score,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
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
                  borderRadius: BorderRadius.circular(22),
                ),
                child: Row(
                  children: [
                    Icon(LucideIcons.lock, color: pal.muted, size: 22),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'امتیاز، بج‌ها و همگام‌سازی از امکانات اصلی نمایه‌اند و با ورود فعال می‌شوند. به‌عنوان مهمان، واژه‌نامه، کیبورد و نشان‌شده‌های روی گوشی در دسترس‌تان است.',
                        style: TextStyle(
                          color: pal.muted,
                          fontSize: 13,
                          height: 1.8,
                        ),
                      ),
                    ),
                  ],
                ),
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
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: pal.div),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
                  style: OutlinedButton.styleFrom(
                    foregroundColor: pal.accent,
                    side: BorderSide(color: pal.div),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
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
              leading: Icon(LucideIcons.award, color: pal.ink),
              title: const Text('آموخته‌های کیبورد'),
              subtitle: const Text('آنچه کیبورد سورن از شما آموخته است'),
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

  /// Login + create-profile in ONE row (round 3 §18).
  Widget _authButtons() {
    return Row(
      children: [
        Expanded(
          child: FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: pal.sel,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(capR(50)),
              ),
            ),
            onPressed: () => setState(() {
              showAuthForm = true;
              authRegister = false;
              authError = null;
            }),
            child: const Text('ورود به نمایه'),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: pal.div),
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(capR(50)),
              ),
            ),
            onPressed: () => setState(() {
              showAuthForm = true;
              authRegister = true;
              authError = null;
            }),
            child: const Text('ساخت نمایهٔ تازه'),
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
        borderRadius: BorderRadius.circular(capR(50)),
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
              style: FilledButton.styleFrom(
                backgroundColor: pal.sel,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(capR(50)),
                ),
              ),
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
      edgeFade(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 22 + kNavClearance),
          children: [
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
                'تم و رنگ',
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
                'فونت برنامه',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15.5),
              ),
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: capsuleGroup<String>(
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
              title: const Text('به‌روزرسانی آنلاین از سرور'),
              subtitle: Text(
                'نسخهٔ کنونی: ${faNum(d.version)}${d.fromUpdate ? ' (به‌روزشده)' : ' (همراه برنامه)'} — با اینترنت، تازه‌ترین پایگاه از سرور گرفته می‌شود؛ آفلاین، آرشیو روی گوشی به کار می‌رود',
              ),
              trailing: dbSyncing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : null,
              onTap: dbSyncing ? null : () => _syncDbNow(d),
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated
                ? 'پایگاه واژه‌ها به‌روز شد'
                : 'پایگاه به‌روز است یا ارتباط با سرور برقرار نشد',
          ),
        ),
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

  Widget _pageShell(String title, Widget body, {bool back = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
          child: Row(
            children: [
              if (back) ...[const BackIconButton(), const SizedBox(width: 4)],
              Text(
                title,
                style: const TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(child: body),
      ],
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

/// Scaffold for sub-pages: the content scrolls under a header strip
/// whose background fades and blurs into the page colour — no hard
/// rectangle edge appears under the page title while scrolling.
Widget subScaffold(String title, Widget body) {
  return Scaffold(
    backgroundColor: pal.bg,
    body: SafeArea(
      child: Stack(
        children: [
          Positioned.fill(top: 58, child: body),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
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
        ],
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
                          child: InkWell(
                            onTap: () => widget.onTapEntry(e),
                            child: Row(
                              children: [
                                Text(
                                  e.ar,
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: pal.muted,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
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
                borderRadius: BorderRadius.circular(20),
              ),
              child: AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, anim) =>
                    FadeTransition(opacity: anim, child: child),
                child: Text(
                  _out.isEmpty ? '…' : _out,
                  key: ValueKey(_out),
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
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
  final List<(String, String)> proverbs;
  final Set<String> liked;
  final Set<String> favorites;
  final Map<String, int> likeCounts;
  final Future<void> Function(String) onToggleLike;
  final Future<void> Function(String) onToggleFav;

  const PandvazhePage({
    super.key,
    required this.proverbs,
    required this.liked,
    required this.favorites,
    required this.likeCounts,
    required this.onToggleLike,
    required this.onToggleFav,
  });



  @override
  State<PandvazhePage> createState() => _PandvazhePageState();
}

class _PandvazhePageState extends State<PandvazhePage> {
  late final Set<String> _liked = {...widget.liked};
  late final Set<String> _faved = {...widget.favorites};
  late final Map<String, int> _counts = {...widget.likeCounts};

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
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) => DetailSheet(
        card: card,
        initialLiked: _liked.contains('proverb:$title') || _liked.contains(title),
        initialBookmarked: _faved.contains('proverb:$title') || _faved.contains(title),
        onToggleLike: () async => _toggleLike(title),
        onToggleBookmark: () async => _toggleFav(title),
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
            for (var i = 0; i < proverbs.length; i++)
              Enter(
                index: i,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Pressable(
                    onTap: () => _proverbSheet(
                      context,
                      proverbs[i].$1,
                      proverbs[i].$2,
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
                                      proverbs[i].$1,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 19,
                                      ),
                                    ),
                                  ),
                                  _actions(proverbs[i].$1),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                proverbs[i].$2,
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
                    borderRadius: BorderRadius.circular(20),
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
        borderRadius: BorderRadius.circular(18),
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
  const EtymologyPage({super.key, required this.dict, this.initialWord});
  @override
  State<EtymologyPage> createState() => _EtymologyPageState();
}

class _EtymologyPageState extends State<EtymologyPage> {
  final _ctrl = TextEditingController();
  late final List<PersianLexeme> _rows = PersianRoots.index(widget.dict);
  String _query = '';
  String? _selectedWord;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialWord?.trim() ?? '';
    if (initial.isNotEmpty) {
      _ctrl.text = initial;
      _query = PersianRoots.normalize(initial);
      _selectedWord = initial;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _select(String word) {
    setState(() {
      _selectedWord = word;
      _ctrl.text = word;
      _query = PersianRoots.normalize(word);
    });
  }

  @override
  Widget build(BuildContext context) {
    final matches = PersianRoots.search(_rows, _query);
    PersianLexeme? selected;
    final target = _selectedWord == null ? _query : PersianRoots.normalize(_selectedWord!);
    if (target.isNotEmpty) {
      for (final row in _rows) {
        if (PersianRoots.normalize(row.word) == target) {
          selected = row;
          break;
        }
      }
    }
    final related = selected == null
        ? const <PersianLexeme>[]
        : PersianRoots.sameBase(_rows, selected.word);

    return subScaffold(
      'ریشه‌شناسی فارسی',
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _ctrl,
              onChanged: (v) => setState(() {
                _query = PersianRoots.normalize(v);
                _selectedWord = null;
              }),
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
            if (selected != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: pal.pillC,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(selected.word, textDirection: TextDirection.rtl,
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.ink, fontSize: 20,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 5),
                    Text('بن‌واژه: ${selected.base}',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.sel, fontSize: 15,
                            fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text('${faNum(selected.sourceCount)} پیوند به مدخل واژگان',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.muted, fontSize: 11.5)),
                    if (related.length > 1) ...[
                      const SizedBox(height: 10),
                      Text('واژه‌های هم‌بن', textAlign: TextAlign.right,
                          style: TextStyle(color: pal.muted, fontSize: 11.5)),
                      const SizedBox(height: 6),
                      Wrap(
                        alignment: WrapAlignment.end,
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (final item in related)
                            ActionChip(
                              label: Text(item.word,
                                  textDirection: TextDirection.rtl),
                              onPressed: () => _select(item.word),
                              backgroundColor: pal.cardC,
                              side: BorderSide.none,
                              labelStyle: TextStyle(color: pal.ink),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
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
                      child: Text('واژه‌ای در برابرهای فارسی پیدا نشد.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: pal.muted, height: 1.8)),
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
                            child: InkWell(
                              onTap: () => _select(row.word),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12, horizontal: 4),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text('بن: ${row.base}',
                                          textAlign: TextAlign.left,
                                          style: TextStyle(color: pal.sel,
                                              fontSize: 12.5,
                                              fontWeight: FontWeight.w600)),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(row.word,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(color: pal.ink,
                                            fontSize: 16.5,
                                            fontWeight: FontWeight.w700)),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'این بخش واژه‌های فارسیِ ثبت‌شده در برابرهای دیکشنری را بررسی می‌کند؛ دادهٔ ریشه‌های عربی در آن استفاده نمی‌شود.',
                textAlign: TextAlign.center,
                style: TextStyle(color: pal.faint, fontSize: 10.5, height: 1.6),
              ),
            ),
          ],
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
  static final Map<String, Future<List<Map<String, dynamic>>>> _poemSearchCache = {};

  static String _cacheName(String path) =>
      'ganjoor_${base64Url.encode(utf8.encode(path))}.json';

  static Future<Map<String, dynamic>> json(String path) async {
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

  static Future<Map<String, int>> _loadStats() async {
    var poets = 0, books = 0, poems = 0;
    try {
      final manifest = await json('manifest.json');
      poets = rows(manifest['Poets']).length;
      poems = (manifest['PoemCount'] as num?)?.toInt() ??
          (manifest['poemCount'] as num?)?.toInt() ??
          (manifest['TotalPoems'] as num?)?.toInt() ?? 0;
    } catch (_) {}
    try { books = (await bookCatalog()).length; } catch (_) {}
    return {'poets': poets, 'books': books, 'poems': poems};
  }
}

class _PoemUsageCard extends StatelessWidget {
  final List<String> words;
  const _PoemUsageCard({required this.words});

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
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('شعرهایی که این واژه در آن‌ها آمده',
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
                  trailing: Icon(LucideIcons.chevronRight,
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
  const GanjoorPage({super.key});
  @override
  State<GanjoorPage> createState() => _GanjoorPageState();
}

class _GanjoorPageState extends State<GanjoorPage> {
  late Future<Map<String, dynamic>> _manifest = GanjoorData.json('manifest.json');
  late final Future<List<Map<String, dynamic>>> _books = GanjoorData.bookCatalog();
  Future<List<Map<String, dynamic>>>? _poems;
  String _query = '';
  int _filter = 0; // all, poets, books, poems
  int _view = 0; // list, two columns, cards
  int _searchTicket = 0;

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
    final q = value.trim();
    setState(() {
      _query = q;
      _poems = null;
    });
    final ticket = ++_searchTicket;
    if (q.isEmpty) return;
    Future.delayed(const Duration(milliseconds: 350), () async {
      if (!mounted || ticket != _searchTicket) return;
      final future = GanjoorData.searchPoems(q);
      if (mounted) setState(() => _poems = future);
    });
  }

  void _showSourceInfo() {
    showTopBanner(
      context,
      title: 'داده‌های کتابخانهٔ شعر',
      message: 'متن و فهرست آثار از داده‌های عمومی گنجور دریافت می‌شود. جست‌وجوی شعر از API گنجور انجام می‌شود.',
    );
  }

  void _openPoet(Map<String, dynamic> poet) {
    final full = _value(poet, ['FullUrl', 'fullUrl', 'Url', 'url']);
    if (full.isEmpty) return;
    Navigator.of(context).push(_softRoute(GanjoorNodePage(
      title: _value(poet, ['Nickname', 'nickname', 'Name', 'name']).isEmpty
          ? 'شاعر' : _value(poet, ['Nickname', 'nickname', 'Name', 'name']),
      path: full.replaceFirst(RegExp(r'^/'), ''),
    )));
  }

  void _openBook(Map<String, dynamic> book) {
    final full = _value(book, ['FullUrl', 'fullUrl', 'Url', 'url']);
    if (full.isEmpty) return;
    Navigator.of(context).push(_softRoute(GanjoorNodePage(
      title: _value(book, ['Title', 'title', 'Name', 'name']).isEmpty
          ? 'کتاب' : _value(book, ['Title', 'title', 'Name', 'name']),
      path: full.replaceFirst(RegExp(r'^/'), ''),
    )));
  }

  void _openPoem(Map<String, dynamic> poem) {
    final full = _value(poem, ['FullUrl', 'fullUrl', 'Url', 'url'])
        .replaceFirst(RegExp(r'^/'), '');
    if (full.isEmpty) return;
    Navigator.of(context).push(_softRoute(GanjoorPoemPage(
      title: _value(poem, ['Title', 'title']).isEmpty
          ? 'شعر' : _value(poem, ['Title', 'title']),
      path: 'poets/$full.json',
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
            borderRadius: BorderRadius.circular(16),
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
          borderRadius: BorderRadius.circular(14),
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
            Icon(LucideIcons.chevronRight, color: pal.muted, size: 16),
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
              Text(faNum(items.length),
                  style: TextStyle(color: pal.faint, fontSize: 11)),
              const Spacer(),
              Text(title, textAlign: TextAlign.right,
                  style: TextStyle(color: pal.ink, fontWeight: FontWeight.w700,
                      fontSize: 14)),
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
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 10),
              child: Row(
                children: [
                  const BackIconButton(),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text('کتابخانهٔ شعر',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.ink, fontSize: 20,
                            fontWeight: FontWeight.w700)),
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
                  hintText: 'جست‌وجو در شاعر، کتاب و متن شعر',
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
                  for (var i = 0; i < 4; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Pressable(
                          onTap: () => setState(() => _filter = i),
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            decoration: const BoxDecoration(
                              color: Colors.transparent,
                            ),
                            child: Text(
                              ['همه', 'شاعران', 'کتاب‌ها', 'شعرها'][i],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: _filter == i ? pal.sel : pal.muted,
                                fontSize: 11.5,
                                fontWeight: _filter == i ? FontWeight.w800 : FontWeight.w600,
                              ),
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
                  for (var i = 0; i < 3; i++)
                    Pressable(
                      onTap: () => setState(() => _view = i),
                      child: Container(
                        margin: const EdgeInsets.only(left: 7),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: _view == i ? pal.pillC : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          [LucideIcons.list, LucideIcons.grid3x3,
                            LucideIcons.panelLeft][i],
                          size: 18,
                          color: _view == i ? pal.sel : pal.muted,
                        ),
                      ),
                    ),
                  const Spacer(),
                  Text(
                    ['فهرست', 'دوستونه', 'کاشی‌ای'][_view],
                    style: TextStyle(color: pal.muted, fontSize: 11),
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
                    return _ganjoorError('دریافت فهرست شاعران انجام نشد.',
                        () => setState(() => _manifest = GanjoorData.json('manifest.json')));
                  }
                  final poets = GanjoorData.rows(manifestSnapshot.data!['Poets'])
                      .where((p) => _matches(p, _query)).toList();
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _books,
                    builder: (context, bookSnapshot) {
                      if (bookSnapshot.connectionState != ConnectionState.done &&
                          _filter == 2) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      final books = (bookSnapshot.data ?? const <Map<String, dynamic>>[])
                          .where((b) => _matches(b, _query)).toList();
                      final poemFuture = _query.isEmpty ? null : _poems;
                      if (_filter == 3 && poemFuture == null && _query.isNotEmpty) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return FutureBuilder<List<Map<String, dynamic>>>(
                        future: poemFuture,
                        builder: (context, poemSnapshot) {
                          final poems = poemSnapshot.data ?? const <Map<String, dynamic>>[];
                          final showPoets = _filter == 0 || _filter == 1;
                          final showBooks = _filter == 0 || _filter == 2;
                          final showPoems = _filter == 0 || _filter == 3;
                          if (_filter == 3 && _query.isNotEmpty &&
                              poemSnapshot.connectionState != ConnectionState.done) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          return edgeFade(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(18, 0, 18, 30),
                              children: [
                                if (showPoets)
                                  _section(
                                    'شاعران',
                                    poets,
                                    LucideIcons.user,
                                    (p) => _value(p, ['Nickname', 'nickname', 'Name', 'name']),
                                    (p) => _value(p, ['Bio', 'bio', 'Period', 'period']),
                                    _openPoet,
                                  ),
                                if (showBooks)
                                  _section(
                                    'کتاب‌ها و مجموعه‌ها',
                                    books,
                                    LucideIcons.notebookPen,
                                    (b) => _value(b, ['Title', 'title', 'Name', 'name']),
                                    (b) => _value(b, ['PoetName', 'PoetNickname', 'poetName']),
                                    _openBook,
                                  ),
                                if (showPoems && _query.isNotEmpty)
                                  _section(
                                    'شعرهای پیدا‌شده',
                                    poems,
                                    LucideIcons.fileText,
                                    (p) => _value(p, ['Title', 'title']),
                                    (p) => _value(p, ['PoetName', 'PoetNickname', 'poetName']),
                                    _openPoem,
                                  ),
                                if (_query.isEmpty && _filter == 3)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text('برای جست‌وجوی شعر، نام یا بخشی از متن آن را بنویسید.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: pal.muted, height: 1.8)),
                                  ),
                                if (_query.isNotEmpty && poets.isEmpty &&
                                    books.isEmpty && poems.isEmpty &&
                                    poemSnapshot.connectionState == ConnectionState.done)
                                  Padding(
                                    padding: const EdgeInsets.all(24),
                                    child: Text('در شاعرها، کتاب‌ها و متن شعرها نتیجه‌ای پیدا نشد.',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(color: pal.muted, height: 1.8)),
                                  ),
                              ],
                            ),
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class GanjoorNodePage extends StatefulWidget {
  final String title;
  final String path;
  const GanjoorNodePage({super.key, required this.title, required this.path});
  @override
  State<GanjoorNodePage> createState() => _GanjoorNodePageState();
}

class _GanjoorNodePageState extends State<GanjoorNodePage> {
  late Future<Map<String, dynamic>> _future = _load();

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
          final categories = (data['ChildCats'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final poems = (data['Poems'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          return edgeFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              children: [
                if ((data['Description']?.toString() ?? '').isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(
                      data['Description'].toString(),
                      textAlign: TextAlign.right,
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
                        style: TextStyle(color: pal.ink),
                      ),
                      trailing: Icon(
                        LucideIcons.chevronRight,
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
                      leading: Icon(
                        LucideIcons.fileText,
                        color: pal.muted,
                      ),
                      title: Text(
                        poems[i]['Title']?.toString() ?? '',
                        textAlign: TextAlign.right,
                        style: TextStyle(color: pal.ink),
                      ),
                      onTap: () => _openPoem(poems[i]),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class GanjoorPoemPage extends StatefulWidget {
  final String title;
  final String path;
  const GanjoorPoemPage({super.key, required this.title, required this.path});
  @override
  State<GanjoorPoemPage> createState() => _GanjoorPoemPageState();
}

class _GanjoorPoemPageState extends State<GanjoorPoemPage> {
  late Future<Map<String, dynamic>> _future =
      GanjoorData.json(widget.path);

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
          final verses = (data['Verses'] as List? ?? const [])
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
          final couplets = <int, List<String>>{};
          for (final verse in verses) {
            final index = (verse['CoupletIndex'] as num?)?.toInt() ?? -1;
            if (index < 0) continue;
            couplets.putIfAbsent(index, () => <String>[]);
            couplets[index]!.add(verse['Text']?.toString() ?? '');
          }
          final ordered = couplets.keys.toList()..sort();
          return edgeFade(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 10, 22, 32),
              children: [
                if ((data['PoemSummary']?.toString() ?? '').isNotEmpty)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: pal.cardC,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Text(
                      data['PoemSummary'].toString(),
                      textAlign: TextAlign.right,
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
                      style: TextStyle(color: pal.faint, fontSize: 12),
                    ),
                  ),
                for (var i = 0; i < ordered.length; i++)
                  Enter(
                    index: i,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: pal.pillC,
                        borderRadius: BorderRadius.circular(16),
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
                        ],
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
