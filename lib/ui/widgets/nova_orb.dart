import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Nova's animated 3D dot-sphere. Geometry ported verbatim from
/// `src/utils/orb.ts`; rendered with a [CustomPainter] instead of SVG.
enum OrbPreset { sidebar, chat, hub }

class _OrbConfig {
  final double width, height, cx, cy, r;
  final Color color1, color2;
  const _OrbConfig(this.width, this.height, this.cx, this.cy, this.r, this.color1, this.color2);
}

const _presets = <OrbPreset, _OrbConfig>{
  OrbPreset.sidebar: _OrbConfig(
    140, 130, 70, 65, 50, Color(0xA60BB5A6), Color(0x732CB0C8)), // 0.65 / 0.45 alpha
  OrbPreset.chat: _OrbConfig(150, 138, 75, 69, 52, Color(0xFFB8F4EC), Color(0xFFE0FAFF)),
  OrbPreset.hub: _OrbConfig(148, 148, 74, 74, 54, Color(0xFFCDF6EF), Color(0xFFEAFDFF)),
};

class _OrbPoint {
  final double x, y, z;
  final bool top;
  const _OrbPoint(this.x, this.y, this.z, this.top);
}

List<_OrbPoint> _generatePoints() {
  final pts = <_OrbPoint>[];
  for (var li = 0; li <= 16; li++) {
    final lat = -math.pi / 2 + (li / 16) * math.pi;
    final ringR = math.cos(lat);
    final count = math.max(4, (ringR * 24).round());
    for (var k = 0; k < count; k++) {
      final lon = (k / count) * math.pi * 2;
      final y = math.sin(lat);
      pts.add(_OrbPoint(
        ringR * math.cos(lon),
        y,
        ringR * math.sin(lon),
        (y + 1) / 2 < 0.5,
      ));
    }
  }
  return pts;
}

class NovaOrb extends StatefulWidget {
  final OrbPreset preset;
  final double? size; // overrides the preset width (keeps aspect ratio)
  const NovaOrb({super.key, this.preset = OrbPreset.sidebar, this.size});

  @override
  State<NovaOrb> createState() => _NovaOrbState();
}

class _NovaOrbState extends State<NovaOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_OrbPoint> _points;

  @override
  void initState() {
    super.initState();
    _points = _generatePoints();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cfg = _presets[widget.preset]!;
    final scale = widget.size != null ? widget.size! / cfg.width : 1.0;
    return SizedBox(
      width: cfg.width * scale,
      height: cfg.height * scale,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (_, __) => CustomPaint(
          size: Size(cfg.width * scale, cfg.height * scale),
          painter: _OrbPainter(
            points: _points,
            cfg: cfg,
            angle: _controller.value * 2 * math.pi,
            scale: scale,
          ),
        ),
      ),
    );
  }
}

class _OrbPainter extends CustomPainter {
  final List<_OrbPoint> points;
  final _OrbConfig cfg;
  final double angle;
  final double scale;

  _OrbPainter({required this.points, required this.cfg, required this.angle, required this.scale});

  @override
  void paint(Canvas canvas, Size size) {
    final sin = math.sin(angle);
    final cos = math.cos(angle);
    final paint = Paint()..style = PaintingStyle.fill;

    for (final p in points) {
      final rx = p.x * cos - p.z * sin;
      final rz = p.x * sin + p.z * cos;
      final d = (rz + 1) / 2;
      final cx = (cfg.cx + rx * cfg.r) * scale;
      final cy = (cfg.cy + p.y * cfg.r) * scale;
      final r = (0.6 + d * 1.4) * scale;
      final opacity = (0.15 + d * 0.85).clamp(0.0, 1.0);
      // Final alpha = the dot colour's own alpha (baked into the preset) × the
      // depth-based opacity, matching the web's fill-colour + opacity-attr combo.
      final base = p.top ? cfg.color1 : cfg.color2;
      paint.color = base.withValues(alpha: base.a * opacity);
      canvas.drawCircle(Offset(cx, cy), r, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbPainter old) => old.angle != angle;
}
