import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../state/voice_provider.dart';

String _fmtElapsed(Duration d) {
  final total = d.inSeconds;
  final m = total ~/ 60;
  final s = total % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// The "listening" surface that replaces the chat input while recording.
/// Ported from `VoiceRecordBar.tsx` — live waveform, elapsed timer, and
/// cancel / confirm controls. On confirm the clip is transcribed and the
/// text is dropped into the composer for review before sending.
class VoiceRecordBar extends ConsumerWidget {
  const VoiceRecordBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final voice = ref.watch(voiceProvider);
    final transcribing = voice.status == RecorderStatus.transcribing;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: transcribing
                ? null
                : () => ref.read(voiceProvider.notifier).cancel(),
            behavior: HitTestBehavior.opaque,
            child: Opacity(
              opacity: transcribing ? 0.4 : 1,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Icon(PhosphorIconsRegular.x, size: 17, color: t.ink2),
              ),
            ),
          ),
          Expanded(
            child: transcribing
                ? Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.teal,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Transcribing…',
                        style: TextStyle(
                          fontSize: 12.6,
                          fontWeight: FontWeight.w600,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  )
                : Row(
                    children: [
                      const _PulsingDot(),
                      const SizedBox(width: 8),
                      Expanded(child: _Waveform(levels: voice.levels)),
                    ],
                  ),
          ),
          const SizedBox(width: 8),
          Text(
            _fmtElapsed(voice.elapsed),
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: t.ink2,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: transcribing
                ? null
                : () => ref.read(voiceProvider.notifier).stop(),
            child: Opacity(
              opacity: transcribing ? 0.5 : 1,
              child: Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(
                  PhosphorIconsBold.check,
                  size: 15,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PulsingDot extends StatefulWidget {
  const _PulsingDot();

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 10,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final scale = 1 + _c.value * 1.6;
          final opacity = (1 - _c.value).clamp(0.0, 1.0);
          return Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: scale,
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: AppColors.coral.withValues(alpha: 0.4 * opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: AppColors.coral,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Waveform extends StatelessWidget {
  final List<double> levels;
  const _Waveform({required this.levels});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 22,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (final lvl in levels)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 100),
                  height: (8 + lvl * 14).clamp(3, 22),
                  decoration: BoxDecoration(
                    color: AppColors.teal.withValues(alpha: 0.45 + lvl * 0.55),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
