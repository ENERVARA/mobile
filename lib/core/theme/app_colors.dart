import 'package:flutter/material.dart';

/// Brand + semantic colour tokens, ported 1:1 from the web design system
/// (`src/styles/globals.css`).
///
/// Brand accents are theme-constant statics on [AppColors]. The neutral
/// surface/ink tokens flip with light/dark and live on the [AppTokens]
/// [ThemeExtension] so `context.tokens.card` resolves per-theme.
class AppColors {
  AppColors._();

  // ── Brand accents (constant across themes) ──
  static const teal = Color(0xFF0BB5A6);
  static const tealD = Color(0xFF099488);
  static const tealDD = Color(0xFF08766E);
  static const cyan = Color(0xFF2CB0C8);
  static const lav = Color(0xFF8168C4);
  static const coral = Color(0xFFF26440);
  static const amber = Color(0xFFE0A51F);

  // Legacy brand palette (used by a few surfaces / speciality colours)
  static const brandCoral = Color(0xFFF27649);
  static const brandPink = Color(0xFFE85D8A);
  static const brandLavender = Color(0xFF9B7FE6);

  // Semantic status tints
  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF5A623);
  static const danger = Color(0xFFEF4444);

  /// Parse a `#RRGGBB` hex string (speciality colours arrive as hex strings).
  static Color hex(String value) {
    var h = value.replaceAll('#', '').trim();
    if (h.length == 6) h = 'FF$h';
    return Color(int.parse(h, radix: 16));
  }
}

/// Neutral surface + ink tokens that flip with the theme. Mirrors the redesign
/// CSS vars: `--ink / --ink-2 / --ink-3 / --app-bg / --card / --soft / --line`.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  final Color ink; // primary text
  final Color ink2; // secondary text
  final Color ink3; // tertiary / muted text
  final Color appBg; // page background
  final Color card; // raised surface
  final Color soft; // subtle fill
  final Color line; // hairline border

  const AppTokens({
    required this.ink,
    required this.ink2,
    required this.ink3,
    required this.appBg,
    required this.card,
    required this.soft,
    required this.line,
  });

  static const light = AppTokens(
    ink: Color(0xFF1A2027),
    ink2: Color(0xFF5F6670),
    ink3: Color(0xFF9AA1AB),
    appBg: Color(0xFFEEF4F1),
    card: Color(0xFFFFFFFF),
    soft: Color(0xFFEEF5F2),
    line: Color(0xFFE7ECE9),
  );

  static const dark = AppTokens(
    ink: Color(0xFFF4F4F5),
    ink2: Color(0xFFA1A1AA),
    ink3: Color(0xFF63636B),
    appBg: Color(0xFF0A0A0B),
    card: Color(0xFF141416),
    soft: Color(0xFF1C1C1F),
    line: Color(0xFF2A2A2E),
  );

  @override
  AppTokens copyWith({
    Color? ink,
    Color? ink2,
    Color? ink3,
    Color? appBg,
    Color? card,
    Color? soft,
    Color? line,
  }) {
    return AppTokens(
      ink: ink ?? this.ink,
      ink2: ink2 ?? this.ink2,
      ink3: ink3 ?? this.ink3,
      appBg: appBg ?? this.appBg,
      card: card ?? this.card,
      soft: soft ?? this.soft,
      line: line ?? this.line,
    );
  }

  @override
  AppTokens lerp(covariant ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    return AppTokens(
      ink: Color.lerp(ink, other.ink, t)!,
      ink2: Color.lerp(ink2, other.ink2, t)!,
      ink3: Color.lerp(ink3, other.ink3, t)!,
      appBg: Color.lerp(appBg, other.appBg, t)!,
      card: Color.lerp(card, other.card, t)!,
      soft: Color.lerp(soft, other.soft, t)!,
      line: Color.lerp(line, other.line, t)!,
    );
  }
}
