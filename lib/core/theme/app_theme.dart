import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

/// Light + dark [ThemeData], built on the Outfit typeface and the redesign
/// token system. Screens read neutral surfaces via `context.tokens` and brand
/// accents via [AppColors].
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(Brightness.light, AppTokens.light);
  static ThemeData dark() => _build(Brightness.dark, AppTokens.dark);

  static ThemeData _build(Brightness brightness, AppTokens tokens) {
    final base = ThemeData(brightness: brightness, useMaterial3: true);

    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.teal,
      brightness: brightness,
    ).copyWith(
      primary: AppColors.teal,
      secondary: AppColors.cyan,
      surface: tokens.card,
      error: AppColors.danger,
    );

    final textTheme = GoogleFonts.outfitTextTheme(base.textTheme).apply(
      bodyColor: tokens.ink,
      displayColor: tokens.ink,
    );

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: tokens.appBg,
      canvasColor: tokens.appBg,
      textTheme: textTheme,
      extensions: [tokens],
      splashFactory: InkRipple.splashFactory,
      dividerTheme: DividerThemeData(color: tokens.line, thickness: 1, space: 1),
      iconTheme: IconThemeData(color: tokens.ink2),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        foregroundColor: tokens.ink,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: tokens.ink,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.soft,
        hintStyle: TextStyle(color: tokens.ink3),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: tokens.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: tokens.ink,
        contentTextStyle: TextStyle(color: tokens.card),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.card,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.card,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }
}
