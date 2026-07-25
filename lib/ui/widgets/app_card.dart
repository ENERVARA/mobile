import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';

/// The standard raised card surface — white/`card` fill, hairline `line`
/// border, 18px radius. `onTap` adds a ripple.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final List<BoxShadow>? shadow;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.color,
    this.borderColor,
    this.radius = 18,
    this.shadow,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final br = BorderRadius.circular(radius);
    final content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? t.card,
        borderRadius: br,
        border: Border.all(color: borderColor ?? t.line),
        boxShadow: shadow,
      ),
      child: child,
    );
    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      borderRadius: br,
      child: InkWell(
        onTap: onTap,
        borderRadius: br,
        child: content,
      ),
    );
  }
}
