import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/context_ext.dart';
import '../../state/auth_provider.dart';
import '../../state/shell_ui_provider.dart';
import '../widgets/logo.dart';
import 'tour_geometry.dart';
import 'tour_keys.dart';
import 'tour_steps.dart';
import 'tour_storage.dart';

/// Gap between the highlighted element and the edge of its frame.
const _framePad = 6.0;
const _minRadius = 12.0;

/// How long the frame takes to glide from one feature to the next.
const _moveMs = 800;

/// Pause before the welcome bubble pops, while the dimming fades in.
const _introMs = 350;

/// The drawer slides in over ~150ms; wait it out before measuring.
const _drawerSettleMs = 380;
const _viewportMargin = 8.0;

OverlayEntry? _entry;
Completer<void>? _completer;

/// Guided first-run tour of the dashboard. Dims and blurs the whole screen,
/// leaves one feature crisp inside a rounded frame, and pops a chat bubble beside
/// it. Between features the frame glides to the next one. Ported from
/// `features/tour/ProductTour.tsx`.
///
/// Resolves when the tour finishes (or is skipped). Safe to call while another
/// tour is running — it returns that tour's future.
Future<void> runProductTour(
  BuildContext context,
  WidgetRef ref, {
  ScrollController? scrollController,
}) {
  if (_entry != null) return _completer!.future;
  final overlay = Overlay.of(context, rootOverlay: true);
  final completer = Completer<void>();
  _completer = completer;
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _TourOverlay(
      onClose: ({required bool markSeen}) async {
        if (markSeen) {
          final userId = ref.read(authProvider).user?.id;
          if (userId != null) await markTourSeen(userId);
        }
        // The drawer is shared chrome — always leave it as we found it (closed).
        ref.read(shellUiProvider.notifier).closeDrawer();
        if (entry.mounted) entry.remove();
        _entry = null;
        _completer = null;
        if (!completer.isCompleted) completer.complete();
      },
    ),
  );
  _entry = entry;
  overlay.insert(entry);
  return completer.future;
}

/// Leaving the dashboard mid-tour just stops it; it isn't recorded as seen.
void abortProductTour() {
  final entry = _entry;
  if (entry == null) return;
  if (entry.mounted) entry.remove();
  _entry = null;
  final c = _completer;
  _completer = null;
  if (c != null && !c.isCompleted) c.complete();
}

class _Geo {
  final Rect rect;
  final double radius;
  const _Geo(this.rect, this.radius);
}

class _TourOverlay extends ConsumerStatefulWidget {
  final Future<void> Function({required bool markSeen}) onClose;
  const _TourOverlay({required this.onClose});

  @override
  ConsumerState<_TourOverlay> createState() => _TourOverlayState();
}

class _TourOverlayState extends ConsumerState<_TourOverlay> with TickerProviderStateMixin {
  int _step = 0;

  /// Which way the patient is travelling, so a step whose element is missing is
  /// skipped onward.
  int _direction = 1;

  _Geo _geo = const _Geo(Rect.zero, 0);
  bool _geoReady = false;
  bool _frameVisible = false;
  bool _revealed = false;

  /// The step whose bubble is on screen. Compared against the current step, so
  /// changing step hides the old bubble at once — no frame of a new bubble
  /// sitting at the previous step's position.
  int? _shownStep;
  Rect? _target;

