import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';

/// Resolves a speciality's icon-name (from the catalog) to a Phosphor icon.
/// Gastroenterology's "Stomach" has no Phosphor equivalent — proxied to a
/// food-bowl glyph, matching the web's react-icons fallback intent.
class SpecialityIcon extends StatelessWidget {
  final String icon;
  final double size;
  final Color color;

  const SpecialityIcon({super.key, required this.icon, required this.size, required this.color});

  static IconData resolve(String name) {
    switch (name) {
      case 'Stethoscope':
        return PhosphorIconsDuotone.stethoscope;
      case 'Stomach':
        return PhosphorIconsDuotone.bowlFood;
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
    return Icon(resolve(icon), size: size, color: color);
  }

  static Color colorOf(String hex) => AppColors.hex(hex);
}
