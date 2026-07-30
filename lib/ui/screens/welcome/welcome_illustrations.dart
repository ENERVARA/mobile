import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../widgets/logo.dart';

// ── Animation helpers ────────────────────────────────────────────────────────

/// Curved 0→1 progress for a sub-segment [a,b] of a 0→1 timeline `t`.
double _seg(double t, double a, double b, [Curve c = Curves.easeOutCubic]) {
  if (b <= a) return t >= b ? 1.0 : 0.0;
  return c.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
}

/// A -1..1 sine from a looping 0..1 `ambient` value (for floating/bobbing).
double _wave(double ambient, [double phase = 0]) =>
    math.sin(ambient * 2 * math.pi + phase);

/// A 0..1 sine from a looping 0..1 `ambient` value (for pulsing/breathing).
double _pulse(double ambient, [double phase = 0]) =>
    0.5 + 0.5 * math.sin(ambient * 2 * math.pi + phase);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Per-slide animated illustration. Owns an [_intro] controller (the staggered
/// entrance, replayed whenever the slide becomes [active]) and an always-looping
/// [_ambient] controller (float / pulse / breathe). Kept deliberately subtle —
/// small amplitudes, soft opacity, gentle curves — for an Apple-Health /
/// Headspace feel rather than anything flashy.
class SlideIllustration extends StatefulWidget {
  final int index;
  final List<Color> tint;
  final bool active;
  const SlideIllustration({
    super.key,
    required this.index,
    required this.tint,
    required this.active,
  });

  @override
  State<SlideIllustration> createState() => _SlideIllustrationState();
}

class _SlideIllustrationState extends State<SlideIllustration>
    with TickerProviderStateMixin {
  late final AnimationController _intro =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));
  late final AnimationController _ambient =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 4200))
        ..repeat();

  @override
  void initState() {
    super.initState();
    if (widget.active) _intro.forward();
  }

  @override
  void didUpdateWidget(covariant SlideIllustration old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _intro.forward(from: 0); // replay the entrance on re-entry
    } else if (!widget.active && old.active) {
      _intro.value = 0;
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    _ambient.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 264,
      height: 208,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _ambient]),
        builder: (context, _) {
          final i = _intro.value;
          final a = _ambient.value;
          switch (widget.index) {
            case 0:
              return _brand(context, i, a, widget.tint);
            case 1:
              return _nova(context, i, a, widget.tint);
            case 2:
              return _specialities(context, i, a);
            case 3:
              return _privacy(context, i, a, widget.tint);
            case 4:
              return _records(context, i, a, widget.tint);
            case 5:
              return _handoff(context, i, a, widget.tint);
            default:
              return _dataProtected(context, i, a, widget.tint);
          }
        },
      ),
    );
  }
}

// ── Shared building blocks ───────────────────────────────────────────────────

Widget _glowDisc({
  required double size,
  required List<Color> tint,
  Widget? child,
  double glow = 0.35,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: LinearGradient(
        colors: tint,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      boxShadow: [
        BoxShadow(
          color: tint.first.withValues(alpha: glow),
          blurRadius: 24,
          offset: const Offset(0, 10),
        ),
      ],
    ),
    child: child == null ? null : Center(child: child),
  );
}

Widget _gradientIcon(IconData icon, double size, List<Color> tint) => ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (r) => LinearGradient(
        colors: tint,
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(r),
      child: Icon(icon, size: size, color: Colors.white),
    );

/// A small "record card" — a rounded card with 2–3 skeleton lines. Used for the
/// records-into-shield and files-into-folder illustrations.
Widget _miniCard(
  double w,
  double h, {
  int lines = 2,
  required Color lineColor,
  Color? border,
  double radius = 9,
}) {
  return Container(
    width: w,
    height: h,
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: border != null ? Border.all(color: border) : null,
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.07),
          blurRadius: 9,
          offset: const Offset(0, 3),
        ),
      ],
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var l = 0; l < lines; l++)
          Container(
            margin: EdgeInsets.only(bottom: l == lines - 1 ? 0 : 4),
            height: 4,
            width: w * (l == 0 ? 0.66 : 0.44),
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
      ],
    ),
  );
}

// ── 0 · Brand — heartbeat pulse rings + floating particles ───────────────────

