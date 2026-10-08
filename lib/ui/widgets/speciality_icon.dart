import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/svg_path.dart';

/// react-icons' `GiStomach` (Game Icons, 512×512 viewBox) — gastroenterology's
/// glyph. Phosphor ships no stomach, so the web draws this one from react-icons;
/// the same path data is rendered here.
const _stomachPathData =
    'M153.063 21.74a19.46 28.32 83.178 0 1-23.98 13.947 19.46 28.32 83.178 0 1-27.68-9.18c-1.236 5.62-1.713 12.016-1.163 19.15 3.247 42.106-10.16 118.603 107.54 132.268-41.45 32.308-27.99 64.745-18.467 97.258-33.296-1.63-53.61 23.1-62.577 45.982-97.49-13.226-79.727 121.682-78.574 148.143 1.086 24.9 52.413 28.33 54.285 6.39 3.667-42.972-10.243-104.27 29.207-94.132 22.28 5.724 62.243 53.447 161.366 51.377 140.028-2.926 263.475-321.36 81.64-351.272-63.3-10.412-148.19 37.224-148.19 37.224-67.307 6.347-67.29-24.454-70.937-82.172-.357-5.654-1.216-10.638-2.47-14.983zM137.59 350.176h254.305c-16.912 28.374-52.22 66.58-114.563 65.668-58.09-.85-103.54-18.614-139.742-65.668z';
final Path _stomachPath = parseSvgPath(_stomachPathData);

/// Resolves a speciality's icon-name (from the catalog) to its glyph — mirrors
/// the web's `SpecialityIcon`: Phosphor icons by name (duotone by default, or
/// [filled]), and the react-icons stomach for gastroenterology.
class SpecialityIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color color;

  /// Phosphor `fill` weight instead of the default `duotone` (react-icons'
  /// stomach has a single weight and ignores this).
  final bool filled;

  const SpecialityIcon({
    super.key,
    required this.icon,
    required this.size,
    required this.color,
    this.filled = false,
  });

  static IconData resolve(String name, {bool filled = false}) {
    if (filled) {
      switch (name) {
        case 'Heartbeat':
          return PhosphorIconsFill.heartbeat;
        case 'SunHorizon':
          return PhosphorIconsFill.sunHorizon;
        case 'Ear':
          return PhosphorIconsFill.ear;
        case 'Wind':
          return PhosphorIconsFill.wind;
        case 'Bone':
          return PhosphorIconsFill.bone;
        case 'Brain':
          return PhosphorIconsFill.brain;
        case 'Baby':
          return PhosphorIconsFill.baby;
        case 'Lightning':
          return PhosphorIconsFill.lightning;
        case 'Smiley':
          return PhosphorIconsFill.smiley;
        default:
          return PhosphorIconsFill.stethoscope;
      }
    }
    switch (name) {
      case 'Heartbeat':
        return PhosphorIconsDuotone.heartbeat;
      case 'SunHorizon':
        return PhosphorIconsDuotone.sunHorizon;
      case 'Ear':
        return PhosphorIconsDuotone.ear;
      case 'Wind':
        return PhosphorIconsDuotone.wind;
      case 'Bone':
        return PhosphorIconsDuotone.bone;
      case 'Brain':
        return PhosphorIconsDuotone.brain;
      case 'Baby':
        return PhosphorIconsDuotone.baby;
      case 'Lightning':
        return PhosphorIconsDuotone.lightning;
      case 'Smiley':
        return PhosphorIconsDuotone.smiley;
      default:
        return PhosphorIconsDuotone.stethoscope;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (icon == 'Stomach') {
      return CustomPaint(
        size: Size.square(size),
        painter: _PathIconPainter(_stomachPath, 512, color),
      );
    }
    return Icon(resolve(icon, filled: filled), size: size, color: color);
  }

  static Color colorOf(String hex) => AppColors.hex(hex);
}

/// Fills [path] (authored in a square [viewBox]) scaled to the paint size.
class _PathIconPainter extends CustomPainter {
  final Path path;
  final double viewBox;
  final Color color;
  const _PathIconPainter(this.path, this.viewBox, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.shortestSide / viewBox;
    canvas.save();
    canvas.scale(k, k);
    canvas.drawPath(path, Paint()..color = color..isAntiAlias = true);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_PathIconPainter old) => old.color != color || old.path != path;
}
