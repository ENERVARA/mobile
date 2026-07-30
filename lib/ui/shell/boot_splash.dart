import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../../state/boot_gate_provider.dart';

/// The message sequence, one step each. The splash loops through these until
/// the router lets go — `bootGateProvider` guarantees at least one full pass.
const _messages = <String>[
  'Your care journey begins here.',
  'Smarter care begins with better context.',
  'Preparing your personalized care assistant…',
  'Almost ready…',
];

/// Full-screen boot splash shown while auth state hydrates: an ECG trace
/// sweeping on a loop, the current message, and a dot per message.
class BootSplash extends StatefulWidget {
  const BootSplash({super.key});

  @override
  State<BootSplash> createState() => _BootSplashState();
}

class _BootSplashState extends State<BootSplash> with SingleTickerProviderStateMixin {
  // One controller drives everything, so the trace sweep and the message
  // sequence stay in phase: exactly two sweeps per pass through the messages.
  late final AnimationController _loop =
      AnimationController(vsync: this, duration: kBootLoopDuration)..repeat();

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    const tint = [AppColors.teal, AppColors.cyan];

    return Scaffold(
      backgroundColor: t.appBg,
      body: Center(
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) {
            final f = _loop.value * _messages.length;
            final idx = f.floor().clamp(0, _messages.length - 1);
            final local = f - idx; // 0→1 within the current message
            final inT = Curves.easeOutCubic.transform((local / 0.18).clamp(0.0, 1.0));
            final outT =
                Curves.easeInCubic.transform(((local - 0.82) / 0.18).clamp(0.0, 1.0));

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 152,
                  height: 54,
                  child: CustomPaint(
                    painter: _EcgPainter(
                      // 6 beats per message pass — 800ms each, a resting 75bpm
                      progress: (_loop.value * 6) % 1.0,
                      ghost: t.line,
                      tint: tint,
                    ),
                  ),
                ),
                const SizedBox(height: 34),

                // Fixed box so a two-line message doesn't shift the dots.
                SizedBox(
                  width: 300,
                  height: 48,
                  child: Center(
                    child: Opacity(
                      opacity: (inT * (1 - outT)).clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(0, (1 - inT) * 10 - outT * 8),
                        child: Text(
                          _messages[idx],
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 15.5,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            color: t.ink2,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var d = 0; d < _messages.length; d++)
                      _dot(d < idx ? 1.0 : (d == idx ? inT : 0.0), t),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _dot(double fill, dynamic t) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Color.lerp(Colors.transparent, AppColors.teal, fill),
          border: fill >= 1 ? null : Border.all(color: t.line, width: 1.5),
          boxShadow: fill <= 0
              ? null
              : [
                  BoxShadow(
                    color: AppColors.teal.withValues(alpha: 0.35 * fill),
                    blurRadius: 8,
                  ),
                ],
        ),
      ),
    );
  }
}

/// A single-beat ECG trace with a monitor-style sweep: the whole trace sits at
/// low contrast, and a bright head runs along it dragging a fading tail. The
/// tail wraps past the end of the path so the loop has no visible seam.
class _EcgPainter extends CustomPainter {
  final double progress; // 0→1 position of the head along the trace
  final Color ghost;
  final List<Color> tint;

  const _EcgPainter({
    required this.progress,
    required this.ghost,
    required this.tint,
  });

  static const _tail = 0.35; // fraction of the trace lit behind the head
  static const _slices = 26; // tail is drawn as N segments of rising opacity

  @override
  void paint(Canvas canvas, Size size) {
    final path = _ecgPath(size);
    final metric = path.computeMetrics().first;
    final len = metric.length;

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = ghost,
    );

    final head = progress * len;
    final tailLen = len * _tail;

    for (var k = 0; k < _slices; k++) {
      final f = (k + 1) / _slices; // 0 at the tail end, 1 at the head
      _strokeRange(
        canvas,
        metric,
        len,
        head - tailLen * (_slices - k) / _slices,
        head - tailLen * (_slices - k - 1) / _slices,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.7 + 0.8 * f
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = Color.lerp(tint.last, tint.first, f)!.withValues(alpha: f * f),
      );
    }

    final tan = metric.getTangentForOffset(head.clamp(0.0, len));
    if (tan != null) {
      final p = tan.position;
      canvas.drawCircle(
        p,
        7,
        Paint()
          ..color = tint.first.withValues(alpha: 0.32)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
      canvas.drawCircle(p, 3.6, Paint()..color = tint.first.withValues(alpha: 0.26));
      canvas.drawCircle(p, 2.2, Paint()..color = tint.first);
    }
  }

  /// Strokes `[a, b]` of the contour, where either bound may be negative —
  /// those wrap around to the end of the path.
  void _strokeRange(
    Canvas canvas,
    PathMetric m,
    double len,
    double a,
    double b,
    Paint paint,
  ) {
    if (b <= a) return;
    if (b <= 0) {
      a += len;
      b += len;
    }
    if (a < 0) {
      canvas.drawPath(m.extractPath(a + len, len), paint);
      canvas.drawPath(m.extractPath(0, b), paint);
      return;
    }
    canvas.drawPath(m.extractPath(a, b.clamp(0.0, len)), paint);
  }

  @override
  bool shouldRepaint(_EcgPainter old) =>
      old.progress != progress || old.ghost != ghost || old.tint != tint;
}

/// One cardiac cycle across [size], proportioned like a real rhythm strip: a
/// long isoelectric baseline, a low rounded P wave, a narrow spiky QRS, a
/// broader T wave, then diastole. X values are fractions of the width, Y values
/// are fractions of half the height above the baseline.
Path _ecgPath(Size size) {
  final baseline = size.height / 2;
  final amp = size.height / 2 * 0.8;
  double x(double f) => f * size.width;
  double y(double f) => baseline - f * amp;

  return Path()
    ..moveTo(0, baseline)
    ..lineTo(x(0.08), baseline)
    ..quadraticBezierTo(x(0.125), y(0.14), x(0.17), baseline) // P
    ..lineTo(x(0.25), baseline) // PR segment
    ..lineTo(x(0.27), y(-0.08)) // Q
    ..lineTo(x(0.30), y(1.0)) // R
    ..lineTo(x(0.33), y(-0.22)) // S
    ..lineTo(x(0.36), baseline)
    ..lineTo(x(0.45), baseline) // ST segment
    ..quadraticBezierTo(x(0.535), y(0.26), x(0.62), baseline) // T
    ..lineTo(x(1.0), baseline); // diastole
}
