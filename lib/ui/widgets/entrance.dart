import 'package:flutter/material.dart';

/// `cubic-bezier(.22, 1, .36, 1)` — the dashboard's `--ease-spring`.
const Curve kEaseSpring = Cubic(0.22, 1, 0.36, 1);

/// A one-shot entrance that plays when the widget is first inserted: fades in
/// while sliding from [from] (logical px) to its resting place. Covers the
/// dashboard's `animate-msg-in` (up 8px, .28s), `animate-msg-left/right`
/// (±38px, .38s) and similar keyframes.
class Entrance extends StatefulWidget {
  final Widget child;
  final Offset from;
  final Duration duration;

  /// When false the child is shown immediately, with no animation.
  final bool animate;

  const Entrance({
    super.key,
    required this.child,
    this.from = const Offset(0, 8),
    this.duration = const Duration(milliseconds: 280),
    this.animate = true,
  });

  /// `animate-msg-in`
  const Entrance.up({super.key, required this.child, this.animate = true})
    : from = const Offset(0, 8),
      duration = const Duration(milliseconds: 280);

  /// `animate-msg-left` — Nova's replies fly in from the left edge.
  const Entrance.fromLeft({super.key, required this.child, this.animate = true})
    : from = const Offset(-38, 0),
      duration = const Duration(milliseconds: 380);

  /// `animate-msg-right` — the user's own message flies in from the right edge.
  const Entrance.fromRight({super.key, required this.child, this.animate = true})
    : from = const Offset(38, 0),
      duration = const Duration(milliseconds: 380);

  @override
  State<Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<Entrance> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: widget.animate ? 0 : 1,
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_c.isCompleted) return widget.child;
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final k = kEaseSpring.transform(_c.value);
        return Opacity(
          opacity: k.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(widget.from.dx * (1 - k), widget.from.dy * (1 - k)),
            child: child,
          ),
        );
      },
    );
  }
}