Widget _brand(BuildContext context, double i, double a, List<Color> tint) {
  final discIntro = _seg(i, 0.0, 0.5, Curves.easeOutBack);
  final breathe = 1 + 0.04 * _wave(a);
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      for (var r = 0; r < 3; r++) _pulseRing(a, tint, r, i),
      Transform.scale(
        scale: breathe,
        child: Container(
          width: 176,
          height: 176,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [tint.first.withValues(alpha: 0.16 * i), Colors.transparent],
              stops: const [0.35, 1.0],
            ),
          ),
        ),
      ),
      _particle(a, tint, const Offset(-90, -48), 0.0, i, 6),
      _particle(a, tint, const Offset(94, -32), 1.7, i, 5),
      _particle(a, tint, const Offset(74, 64), 3.1, i, 7),
      _particle(a, tint, const Offset(-80, 60), 4.4, i, 4),
      Opacity(
        opacity: _seg(i, 0.0, 0.4),
        child: Transform.scale(
          scale: 0.6 + 0.4 * discIntro,
          child: _glowDisc(
            size: 104,
            tint: tint,
            child: const Logo(size: 56, white: true),
          ),
        ),
      ),
    ],
  );
}

Widget _pulseRing(double a, List<Color> tint, int idx, double i) {
  final phase = (a + idx / 3) % 1.0;
  final scale = 0.55 + phase * 1.45;
  final opacity = ((1 - phase) * 0.30 * i).clamp(0.0, 1.0);
  return Transform.scale(
    scale: scale,
    child: Container(
      width: 124,
      height: 124,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: tint.first.withValues(alpha: opacity), width: 2),
      ),
    ),
  );
}

Widget _particle(
    double a, List<Color> tint, Offset base, double phase, double appear, double s) {
  return Transform.translate(
    offset: base + Offset(0, _wave(a, phase) * 5),
    child: Opacity(
      opacity: (0.55 * appear).clamp(0.0, 1.0),
      child: Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, color: tint.last.withValues(alpha: 0.6)),
      ),
    ),
  );
}

// ── 1 · Nova — chat bubbles sliding in one by one ────────────────────────────

Widget _nova(BuildContext context, double i, double a, List<Color> tint) {
  final t = context.tokens;
  final orbIntro = _seg(i, 0.0, 0.3, Curves.easeOutBack);
  return Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Opacity(
        opacity: _seg(i, 0.0, 0.25),
        child: Transform.translate(
          offset: Offset(0, _wave(a) * 3),
          child: Transform.scale(
            scale: 0.7 + 0.3 * orbIntro,
            child: _glowDisc(
              size: 52,
              tint: tint,
              child: const Icon(PhosphorIconsFill.sparkle, size: 26, color: Colors.white),
            ),
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: 212,
        child: Column(
          children: [
            _chatBubble(
              left: true,
              appear: _seg(i, 0.15, 0.42),
              bg: t.soft,
              child: _lines(const [78, 52], t.ink3),
            ),
            _chatBubble(
              left: false,
              appear: _seg(i, 0.44, 0.66),
              bg: AppColors.teal,
              child: _lines(const [58], Colors.white.withValues(alpha: 0.9)),
            ),
            _chatBubble(
              left: true,
              appear: _seg(i, 0.68, 0.9),
              bg: t.soft,
              child: _typingDots(a, t.ink3),
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _chatBubble({
  required bool left,
  required double appear,
  required Color bg,
  required Widget child,
}) {
  final dx = (left ? -26.0 : 26.0) * (1 - appear);
  return Align(
    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
    child: Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.translate(
        offset: Offset(dx, 0),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(14),
              topRight: const Radius.circular(14),
              bottomLeft: Radius.circular(left ? 4 : 14),
              bottomRight: Radius.circular(left ? 14 : 4),
            ),
          ),
          child: child,
        ),
      ),
    ),
  );
}

Widget _lines(List<double> widths, Color c) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var l = 0; l < widths.length; l++)
          Container(
            margin: EdgeInsets.only(top: l == 0 ? 0 : 5),
            width: widths[l],
            height: 6,
            decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
          ),
      ],
    );

Widget _typingDots(double a, Color color) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var d = 0; d < 3; d++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: Opacity(
              opacity: 0.35 + 0.65 * _pulse(a, d * 1.1),
              child: Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: color),
              ),
            ),
          ),
      ],
    );

