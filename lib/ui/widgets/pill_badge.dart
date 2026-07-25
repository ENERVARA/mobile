import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';

enum PillVariant { avail, soon, green, amber, gray }

/// Small status pill (redesign) — avail / soon / green / amber / gray.
class PillBadge extends StatelessWidget {
  final PillVariant variant;
  final String label;
  final bool? dot;

  const PillBadge({super.key, required this.variant, required this.label, this.dot});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    late final Color bg;
    late final Color fg;
    switch (variant) {
      case PillVariant.avail:
        bg = AppColors.teal.withValues(alpha: dark ? 0.18 : 0.12);
        fg = dark ? AppColors.teal : AppColors.tealD;
        break;
      case PillVariant.soon:
        bg = t.soft;
        fg = t.ink3;
        break;
      case PillVariant.green:
        bg = const Color(0xFF22C55E).withValues(alpha: dark ? 0.18 : 0.12);
        fg = dark ? const Color(0xFF4ADE9A) : const Color(0xFF1A9E58);
        break;
      case PillVariant.amber:
        bg = const Color(0xFFE0A51F).withValues(alpha: dark ? 0.20 : 0.14);
        fg = dark ? const Color(0xFFE0B94A) : const Color(0xFFB07C0A);
        break;
      case PillVariant.gray:
        bg = t.soft;
        fg = t.ink2;
        break;
    }
    final showDot = dot ?? (variant == PillVariant.avail);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showDot) ...[
            Container(
              width: 6,
              height: 6,
              decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
            ),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}
