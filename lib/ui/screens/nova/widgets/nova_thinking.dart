import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/theme/context_ext.dart';
import '../../../widgets/entrance.dart';
import 'ecg_pulse.dart';

/// Medical-themed staged status phrases shown while Nova prepares a response,
/// paired with an ECG trace. Advances through the stages and rests on the last
/// one until the first token streams in. Ported from `NovaThinking.tsx`.
const List<String> _stages = [
  'Collecting your details',
  'Reviewing your health context',
  'Analysing the question',
  'Consulting medical knowledge',
  'Planning a clear answer',
];

const int _stageMs = 1600;

class NovaThinking extends StatefulWidget {
  const NovaThinking({super.key});

  @override
  State<NovaThinking> createState() => _NovaThinkingState();
}

class _NovaThinkingState extends State<NovaThinking> {
  Timer? _timer;
  int _i = 0;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: _stageMs), (_) {
      // Advance through the stages, then hold on the final one.
      if (mounted && _i < _stages.length - 1) setState(() => _i++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // `flex items-center gap-2 py-0.5`
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const EcgPulse(),
          const SizedBox(width: 8),
          Flexible(
            // A fresh element per stage replays the entrance (`key={i}`).
            child: Entrance.up(
              key: ValueKey(_i),
              child: Text(
                '${_stages[_i]}…',
                style: TextStyle(
                  fontSize: 13.12,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
                  color: context.tokens.ink2,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
