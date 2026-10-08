import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/css_shadow.dart';
import '../../../data/constants/nova_data.dart';
import '../../../data/constants/specialities.dart';
import '../../../state/auth_provider.dart';
import '../../../state/care_journey_provider.dart';
import '../../../state/chat_provider.dart';
import '../../../state/nova_ui_provider.dart';
import '../../widgets/entrance.dart';
import '../../widgets/logo.dart';
import 'widgets/care_journey_rail.dart';
import 'widgets/doctor_summary_cta.dart';
import 'widgets/message_list.dart';
import 'widgets/nova_composer.dart';
import 'widgets/nova_leaf_tree.dart';
import 'widgets/soap_note_panel.dart';

// A swipe shorter than this (px) or more vertical than horizontal is a scroll,
// not a gesture — ignored so scrolling the thread never flips the drawer.
const double _swipeThresholdPx = 70;

/// The Nova chat panel — the full-height overlay AppShell slides in under the
/// header on mobile. Ported from the mobile branch of `ChatPanel.tsx`: a
/// gradient-washed header (avatar, speciality, swipe hint, close), a thread
/// surface with the leaf tree growing behind the messages, the composer, a
/// care-journey drawer that swipes in from the right, and the doctor-summary
/// SOAP takeover.
class NovaPanel extends ConsumerStatefulWidget {
  const NovaPanel({super.key});

  @override
  ConsumerState<NovaPanel> createState() => _NovaPanelState();
}

class _NovaPanelState extends ConsumerState<NovaPanel> {
  // Shared with the leaf tree so its reveal reads off the very scroll position
  // the message list scrolls — one source of truth.
  final _scroll = ScrollController();