// ── 2 · Specialities — icon chips popping in + orbiting float ────────────────

const _specChips = <(IconData, Color)>[
  (PhosphorIconsFill.heart, AppColors.coral),
  (PhosphorIconsFill.brain, AppColors.lav),
  (PhosphorIconsFill.tooth, AppColors.cyan),
  (PhosphorIconsFill.pulse, AppColors.teal),
  (PhosphorIconsFill.eye, AppColors.amber),
  (PhosphorIconsFill.pill, AppColors.tealD),
];

Widget _specialities(BuildContext context, double i, double a) {
  final t = context.tokens;
  final centerIntro = _seg(i, 0.0, 0.3, Curves.easeOutBack);
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Opacity(
        opacity: _seg(i, 0.0, 0.3),
        child: Transform.scale(
          scale: 0.7 + 0.3 * centerIntro,
          child: _glowDisc(
            size: 66,
            tint: const [AppColors.teal, AppColors.cyan],
            child: const Icon(PhosphorIconsFill.stethoscope, size: 32, color: Colors.white),
          ),
        ),
      ),
      for (var c = 0; c < _specChips.length; c++)
        _orbitChip(i, a, c, _specChips.length, _specChips[c].$1, _specChips[c].$2, t),
    ],
  );
}

Widget _orbitChip(double i, double a, int idx, int n, IconData icon, Color color, dynamic t) {
  final angle = -math.pi / 2 + idx * 2 * math.pi / n;
  const radius = 80.0;
  final pos = Offset(math.cos(angle) * radius, math.sin(angle) * radius);
  final appear = _seg(i, 0.15 + idx * 0.09, 0.42 + idx * 0.09, Curves.easeOutBack);
  final bob = _wave(a, idx * 1.1) * 4;
  return Transform.translate(
    offset: pos + Offset(0, bob),
    child: Transform.scale(
      scale: appear,
      child: Opacity(
        opacity: appear.clamp(0.0, 1.0),
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.card,
            border: Border.all(color: t.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(icon, size: 22, color: color),
        ),
      ),
    ),
  );
}

// ── 3 · Privacy — records slide into a shield, then a lock snaps shut ────────

Widget _privacy(BuildContext context, double i, double a, List<Color> tint) {
  final shieldIntro = _seg(i, 0.0, 0.35, Curves.easeOutBack);
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Opacity(
        opacity: _seg(i, 0.0, 0.3),
        child: Transform.translate(
          offset: Offset(0, _wave(a) * 3),
          child: Transform.scale(
            scale: 0.8 + 0.2 * shieldIntro,
            child: _gradientIcon(PhosphorIconsFill.shield, 152, tint),
          ),
        ),
      ),
      for (var r = 0; r < 3; r++) _recordIntoShield(i, r, tint),
      _lockClose(i, a, tint),
    ],
  );
}

Widget _recordIntoShield(double i, int r, List<Color> tint) {
  final p = _seg(i, 0.14 + r * 0.12, 0.5 + r * 0.12, Curves.easeInOut);
  if (p <= 0) return const SizedBox.shrink();
  final y = _lerp(-66, -14, p);
  // Fade in over the first third, hold, then fade out as it enters the shield.
  final opacity = (p * 3).clamp(0.0, 1.0) * (1 - ((p - 0.7) / 0.3).clamp(0.0, 1.0));
  final scale = _lerp(0.92, 0.5, p);
  return Transform.translate(
    offset: Offset(0, y),
    child: Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: _miniCard(48, 34, lines: 2, lineColor: tint.first.withValues(alpha: 0.55)),
      ),
    ),
  );
}

