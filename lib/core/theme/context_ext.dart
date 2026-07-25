import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Ergonomic theme accessors used across every screen.
extension ThemeContextX on BuildContext {
  /// Neutral surface/ink tokens for the current theme.
  AppTokens get tokens => Theme.of(this).extension<AppTokens>()!;

  TextTheme get text => Theme.of(this).textTheme;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  /// MediaQuery shortcuts.
  Size get screenSize => MediaQuery.sizeOf(this);
  EdgeInsets get viewPadding => MediaQuery.viewPaddingOf(this);
}
