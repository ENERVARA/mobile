import 'package:flutter/painting.dart';

/// A box shadow specified the way CSS writes it (`x y blur spread color`).
///
/// CSS blurs a shadow with a Gaussian of sigma = blur / 2, whereas Flutter's
/// [BoxShadow.blurRadius] maps to sigma = radius * 0.57735 + 0.5 — passing a CSS
/// blur straight through renders a visibly wider, softer shadow. This converts
/// so ported shadows look the same as on the web.
BoxShadow cssShadow(
  Color color, {
  double x = 0,
  double y = 0,
  double blur = 0,
  double spread = 0,
}) {
  final sigma = blur / 2;
  final radius = sigma <= 0.5 ? 0.0 : (sigma - 0.5) / 0.57735;
  return BoxShadow(
    color: color,
    offset: Offset(x, y),
    blurRadius: radius,
    spreadRadius: spread,
  );
}