Widget _lockClose(double i, double a, List<Color> tint) {
  final p = _seg(i, 0.6, 0.9, Curves.easeOutBack);
  if (p <= 0) return const SizedBox.shrink();
  final isClosed = i >= 0.74;
  final ring = _seg(i, 0.74, 1.0, Curves.easeOut);
  return Transform.translate(
    offset: const Offset(0, 6),
    child: Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        // one-shot ring that expands as the lock snaps shut
        if (ring > 0)
          Transform.scale(
            scale: 0.6 + ring * 1.3,
            child: Opacity(
              opacity: (1 - ring) * 0.5,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: tint.first, width: 2),
                ),
              ),
            ),
          ),
        Opacity(
          opacity: p.clamp(0.0, 1.0),
          child: Transform.scale(
            scale: 0.7 + 0.3 * p,
            child: Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: tint.first.withValues(alpha: 0.35 + 0.15 * _pulse(a)),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                isClosed ? PhosphorIconsFill.lockSimple : PhosphorIconsFill.lockSimpleOpen,
                size: 24,
                color: tint.first,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

// ── 4 · Records & quick help — files drop into a folder + emergency pulse ────

Widget _records(BuildContext context, double i, double a, List<Color> tint) {
  final t = context.tokens;
  final folderIntro = _seg(i, 0.0, 0.32, Curves.easeOutBack);
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      Opacity(
        opacity: _seg(i, 0.0, 0.28),
        child: Transform.translate(
          offset: Offset(0, 36 + _wave(a) * 3),
          child: Transform.scale(
            scale: 0.85 + 0.15 * folderIntro,
            child: _gradientIcon(PhosphorIconsFill.folder, 120, const [AppColors.teal, AppColors.cyan]),
          ),
        ),
      ),
      for (var f = 0; f < 3; f++) _fileDrop(i, f, t, tint),
      _emergencyBadge(i, a),
    ],
  );
}

Widget _fileDrop(double i, int f, dynamic t, List<Color> tint) {
  final p = _seg(i, 0.2 + f * 0.14, 0.56 + f * 0.14, Curves.easeOutCubic);
  if (p <= 0) return const SizedBox.shrink();
  final restY = -8.0 - f * 9;
  final y = _lerp(-92, restY, p);
  final dx = (f - 1) * 11.0;
  final rot = (f - 1) * 0.06;
  return Transform.translate(
    offset: Offset(dx, y),
    child: Opacity(
      opacity: p.clamp(0.0, 1.0),
      child: Transform.rotate(
        angle: rot,
        child: _miniCard(58, 42, lines: 3, lineColor: tint.first.withValues(alpha: 0.5), border: t.line),
      ),
    ),
  );
}

Widget _emergencyBadge(double i, double a) {
  final appear = _seg(i, 0.55, 0.82, Curves.easeOutBack);
  if (appear <= 0) return const SizedBox.shrink();
  final pulse = _pulse(a);
  return Positioned(
    right: 8,
    top: 6,
    child: Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: appear,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.scale(
              scale: 1 + 0.5 * pulse,
              child: Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.coral.withValues(alpha: 0.18 * (1 - pulse)),
                ),
              ),
            ),
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppColors.coral, AppColors.amber],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.coral.withValues(alpha: 0.4),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: const Icon(PhosphorIconsFill.plus, size: 24, color: Colors.white),
            ),
          ],
        ),
      ),
    ),
  );
}

// ── 5 · Handoff — a record card travels from patient to physician ────────────

/// The pieces of the record that get absorbed into the card mid-flight, in the
/// order they animate in: labs → meds → allergies → history → symptom timeline.
const _handoffChips = <(IconData, Color)>[
  (PhosphorIconsFill.flask, AppColors.cyan),
  (PhosphorIconsFill.pill, AppColors.teal),
  (PhosphorIconsFill.warning, AppColors.coral),
  (PhosphorIconsFill.clockCounterClockwise, AppColors.lav),
  (PhosphorIconsFill.pulse, AppColors.amber),
];

const _laneY = -52.0; // the patient→physician lane, above the centre line
const _nodeX = 92.0; // horizontal distance of each node from centre