  // Mobile has no fullscreen hub to show the care journey in, so a swipe left over
  // the thread drops it in as a right-sliding bar; swiping right (or the header
  // button) returns to the chat.
  bool _timelineOpen = false;
  Offset? _touchStart;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent e) => _touchStart = e.position;

  void _onPointerUp(PointerUpEvent e) {
    final start = _touchStart;
    _touchStart = null;
    if (start == null) return;
    final dx = e.position.dx - start.dx;
    final dy = e.position.dy - start.dy;
    if (dx.abs() < _swipeThresholdPx || dx.abs() < dy.abs() * 1.5) return;
    setState(() => _timelineOpen = dx < 0);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final slug = ref.watch(novaUiProvider.select((s) => s.specialitySlug));
    final firstName = ref.watch(authProvider.select((s) => s.user?.firstName));
    final userInitial = ref.watch(authProvider.select((s) => s.user?.initial)) ?? 'U';
    final soapStatus = ref.watch(chatProvider.select((s) => s.soap.status));
    final activeId = ref.watch(chatProvider.select((s) => s.activeConversationId));
    final showDoctorSummary = ref.watch(
      chatProvider.select((s) => s.activeConversationId != null && s.doctorSummaryReady[s.activeConversationId] == true),
    );
    final journey = ref.watch(currentCareJourneyProvider);
    final resolvedSlug = isSpecialityEnabled(slug) ? slug : kDefaultSpecialitySlug;

    // A fresh conversation always starts on the chat, never mid-swipe into a
    // stale timeline.
    ref.listen<String?>(chatProvider.select((s) => s.activeConversationId), (prev, next) {
      if (prev != next && _timelineOpen) setState(() => _timelineOpen = false);
    });

    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: ColoredBox(
        color: t.card,
        child: Stack(
          children: [
            Column(
              children: [
                _Header(
                  specialityName: specialityName(slug),
                  timelineOpen: _timelineOpen,
                  onToggleTimeline: () => setState(() => _timelineOpen = !_timelineOpen),
                  onClose: () => ref.read(novaUiProvider.notifier).closeChat(),
                ),
                // Thread surface. The tree grows leaves behind the messages as the
                // thread scrolls, inset 10px and anchored just above the composer.
                Expanded(
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [t.card, t.soft],
                        ),
                      ),
                      child: Stack(
                        children: [
                          // `radial-gradient(… rgba(11,181,166,.07), transparent 70%)`
                          // — a faint teal wash at the top of the thread.
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                gradient: RadialGradient(
                                  center: Alignment.topCenter,
                                  radius: 1.0,
                                  colors: [AppColors.teal.withValues(alpha: 0.07), AppColors.teal.withValues(alpha: 0)],
                                  stops: const [0, 0.7],
                                ),
                              ),
                            ),
                          ),
                          NovaLeafTree(controller: _scroll),
                          Positioned.fill(
                            child: MessageList(
                              userInitial: userInitial,
                              specialitySlug: resolvedSlug,
                              controller: _scroll,
                              greeting: novaGreeting(firstName),
                            ),
                          ),
                          if (showDoctorSummary)
                            Positioned(
                              left: 0,
                              right: 0,
                              bottom: 0,
                              child: DoctorSummaryCta(
                                onTap: () => ref.read(chatProvider.notifier).generateSoap(),
                                loading: soapStatus == SoapStatus.loading,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const NovaComposer(),
              ],
            ),

            // Care-journey drawer — a full takeover of the chat column, so only
            // the app header stays visible above it.
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !_timelineOpen,
                child: AnimatedSlide(
                  offset: _timelineOpen ? Offset.zero : const Offset(1, 0),
                  duration: const Duration(milliseconds: 300),
                  curve: kEaseSpring,
                  child: Listener(
                    behavior: HitTestBehavior.translucent,
                    onPointerDown: _onPointerDown,
                    onPointerUp: _onPointerUp,
                    child: ColoredBox(
                      color: t.card,
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => setState(() => _timelineOpen = false),
                              child: const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(PhosphorIconsRegular.arrowRight, size: 13.6, color: AppColors.teal),
                                    SizedBox(width: 6),
                                    Text(
                                      'Back to chat',
                                      style: TextStyle(
                                        fontSize: 13.6,
                                        fontWeight: FontWeight.w600,
                                        height: 1.5,
                                        color: AppColors.teal,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            CareJourneyRail(journey: journey),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Doctor-summary SOAP note — full-takeover overlay of the chat column,
            // never a chat message.
            if (soapStatus != SoapStatus.idle && activeId != null) const SoapNotePanel(),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String specialityName;
  final bool timelineOpen;
  final VoidCallback onToggleTimeline;
  final VoidCallback onClose;
  const _Header({
    required this.specialityName,
    required this.timelineOpen,
    required this.onToggleTimeline,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: t.line)),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.teal.withValues(alpha: 0.06), AppColors.teal.withValues(alpha: 0)],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: AppGradients.tealCyan,
                    boxShadow: [cssShadow(AppColors.teal.withValues(alpha: 0.65), y: 3, blur: 10, spread: -3)],
                  ),
                  child: const Logo(size: 19, white: true),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Nova',
                        style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, height: 1.25, color: t.ink),
                      ),
                      Text(
                        specialityName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.52, fontWeight: FontWeight.w500, height: 1.25, color: t.ink3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _SwipeHint(open: timelineOpen, onTap: onToggleTimeline),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(9)),
              child: Icon(PhosphorIconsRegular.x, size: 15.2, color: t.ink2),
            ),
          ),
        ],
      ),
    );
  }
}

/// "‹ Swipe left" / "Swipe right ›" — toggles the care-journey drawer, its caret
/// nudging in the swipe direction (`animate-nudge-left/right`).
class _SwipeHint extends StatefulWidget {
  final bool open;
  final VoidCallback onTap;
  const _SwipeHint({required this.open, required this.onTap});

  @override
  State<_SwipeHint> createState() => _SwipeHintState();
}

class _SwipeHintState extends State<_SwipeHint> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);
  late final Animation<double> _k = CurvedAnimation(parent: _c, curve: Curves.easeInOut);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final open = widget.open;
    final caret = AnimatedBuilder(
      animation: _k,
      builder: (context, child) => Transform.translate(offset: Offset((open ? 5 : -5) * _k.value, 0), child: child),
      child: Icon(
        open ? PhosphorIconsBold.caretRight : PhosphorIconsBold.caretLeft,
        size: 12.8,
        color: AppColors.teal,
      ),
    );
    final label = Text(
      open ? 'Swipe right' : 'Swipe left',
      style: const TextStyle(fontSize: 11.84, fontWeight: FontWeight.w600, color: AppColors.teal),
    );
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: open ? [label, const SizedBox(width: 4), caret] : [caret, const SizedBox(width: 4), label],
        ),
      ),
    );
  }
}