  late final AnimationController _move = AnimationController(vsync: this);
  Ticker? _tracker;
  int _runId = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _revealed = true);
      _goTo(0);
    });
  }

  @override
  void dispose() {
    _runId++;
    _tracker?.dispose();
    _move.dispose();
    super.dispose();
  }

  Size get _vp => MediaQuery.sizeOf(context);

  _Geo _geoFor(TourStep step, Rect? el) {
    final vp = _vp;
    if (el == null) return _Geo(centerRect(vp.width, vp.height), 0);
    if (step.circle) {
      final c = padRect(squareRect(el), 4);
      return _Geo(clampRect(c, vp.width, vp.height, _viewportMargin), c.width / 2);
    }
    return _Geo(
      clampRect(padRect(el, _framePad), vp.width, vp.height, _viewportMargin),
      math.max(step.ownRadius + _framePad, _minRadius),
    );
  }

  void _stopTracking() {
    _tracker?.dispose();
    _tracker = null;
  }

  // Stay glued to the element: layout can shift (images, fonts, rotation).
  void _startTracking(TourStep step) {
    _stopTracking();
    _tracker = createTicker((_) {
      final id = step.target;
      if (id == null || !mounted) return;
      final el = TourKeys.rectOf(id);
      if (el == null) return;
      final m = _geoFor(step, el);
      if (rectsDiffer(m.rect, _geo.rect) || (m.radius - _geo.radius).abs() > 0.5) {
        setState(() {
          _geo = m;
          _target = m.rect;
        });
      }
    })..start();
  }

  Future<void> _nextFrame() {
    final c = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) => c.complete());
    WidgetsBinding.instance.scheduleFrame();
    return c.future;
  }

  /// Move to [index]: open the drawer if needed, find and scroll to the element,
  /// glide the frame there, then let the bubble pop.
  Future<void> _goTo(int index) async {
    final run = ++_runId;
    bool stale() => run != _runId || !mounted;

    _stopTracking();
    _move.stop();
    if (!_geoReady) {
      final vp = _vp;
      _geo = _Geo(centerRect(vp.width, vp.height), 0);
      _geoReady = true;
    }
    setState(() {
      _step = index;
      _shownStep = null;
    });

    final step = kTourSteps[index];
    final shell = ref.read(shellUiProvider.notifier);
    final drawerOpen = ref.read(shellUiProvider).drawerOpen;
    if (drawerOpen != step.needsDrawer) {
      step.needsDrawer ? shell.openDrawer() : shell.closeDrawer();
      await Future<void>.delayed(const Duration(milliseconds: _drawerSettleMs));
      if (stale()) return;
    }

    Rect? el;
    if (step.target != null) {
      el = TourKeys.rectOf(step.target!);
      if (el == null) {
        // Nothing to point at (not rendered for this account/screen) — skip onward.
        if (_direction == 1) {
          _next();
        } else {
          _back();
        }
        return;
      }
      if (!step.fixed) {
        if (!mounted) return;
        final vp = _vp;
        final top = 84.0 + MediaQuery.viewPaddingOf(context).top - 24;
        final bottom = vp.height - 88;
        if (el.top < top || el.bottom > bottom) {
          final ctx = TourKeys.of(step.target!).currentContext;
          if (ctx != null) {
            // `ctx` is read fresh from the target's key one line above — there is no
            // async gap between obtaining it and using it.
            // ignore: use_build_context_synchronously
            await Scrollable.ensureVisible(ctx, alignment: 0.5, duration: Duration.zero);
            await _nextFrame();
            if (stale() || !mounted) return;
            el = TourKeys.rectOf(step.target!);
          }
        }
      }
    }

    if (!mounted) return;
    final to = _geoFor(step, el);
    final from = _geo;
    setState(() => _frameVisible = el != null);

    // Nowhere to glide on the first step — just give the dimming a beat to fade in.
    final ms = rectsDiffer(from.rect, to.rect) ? _moveMs : _introMs;
    _move.duration = Duration(milliseconds: MediaQuery.disableAnimationsOf(context) ? 1 : ms);
    void tick() {
      if (!mounted) return;
      final k = Curves.easeInOutCubic.transform(_move.value);
      setState(() {
        _geo = _Geo(
          Rect.lerp(from.rect, to.rect, k)!,
          from.radius + (to.radius - from.radius) * k,
        );
      });
    }

    _move.addListener(tick);
    try {
      await _move.forward(from: 0);
    } finally {
      _move.removeListener(tick);
    }
    if (stale()) return;

    setState(() {
      _geo = to;
      _target = el != null ? to.rect : null;
      _shownStep = index;
    });
    if (el != null) _startTracking(step);
  }

  void _next() {
    _direction = 1;
    if (_step >= kTourSteps.length - 1) {
      _finish();
    } else {
      _goTo(_step + 1);
    }
  }

  void _back() {
    _direction = -1;
    _goTo(math.max(0, _step - 1));
  }

  /// Finish or skip — either way the patient has seen it and won't be shown it again.
  void _finish() {
    _runId++;
    widget.onClose(markSeen: true);
  }

  @override
  Widget build(BuildContext context) {
    final vp = MediaQuery.sizeOf(context);
    final step = kTourSteps[_step];
    final showBubble = _shownStep == _step;

    return BackButtonListener(
      onBackButtonPressed: () async {
        _finish();
        return true;
      },
      child: SizedBox.expand(
        child: Stack(
          children: [
            // Swallows every pointer/touch so the page underneath can't be used or
            // scrolled mid-tour.
            const Positioned.fill(
              child: AbsorbPointer(child: SizedBox.expand()),
            ),

            // Dim + blur everything except the hole.
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 500),
                  opacity: _revealed ? 1 : 0,
                  child: ClipPath(
                    clipper: _HoleClipper(_geo.rect, _geo.radius, vp),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 2.5, sigmaY: 2.5),
                      child: const ColoredBox(color: Color.fromRGBO(8, 16, 20, 0.58)),
                    ),
                  ),
                ),
              ),
            ),

            // The frame around the featured area: a light wash, a crisp ring and a
            // soft glow.
            if (_geoReady)
              Positioned.fromRect(
                rect: _geo.rect,
                child: IgnorePointer(
                  child: AnimatedOpacity(
                    duration: const Duration(milliseconds: 300),
                    opacity: _frameVisible ? 1 : 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color.fromRGBO(255, 255, 255, 0.07),
                        borderRadius: BorderRadius.circular(_geo.radius),
                        // CSS lists the topmost shadow first; Flutter paints in order.
                        boxShadow: const [
                          BoxShadow(
                            color: Color.fromRGBO(11, 181, 166, 0.4),
                            blurRadius: 36,
                            spreadRadius: 6,
                          ),
                          BoxShadow(color: Color.fromRGBO(11, 181, 166, 0.55), spreadRadius: 5),
                          BoxShadow(color: Color.fromRGBO(255, 255, 255, 0.9), spreadRadius: 2),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            if (showBubble)
              _TourBubble(
                key: ValueKey(step.id),
                step: step,
                index: _step,
                target: _target,
                vp: vp,
                onNext: _next,
                onBack: _back,
                onSkip: _finish,
              ),
          ],
        ),
      ),
    );
  }
}