Widget _handoff(BuildContext context, double i, double a, List<Color> tint) {
  final t = context.tokens;
  // The card's position along the lane — every chip aims at wherever it is
  // *right now*, so the absorptions track the moving target.
  final travel = _seg(i, 0.18, 0.76, Curves.easeInOutCubic);
  final cardX = _lerp(-_nodeX, _nodeX, travel);
  final delivered = _seg(i, 0.74, 1.0, Curves.easeOutCubic);

  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      // lane of dots, lighting up behind the card as it passes
      Transform.translate(
        offset: const Offset(0, _laneY),
        child: SizedBox(
          width: 124,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [for (var d = 0; d < 7; d++) _laneDot(travel, d, 7, tint, t)],
          ),
        ),
      ),

      _handoffNode(i, a, -_nodeX, 0.0, PhosphorIconsFill.user, 'You',
          [tint.first, tint.first], t),
      _handoffNode(i, a, _nodeX, 0.08, PhosphorIconsFill.stethoscope, 'Your doctor',
          tint, t),

      // the record fragments flying into the card
      for (var c = 0; c < _handoffChips.length; c++)
        _handoffChip(i, c, cardX, t),

      // the travelling card — fades out as the brief takes its place
      _travellingCard(i, a, cardX, tint, t),

      // and the brief it becomes, in the physician's hands
      _caseBrief(delivered, tint, t),
    ],
  );
}

Widget _laneDot(double travel, int idx, int n, List<Color> tint, dynamic t) {
  final frac = idx / (n - 1);
  final lit = ((travel - frac) * 5).clamp(0.0, 1.0);
  return Container(
    width: 5,
    height: 5,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Color.lerp(t.line, tint.first, lit),
    ),
  );
}

Widget _handoffNode(double i, double a, double x, double delay, IconData icon,
    String label, List<Color> tint, dynamic t) {
  final appear = _seg(i, delay, 0.24 + delay, Curves.easeOutBack);
  if (appear <= 0) return const SizedBox.shrink();
  // +10.5 offsets the caption below the disc, so the disc itself — not the
  // column — sits on the lane the card travels along.
  return Transform.translate(
    offset: Offset(x, _laneY + 10.5 + _wave(a, x.isNegative ? 0 : 2.2) * 2.5),
    child: Opacity(
      opacity: appear.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: 0.7 + 0.3 * appear,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _glowDisc(
              size: 52,
              tint: tint,
              glow: 0.28,
              child: Icon(icon, size: 25, color: Colors.white),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: t.ink3,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// One data fragment: fades in at its home slot, then flies up into the card.
Widget _handoffChip(double i, int c, double cardX, dynamic t) {
  final start = 0.20 + c * 0.085;
  final p = _seg(i, start, start + 0.40, Curves.easeInOutCubic);
  if (p <= 0) return const SizedBox.shrink();
  final homeX = -76.0 + c * 38;
  const homeY = 20.0;
  final fadeIn = (p / 0.22).clamp(0.0, 1.0);
  final absorb = ((p - 0.76) / 0.24).clamp(0.0, 1.0); // merges into the card
  final (icon, color) = _handoffChips[c];
  return Transform.translate(
    offset: Offset(_lerp(homeX, cardX, p), _lerp(homeY, _laneY, p)),
    child: Opacity(
      opacity: (fadeIn * (1 - absorb)).clamp(0.0, 1.0),
      child: Transform.scale(
        scale: _lerp(1.0, 0.35, p) * (0.6 + 0.4 * fadeIn),
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: t.card,
            border: Border.all(color: t.line),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    ),
  );
}

Widget _travellingCard(double i, double a, double cardX, List<Color> tint, dynamic t) {
  final appear = _seg(i, 0.10, 0.30, Curves.easeOutBack);
  if (appear <= 0) return const SizedBox.shrink();
  final handOff = _seg(i, 0.76, 0.88); // dissolves into the case brief
  final opacity = (appear * (1 - handOff)).clamp(0.0, 1.0);
  if (opacity <= 0) return const SizedBox.shrink();
  return Transform.translate(
    offset: Offset(cardX, _laneY + _wave(a, 1.4) * 2),
    child: Opacity(
      opacity: opacity,
      child: Transform.scale(
        scale: (0.7 + 0.3 * appear) * _lerp(1.0, 1.12, handOff),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(11),
            boxShadow: [
              BoxShadow(
                color: tint.first.withValues(alpha: 0.30 + 0.14 * _pulse(a)),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: _miniCard(58, 42,
              lines: 3, lineColor: tint.first.withValues(alpha: 0.5), border: t.line),
        ),
      ),
    ),
  );
}

Widget _caseBrief(double d, List<Color> tint, dynamic t) {
  if (d <= 0) return const SizedBox.shrink();
  return Transform.translate(
    offset: Offset(_lerp(_nodeX * 0.55, 0, d), _lerp(_laneY, 42, d)),
    child: Opacity(
      opacity: d.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: _lerp(0.5, 1.0, d),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 12),
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
            boxShadow: [
              BoxShadow(
                color: tint.first.withValues(alpha: 0.22),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsFill.sealCheck, size: 15, color: tint.first),
                  const SizedBox(width: 6),
                  Text(
                    'Pre-consult case brief',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.1,
                      color: t.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 9),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final chip in _handoffChips)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: chip.$2.withValues(alpha: 0.12),
                        ),
                        child: Icon(chip.$1, size: 12, color: chip.$2),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// ── 6 · Data protection — encrypted core inside a ring of ciphered data ──────

Widget _dataProtected(BuildContext context, double i, double a, List<Color> tint) {
  final t = context.tokens;
  final coreIntro = _seg(i, 0.0, 0.34, Curves.easeOutBack);
  const badges = <(String, double)>[
    ('HIPAA', 0.0),
    ('HL7 FHIR', 0.05),
    ('DPDP 2023', 0.10),
    ('AWS secured', 0.15),
  ];
  return Stack(
    alignment: Alignment.center,
    clipBehavior: Clip.none,
    children: [
      // soft halo breathing behind the vault
      Transform.translate(
        offset: const Offset(0, -30),
        child: Transform.scale(
          scale: 1 + 0.04 * _wave(a),
          child: Container(
            width: 176,
            height: 176,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [tint.first.withValues(alpha: 0.15 * i), Colors.transparent],
                stops: const [0.32, 1.0],
              ),
            ),
          ),
        ),
      ),

      // slowly rotating ring of "ciphered" dashes
      Transform.translate(
        offset: const Offset(0, -30),
        child: Transform.rotate(
          angle: a * 2 * math.pi * 0.2,
          child: SizedBox(
            width: 152,
            height: 152,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (var d = 0; d < 12; d++) _cipherDash(i, a, d, 12, tint),
              ],
            ),
          ),
        ),
      ),

      // the encrypted core
      Transform.translate(
        offset: Offset(0, -30 + _wave(a) * 3),
        child: Opacity(
          opacity: _seg(i, 0.0, 0.3),
          child: Transform.scale(
            scale: 0.7 + 0.3 * coreIntro,
            child: _glowDisc(
              size: 88,
              tint: tint,
              glow: 0.32 + 0.12 * _pulse(a),
              child: const Icon(PhosphorIconsFill.lockKey, size: 42, color: Colors.white),
            ),
          ),
        ),
      ),

      // compliance badges settling in underneath
      Positioned(
        bottom: 0,
        child: SizedBox(
          width: 248,
          child: Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final b in badges) _complianceBadge(i, b.$1, b.$2, t, tint),
            ],
          ),
        ),
      ),
    ],
  );
}

