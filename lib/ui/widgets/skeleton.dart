import 'package:flutter/material.dart';

import '../../core/theme/context_ext.dart';

/// Shimmering placeholder block — `.animate-shimmer` from the web design system
/// (a 90° gradient `border → surface-secondary → border`, sliding over 1.5s).
class Skeleton extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;

  const Skeleton({super.key, this.width, this.height = 40, this.radius = 8});

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1500))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    // Legacy tokens: --color-border / --color-surface-secondary.
    final base = dark ? const Color(0xFF2A2A2E) : const Color(0xFFE5E8EB);
    final mid = dark ? const Color(0xFF1C1C1F) : const Color(0xFFF0F2F5);
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        // background-size 200% 100%; position -200% → 200%.
        final dx = -2.0 + 4.0 * Curves.easeInOut.transform(_c.value);
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(dx - 1, 0),
              end: Alignment(dx + 1, 0),
              colors: [base, mid, base],
              stops: const [0.25, 0.5, 0.75],
              tileMode: TileMode.clamp,
            ),
          ),
        );
      },
    );
  }
}

/// Small centred spinner (the web `Spinner`).
class AppSpinner extends StatelessWidget {
  final double size;
  const AppSpinner({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(strokeWidth: size >= 28 ? 3 : 2.4),
    );
  }
}

/// Tailwind `animate-pulse` placeholder (`rounded-[…px] bg-soft`): opacity
/// 1 → .5 → 1 over 2s.
class PulseBlock extends StatefulWidget {
  final double? width;
  final double height;
  final double radius;
  const PulseBlock({super.key, this.width, required this.height, this.radius = 12});

  @override
  State<PulseBlock> createState() => _PulseBlockState();
}

class _PulseBlockState extends State<PulseBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 1 - 0.5 * Curves.easeInOut.transform(_c.value),
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: t.soft,
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      ),
    );
  }
}
