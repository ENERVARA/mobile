import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';

/// Medical-themed staged status phrases shown while Nova prepares a response,
/// instead of bare dots — ported from `NovaThinking.tsx`. Advances through the
/// stages then rests on the last one until the first token streams in.
const List<String> _stages = [
  'Collecting your details',
  'Reviewing your health context',
  'Analysing the question',
  'Consulting medical knowledge',
  'Planning a clear answer',
];

const int _stageMs = 1600;

/// Animated three-dot "thinking" indicator + rotating stage caption.
class NovaThinking extends StatefulWidget {
  /// The backend idles after ~15 min and takes 10–15 s to boot. When nothing
  /// has come back yet, say so rather than letting the stage captions imply
  /// work is happening.
  final bool wakingUp;

  const NovaThinking({super.key, this.wakingUp = false});

  @override
  State<NovaThinking> createState() => _NovaThinkingState();
}

class _NovaThinkingState extends State<NovaThinking>
    with SingleTickerProviderStateMixin {
  late final AnimationController _dots;
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _dots = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    _timer = Timer.periodic(const Duration(milliseconds: _stageMs), (_) {
      if (!mounted) return;
      // Advance through the stages, then hold on the final one.
      if (_i < _stages.length - 1) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _dots.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Dots(_dots),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            widget.wakingUp ? 'Waking up the assistant…' : '${_stages[_i]}…',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: context.tokens.ink2,
            ),
          ),
        ),
      ],
    );
  }
}

class _Dots extends AnimatedWidget {
  const _Dots(AnimationController controller) : super(listenable: controller);

  double get _t => (listenable as Animation<double>).value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final delay in const [0.0, 0.2, 0.4])
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 1),
            child: _dot(delay),
          ),
      ],
    );
  }

  Widget _dot(double delaySec) {
    // Cycle = 1.2s; each dot offset by its delay, bounces once per cycle.
    final phase = (((_t - delaySec / 1.2) % 1.0) + 1.0) % 1.0;
    final lift = -3.0 * math.sin(phase * math.pi).clamp(0.0, 1.0);
    return Transform.translate(
      offset: Offset(0, lift),
      child: Container(
        width: 6,
        height: 6,
        decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
      ),
    );
  }
}