/// One dash on the rotating ring — reads as a fragment of encrypted data.
Widget _cipherDash(double i, double a, int idx, int n, List<Color> tint) {
  final angle = idx * 2 * math.pi / n;
  const radius = 62.0;
  final appear = _seg(i, 0.12 + idx * 0.04, 0.4 + idx * 0.04);
  if (appear <= 0) return const SizedBox.shrink();
  // Each dash twinkles on its own phase, so the ring never reads as static.
  final twinkle = 0.3 + 0.7 * _pulse(a, idx * 0.9);
  return Transform.translate(
    offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius),
    child: Transform.rotate(
      angle: angle + math.pi / 2,
      child: Opacity(
        opacity: (appear * twinkle * 0.75).clamp(0.0, 1.0),
        child: Container(
          width: 5,
          height: idx.isEven ? 13 : 8,
          decoration: BoxDecoration(
            color: idx.isEven ? tint.first : tint.last,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
      ),
    ),
  );
}

Widget _complianceBadge(double i, String label, double delay, dynamic t, List<Color> tint) {
  // No early return: the badge always occupies its slot so the Wrap doesn't
  // reflow as the row staggers in.
  final appear = _seg(i, 0.54 + delay, 0.80 + delay, Curves.easeOutBack);
  return Opacity(
    opacity: appear.clamp(0.0, 1.0),
    child: Transform.translate(
      offset: Offset(0, (1 - appear) * 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.line),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(PhosphorIconsFill.sealCheck, size: 13, color: tint.first),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
                color: t.ink2,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
