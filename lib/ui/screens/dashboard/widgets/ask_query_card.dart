import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../data/services/medical_query_service.dart';

const _tryAsking = [
  'I have a headache and mild fever',
  'What could cause chest tightness?',
  'Best diet for acid reflux',
];

class _QAItem {
  final bool isUser;
  final String text;
  const _QAItem(this.isUser, this.text);
}

/// CTA 3 — "Ask a medical query". A general-question box on the hub-hero
/// gradient: the user describes how they feel, triage answers, and when it
/// reads like symptoms a CTA into the matching speciality appears.
/// Ported from `AskQueryCard.tsx`.
class AskQueryCard extends StatefulWidget {
  const AskQueryCard({super.key});

  @override
  State<AskQueryCard> createState() => _AskQueryCardState();
}

class _AskQueryCardState extends State<AskQueryCard> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _service = const MedicalQueryService();

  final List<_QAItem> _items = [];
  SuggestedSpeciality? _suggestion;
  bool _loading = false;

  bool get _hasThread => _items.isNotEmpty;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _ask(String text) async {
    final t = text.trim();
    if (t.isEmpty || _loading) return;
    _controller.clear();
    setState(() {
      _suggestion = null;
      _items.add(_QAItem(true, t));
      _loading = true;
    });
    _scrollToEnd();
    try {
      final res = await _service.askMedicalQuery(t);
      if (!mounted) return;
      setState(() {
        _items.add(_QAItem(false, res.answer));
        _suggestion = res.suggestedSpeciality;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _items.add(const _QAItem(false, 'Something went wrong — please try again.')));
    } finally {
      if (mounted) setState(() => _loading = false);
      _scrollToEnd();
    }
  }

  void _reset() {
    setState(() {
      _items.clear();
      _suggestion = null;
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // A fixed height (not just minHeight) so the Expanded message-thread
      // area below has a bounded constraint to size against — this widget
      // sits inside a ListView, which gives its children unbounded height,
      // and minHeight-only leaves that unbounded max in place.
      height: 460,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppGradients.hubHero,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header ──
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(PhosphorIconsFill.sparkle, size: 12, color: Colors.white),
                          SizedBox(width: 6),
                          Text('Nova',
                              style: TextStyle(
                                  fontSize: 10.9, fontWeight: FontWeight.w600, color: Colors.white)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      'Ask a medical query',
                      style: TextStyle(
                        fontSize: 17.9,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        letterSpacing: -0.18,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
              if (_hasThread)
                GestureDetector(
                  onTap: _reset,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'Clear',
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Body ──
          Expanded(
            child: SingleChildScrollView(
              controller: _scroll,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!_hasThread) ...[
                    Text(
                      "Ask a general health question. If it reads like symptoms, I'll point you to the right specialist.",
                      style: TextStyle(
                        fontSize: 13.1,
                        height: 1.5,
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'TRY ASKING',
                      style: TextStyle(
                        fontSize: 10.9,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.1,
                        color: Colors.white.withValues(alpha: 0.55),
                      ),
                    ),
                    const SizedBox(height: 8),
                    for (final prompt in _tryAsking) ...[
                      GestureDetector(
                        onTap: () => _ask(prompt),
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
                          ),
                          child: Text(
                            prompt,
                            style: TextStyle(
                              fontSize: 12.8,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                    ],
                  ],

                  // Thread
                  for (final m in _items) ...[
                    Align(
                      alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.88,
                        alignment: m.isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: m.isUser ? 0.25 : 0.10),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          child: Text(
                            m.text,
                            style: TextStyle(
                              fontSize: 13.1,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: m.isUser ? 1 : 0.95),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  if (_loading)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const _TypingDots(),
                    ),

                  // Triage CTA
                  if (_suggestion != null && !_loading)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                      ),
                      child: Column(
                        children: [
                          GestureDetector(
                            onTap: () => context.push('/nova?speciality=${_suggestion!.slug}'),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(PhosphorIconsFill.stethoscope,
                                      size: 15, color: AppColors.tealD),
                                  const SizedBox(width: 7),
                                  Flexible(
                                    child: Text(
                                      'Talk to ${_suggestion!.name}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontSize: 13.4,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.tealD,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(PhosphorIconsBold.arrowRight,
                                      size: 13, color: AppColors.tealD),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _suggestion!.reason,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              height: 1.35,
                              color: Colors.white.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          // ── Composer ──
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.fromLTRB(13, 5, 5, 5),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    onSubmitted: _ask,
                    textInputAction: TextInputAction.send,
                    style: const TextStyle(fontSize: 13.6, color: Colors.white),
                    decoration: InputDecoration(
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                      hintText: 'Describe your symptoms…',
                      hintStyle: TextStyle(
                        fontSize: 13.6,
                        color: Colors.white.withValues(alpha: 0.6),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _loading ? null : () => _ask(_controller.text),
                  child: Opacity(
                    opacity: _loading ? 0.5 : 1,
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(PhosphorIconsBold.arrowUp,
                          size: 15, color: AppColors.tealD),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(3, (i) {
          final phase = (_c.value + i * 0.15) % 1.0;
          final lift = (phase < 0.5 ? phase : 1 - phase) * 6;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.5),
            child: Transform.translate(
              offset: Offset(0, -lift),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.7),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
