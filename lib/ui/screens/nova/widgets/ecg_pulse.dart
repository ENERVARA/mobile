import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Live ECG trace shown while Nova prepares a reply — a bright trail sweeping
/// continuously left→right over a dim baseline waveform, like a cardiac monitor.
/// Ported from `EcgPulse.tsx`.
///
/// Two copies of one path: the full waveform drawn faint, and a short bright
/// dash (22% of the path) travelling along it and wrapping at the end, so the
/// loop is seamless. Straight segments only, so the dash moves at a constant
/// pace.
class EcgPulse extends StatefulWidget {
  const EcgPulse({super.key});

  @override
  State<EcgPulse> createState() => _EcgPulseState();
}

class _EcgPulseState extends State<EcgPulse> with SingleTickerProviderStateMixin {
  // `ecgTravel 1.8s linear infinite`
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `h-[20px] w-[60px]`; the 72×30 trace is fitted inside (xMidYMid meet).
    return SizedBox(
      width: 60,
      height: 20,
      child: CustomPaint(painter: _EcgPainter(_c)),
    );
  }
}

class _EcgPainter extends CustomPainter {
  final Animation<double> progress;
  _EcgPainter(this.progress) : super(repaint: progress);

  static const _viewW = 72.0;
  static const _viewH = 30.0;
  static const _dash = 0.22;

  // M0 15 L14 15 L17 11 L20 15 L28 15 L31 17 L34 2 L37 27 L40 15 L46 15 L50 8 L56 8 L60 15 L72 15
  static final Path _path = Path()
    ..moveTo(0, 15)
    ..lineTo(14, 15)
    ..lineTo(17, 11)
    ..lineTo(20, 15)
    ..lineTo(28, 15)
    ..lineTo(31, 17)
    ..lineTo(34, 2)
    ..lineTo(37, 27)
    ..lineTo(40, 15)
    ..lineTo(46, 15)
    ..lineTo(50, 8)
    ..lineTo(56, 8)
    ..lineTo(60, 15)
    ..lineTo(72, 15);

  @override
  void paint(Canvas canvas, Size size) {
    final k = (size.width / _viewW) < (size.height / _viewH) ? size.width / _viewW : size.height / _viewH;
    canvas.save();
    canvas.translate((size.width - _viewW * k) / 2, (size.height - _viewH * k) / 2);
    canvas.scale(k, k);

    Paint stroke(double width, Color color) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color
      ..isAntiAlias = true;

    // Dim baseline, always readable between sweeps.
    canvas.drawPath(_path, stroke(1.1, AppColors.teal.withValues(alpha: 0.22)));

    // Bright travelling dash; the part that runs past the end re-enters at the start.
    final metric = _path.computeMetrics().first;
    final len = metric.length;
    final start = progress.value * len;
    final end = start + _dash * len;
    final sweep = Path()..addPath(metric.extractPath(start, end > len ? len : end), Offset.zero);
    if (end > len) sweep.addPath(metric.extractPath(0, end - len), Offset.zero);

    // `drop-shadow(0 0 2px rgba(11,181,166,.55))`
    canvas.drawPath(
      sweep,
      stroke(1.3, AppColors.teal.withValues(alpha: 0.55))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.0 / 0.6667),
    );
    canvas.drawPath(sweep, stroke(1.3, AppColors.teal));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_EcgPainter old) => false;
}
