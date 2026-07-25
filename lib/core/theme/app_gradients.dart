import 'package:flutter/material.dart';

/// Brand gradients ported from the CSS escape-hatch utilities
/// (`.bg-brand-diagonal`, `.bg-hub-hero`, `.bg-mini-brand`, …).
class AppGradients {
  AppGradients._();

  static const _teal = Color(0xFF0BB5A6);
  static const _cyanMid = Color(0xFF18A8C2);
  static const _indigo = Color(0xFF6070CC);
  static const _lav = Color(0xFF8168C4);

  /// `.bg-brand-diagonal` — near-vertical brand sweep (Nova docked panel frame).
  static const brandDiagonal = LinearGradient(
    begin: Alignment(-0.4, -1),
    end: Alignment(0.4, 1),
    colors: [_teal, _cyanMid, _indigo, _lav],
    stops: [0, 0.36, 0.70, 1],
  );

  /// `.bg-hub-hero` — 135° brand sweep (Nova hero, gradient bubbles/avatars).
  static const hubHero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_teal, _cyanMid, _indigo, _lav],
    stops: [0, 0.42, 0.78, 1],
  );

  /// `.bg-mini-brand` — teal → lavender (Nova launcher bubble).
  static const miniBrand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_teal, _lav],
  );

  /// `.bg-feature` — teal feature cards.
  static const feature = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF11B9AA), Color(0xFF0AA093), Color(0xFF088C80)],
    stops: [0, 0.52, 1],
  );

  /// `.bg-teal-cyan`
  static const tealCyan = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [_teal, Color(0xFF2CB0C8)],
  );

  /// `.bg-bar-fill` — progress fills.
  static const barFill = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [_teal, Color(0xFF2CB0C8)],
  );

  /// Full four-stop brand gradient (`.bg-brand-gradient`).
  static const brand = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF27649), Color(0xFFE85D8A), Color(0xFF9B7FE6), Color(0xFF0CC5B8)],
    stops: [0, 0.30, 0.60, 1],
  );
}
