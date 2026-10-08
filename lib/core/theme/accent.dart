import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Soft-tinted background + solid foreground per accent (report / metric icons).
/// Ported from `src/lib/accent.ts` (`ACCENT_STYLE`).
enum Accent { teal, coral, lav, cyan, amber }

class AccentStyle {
  final Color background;
  final Color color;
  const AccentStyle(this.background, this.color);
}

/// `rgba(11,181,166,.13)` etc. — the exact tints the web uses.
const Map<Accent, AccentStyle> kAccentStyle = {
  Accent.teal: AccentStyle(Color(0x210BB5A6), AppColors.teal),
  Accent.coral: AccentStyle(Color(0x21F26440), AppColors.coral),
  Accent.lav: AccentStyle(Color(0x218168C4), AppColors.lav),
  Accent.cyan: AccentStyle(Color(0x212CB0C8), AppColors.cyan),
  Accent.amber: AccentStyle(Color(0x26E0A51F), AppColors.amber),
};

extension AccentX on Accent {
  AccentStyle get style => kAccentStyle[this]!;
}
