import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/css_shadow.dart';
import '../../../../data/models/chat.dart';
import '../../../../state/nova_ui_provider.dart';
import '../../../widgets/entrance.dart';

/// How many answers sit face-up in the deck; the rest hide behind the +N card.
const int _faceUp = 3;

/// One question with tappable answers, dealt as a small deck of cards. Ported
/// from `blocks/QuestionBlock.tsx` + the `.nova-deck` / `.nova-card` /
/// `.nova-pile` styles.
///
/// A tap calls the ordinary `send()` with the option's literal text, so the
/// selection becomes a normal user turn — there is deliberately no quick-reply
/// endpoint. Only the first three answers are dealt face-up; a +N card unfolds
/// the rest. Cards are disabled while a send is in flight, so a double tap
/// cannot post two answers to the same question.
class QuestionBlockView extends ConsumerStatefulWidget {
  final QuestionBlock block;
  const QuestionBlockView({super.key, required this.block});

  @override
  ConsumerState<QuestionBlockView> createState() => _QuestionBlockViewState();
}

class _QuestionBlockViewState extends ConsumerState<QuestionBlockView> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final sending = ref.watch(novaUiProvider.select((s) => s.sending));
    final question = widget.block.question.trim();
    final options = widget.block.options;

    // A forward-incompatible payload degrades to nothing rather than an empty bubble.
    if (question.isEmpty && options.isEmpty) return const SizedBox.shrink();

    final faceUp = options.take(_faceUp).toList();
    final folded = options.skip(_faceUp).toList();

    void pick(String option) => ref.read(novaUiProvider.notifier).send(option);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (question.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
            decoration: BoxDecoration(
              color: t.soft,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
            ),
            child: Text(question, style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink)),
          ),
        if (options.isNotEmpty) ...[
          if (question.isNotEmpty) const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.end,
            children: [
              if (folded.isNotEmpty)
                _Pile(
                  count: folded.length,
                  open: _expanded,
                  onTap: () => setState(() => _expanded = !_expanded),
                ),
              for (final o in faceUp) _OptionCard(option: o, disabled: sending, onPick: pick),
            ],
          ),
          if (folded.isNotEmpty)
            AnimatedSize(
              duration: const Duration(milliseconds: 400),
              curve: kEaseSpring,
              alignment: Alignment.topLeft,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(74, 8, 4, 4),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          for (var i = 0; i < folded.length; i++)
                            Entrance(
                              from: const Offset(-24, -12),
                              duration: Duration(milliseconds: 300 + i * 55),
                              child: _OptionCard(option: folded[i], disabled: sending, onPick: pick),
                            ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
        ],
      ],
    );
  }
}

/// A portrait playing card: corner marks, the answer, nothing else.
class _OptionCard extends StatefulWidget {
  final String option;
  final bool disabled;
  final void Function(String) onPick;
  const _OptionCard({required this.option, required this.disabled, required this.onPick});

  @override
  State<_OptionCard> createState() => _OptionCardState();
}

class _OptionCardState extends State<_OptionCard> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final bracket = AppColors.teal.withValues(alpha: 0.55);
    return GestureDetector(
      onTapDown: widget.disabled ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.disabled ? null : () => widget.onPick(widget.option),
      child: Opacity(
        opacity: widget.disabled ? 0.5 : 1,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            width: 76,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: t.card,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: t.line, width: 1.5),
              boxShadow: [cssShadow(const Color(0x121A2027), y: 2, blur: 5)],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                // Corner brackets, like the marks on a court card.
                Positioned(top: -2, right: -6, child: _Bracket(color: bracket, topRight: true)),
                Positioned(bottom: -2, left: -6, child: _Bracket(color: bracket, topRight: false)),
                Text(
                  widget.option,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 11.2, fontWeight: FontWeight.w600, height: 1.2, color: t.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Bracket extends StatelessWidget {
  final Color color;
  final bool topRight;
  const _Bracket({required this.color, required this.topRight});

  @override
  Widget build(BuildContext context) {
    final side = BorderSide(color: color, width: 1.5);
    return Container(
      width: 7,
      height: 7,
      decoration: BoxDecoration(
        border: topRight ? Border(top: side, right: side) : Border(bottom: side, left: side),
      ),
    );
  }
}

/// The face-down pile: three fanned card backs with the count on top.
class _Pile extends StatelessWidget {
  final int count;
  final bool open;
  final VoidCallback onTap;
  const _Pile({required this.count, required this.open, required this.onTap});

  Widget _back(BuildContext context, {double angle = 0, Offset shift = Offset.zero, Widget? face}) {
    final t = context.tokens;
    return Transform.translate(
      offset: shift,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 54,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: t.card,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.teal.withValues(alpha: 0.55), width: 1.5),
            boxShadow: [cssShadow(const Color(0x141A2027), y: 2, blur: 5)],
          ),
          child: face,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const deg = 3.1415926535 / 180;
    return Semantics(
      button: true,
      label: open ? 'Show fewer answers' : 'Show $count more answers',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 68,
          height: 54,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (!open) _back(context, angle: -9 * deg, shift: const Offset(-5, -2)),
              if (!open) _back(context, angle: 9 * deg, shift: const Offset(5, 2)),
              _back(
                context,
                face: open
                    ? const Icon(PhosphorIconsBold.minus, size: 12.5, color: AppColors.tealD)
                    : Text(
                        '+$count',
                        style: const TextStyle(fontSize: 12.48, fontWeight: FontWeight.w700, color: AppColors.tealD),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