class _HoleClipper extends CustomClipper<Path> {
  final Rect hole;
  final double radius;
  final Size viewport;
  _HoleClipper(this.hole, this.radius, this.viewport);

  @override
  Path getClip(Size size) => holePath(size, hole, radius);

  @override
  bool shouldReclip(covariant _HoleClipper old) =>
      old.hole != hole || old.radius != radius || old.viewport != viewport;
}

class _TourBubble extends StatefulWidget {
  final TourStep step;
  final int index;
  final Rect? target;
  final Size vp;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final VoidCallback onSkip;

  const _TourBubble({
    super.key,
    required this.step,
    required this.index,
    required this.target,
    required this.vp,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  @override
  State<_TourBubble> createState() => _TourBubbleState();
}

class _TourBubbleState extends State<_TourBubble> with SingleTickerProviderStateMixin {
  final _contentKey = GlobalKey();
  double _height = 190;
  late final AnimationController _pop = AnimationController(vsync: this);

  @override
  void initState() {
    super.initState();
    // framer-motion spring: stiffness 420, damping 24, mass 0.8.
    _pop.animateWith(SpringSimulation(
      const SpringDescription(mass: 0.8, stiffness: 420, damping: 24),
      0,
      1,
      0,
    ));
    _remeasure();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  // Measure after layout so the bubble is placed against its real height.
  void _remeasure() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = _contentKey.currentContext?.findRenderObject();
      if (box is RenderBox && box.hasSize && mounted) {
        final h = box.size.height;
        if ((h - _height).abs() > 0.5) setState(() => _height = h);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final step = widget.step;
    final index = widget.index;
    final isWelcome = step.target == null;
    final isLast = index == kTourSteps.length - 1;
    final vp = widget.vp;
    final width = math.min(320.0, vp.width - 24);

    final placement = placeBubble(
      isWelcome ? null : widget.target,
      Size(width, _height),
      vp,
      kTourMobilePrefer,
    );
    final side = placement.side;
    final tail = placement.tail;

    // transform-origin: pops out of the tail.
    final origin = switch (side) {
      TourSide.right => Alignment(-1, -1 + 2 * (tail / _height)),
      TourSide.left => Alignment(1, -1 + 2 * (tail / _height)),
      TourSide.bottom => Alignment(-1 + 2 * (tail / width), -1),
      TourSide.top => Alignment(-1 + 2 * (tail / width), 1),
      null => Alignment.center,
    };

    _remeasure();

    final titleColor = dark ? const Color(0xFFF4F4F5) : const Color(0xFF111827);
    final card = Container(
      key: _contentKey,
      width: width,
      padding: EdgeInsets.all(isWelcome ? 24 : 16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.32),
            blurRadius: 48,
            offset: const Offset(0, 18),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: isWelcome ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          isWelcome
              ? Column(
                  children: [
                    _LogoBadge(size: 48, logo: 28),
                    const SizedBox(height: 12),
                    Text(
                      step.title,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 20.8,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.208,
                        height: 1.4,
                        color: titleColor,
                      ),
                    ),
                  ],
                )
              : Row(
                  children: [
                    const _LogoBadge(size: 28, logo: 17),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        step.title,
                        style: TextStyle(
                          fontSize: 15.68,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1568,
                          height: 1.4,
                          color: titleColor,
                        ),
                      ),
                    ),
                  ],
                ),
          Padding(
            padding: EdgeInsets.only(top: isWelcome ? 10 : 8),
            child: Text(
              step.body,
              textAlign: isWelcome ? TextAlign.center : TextAlign.start,
              style: TextStyle(
                fontSize: isWelcome ? 14.72 : 13.76,
                height: 1.625,
                color: t.ink2,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: isWelcome ? MainAxisAlignment.center : MainAxisAlignment.spaceBetween,
            children: [
              if (!isWelcome)
                Row(
                  children: [
                    for (var i = 0; i < kTourCountedSteps; i++) ...[
                      if (i > 0) const SizedBox(width: 6),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 6,
                        width: i == index - 1 ? 16 : 6,
                        decoration: BoxDecoration(
                          color: i == index - 1
                              ? AppColors.teal
                              : i < index - 1
                                  ? AppColors.teal.withValues(alpha: 0.45)
                                  : t.line,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ],
                  ],
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!isLast)
                    _TextBtn(label: 'Skip', color: t.ink3, weight: FontWeight.w500, onTap: widget.onSkip),
                  if (index > 1)
                    _TextBtn(label: 'Back', color: t.ink2, weight: FontWeight.w600, onTap: widget.onBack),
                  const SizedBox(width: 6),
                  Material(
                    color: AppColors.teal,
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onNext,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        child: Text(
                          isWelcome ? 'Start tour' : (isLast ? 'Finish' : 'Next'),
                          style: const TextStyle(
                            fontSize: 13.44,
                            fontWeight: FontWeight.w600,
                            height: 1.5,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    // The tail is a rotated square; only its two outward edges get a border.
    Widget? tailWidget;
    if (side != null) {
      late final double left, top;
      late final Border border;
      const half = 6.0;
      switch (side) {
        case TourSide.right:
          left = -half;
          top = tail - half;
          border = Border(bottom: BorderSide(color: t.line), left: BorderSide(color: t.line));
          break;
        case TourSide.left:
          left = width - half;
          top = tail - half;
          border = Border(right: BorderSide(color: t.line), top: BorderSide(color: t.line));
          break;
        case TourSide.bottom:
          left = tail - half;
          top = -half;
          border = Border(left: BorderSide(color: t.line), top: BorderSide(color: t.line));
          break;
        case TourSide.top:
          left = tail - half;
          top = _height - half;
          border = Border(bottom: BorderSide(color: t.line), right: BorderSide(color: t.line));
          break;
      }
      tailWidget = Positioned(
        left: left,
        top: top,
        child: Transform.rotate(
          angle: math.pi / 4,
          child: Container(width: 12, height: 12, decoration: BoxDecoration(color: t.card, border: border)),
        ),
      );
    }

    return Positioned(
      left: placement.x,
      top: placement.y,
      width: width,
      child: AnimatedBuilder(
        animation: _pop,
        builder: (context, child) {
          final k = _pop.value.clamp(0.0, 1.2);
          final scale = 0.78 + 0.22 * k;
          return Opacity(
            opacity: k.clamp(0.0, 1.0),
            child: Transform.translate(
              offset: Offset(0, 8 * (1 - k)),
              child: Transform.scale(scale: scale, alignment: origin, child: child),
            ),
          );
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            card,
            if (tailWidget != null) tailWidget,
          ],
        ),
      ),
    );
  }
}

class _LogoBadge extends StatelessWidget {
  final double size;
  final double logo;
  const _LogoBadge({required this.size, required this.logo});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: AppGradients.tealCyan,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.teal.withValues(alpha: 0.65),
            blurRadius: 10,
            spreadRadius: -3,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Logo(size: logo, white: true),
    );
  }
}

class _TextBtn extends StatelessWidget {
  final String label;
  final Color color;
  final FontWeight weight;
  final VoidCallback onTap;
  const _TextBtn({
    required this.label,
    required this.color,
    required this.weight,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(9),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          style: TextStyle(fontSize: 12.8, fontWeight: weight, height: 1.5, color: color),
        ),
      ),
    );
  }
}
