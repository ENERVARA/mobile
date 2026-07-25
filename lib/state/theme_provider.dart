import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Light/dark theme mode, persisted to shared_preferences.
/// Mirrors `themeStore.ts` (default: light).
final themeProvider =
    StateNotifierProvider<ThemeController, ThemeMode>((ref) => ThemeController());

class ThemeController extends StateNotifier<ThemeMode> {
  ThemeController() : super(ThemeMode.light) {
    _load();
  }

  static const _key = 'enervara_theme_mode';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    switch (prefs.getString(_key)) {
      case 'dark':
        state = ThemeMode.dark;
        break;
      case 'system':
        state = ThemeMode.system;
        break;
      case 'light':
        state = ThemeMode.light;
        break;
    }
  }

  Future<void> _save(ThemeMode mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, mode.name);
  }

  bool get isDark => state == ThemeMode.dark;

  void toggle() {
    state = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    _save(state);
  }

  void setMode(ThemeMode mode) {
    state = mode;
    _save(mode);
  }
}
