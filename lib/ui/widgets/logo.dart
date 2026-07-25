import 'package:flutter/material.dart';

/// The Enervara brand logo (assets/images/logo.png). On coloured/gradient
/// surfaces pass `white: true` to render it as a white silhouette.
class Logo extends StatelessWidget {
  final double size;
  final bool white;
  const Logo({super.key, this.size = 34, this.white = false});

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
    if (!white) return image;
    // brightness(0) invert(1) → pure white silhouette, alpha preserved.
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: image,
    );
  }
}
