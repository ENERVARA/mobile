import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../state/chat_provider.dart';
import '../../../../state/nova_ui_provider.dart';
import '../../../tour/tour_keys.dart';
import '../../../widgets/common.dart';
import '../../../widgets/speciality_icon.dart';

const _shownCount = 2;

/// Fetched ahead of what's shown, so there's enough signal to know whether more
/// than [_shownCount] active cares exist without a second round-trip.
const _fetchLimit = 6;

/// "Today" / "1 day ago" / "N days ago" / "N weeks ago" (`fmtWhen`).
String _fmtWhen(String iso) {
  final then = Formatters.tryParse(iso);
  if (then == null) return '';
  final days = DateTime.now().difference(then).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return '1 day ago';
  if (days < 7) return '$days days ago';
  final weeks = days ~/ 7;
  return weeks == 1 ? '1 week ago' : '$weeks weeks ago';
}

/// CTA 2 — Resume previous care. Lists the user's actual recent conversations
/// (across all specialities); tapping one re-opens that exact conversation in
/// Nova so they can pick up where they left off. Ported from `ResumeCareCard.tsx`.
class ResumeCareCard extends ConsumerStatefulWidget {
  const ResumeCareCard({super.key});

  @override
  ConsumerState<ResumeCareCard> createState() => _ResumeCareCardState();
}

class _ResumeCareCardState extends ConsumerState<ResumeCareCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        ref.read(chatProvider.notifier).loadRecentConversations(limit: _fetchLimit);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    // Resolved care has no place in "resume where you left off" — only active
    // conversations are shown here, same definition My Care uses.
    final active = chat.recentConversations.where((c) => c.isActiveCare).toList();
    final shown = active.take(_shownCount).toList();
    final hasMore = active.length > _shownCount;

    return Container(
      key: TourKeys.of('resume-care'),
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 240 - 46),
        child: IntrinsicHeight(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.lav.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  PhosphorIconsFill.clockCounterClockwise,
                  size: 22.4,
                  color: AppColors.lav,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Resume previous care',
                style: TextStyle(
                  fontSize: 17.92,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.1792,
                  height: 1.5,
                  color: t.ink,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Pick up a past consultation right where you left off.',
                style: TextStyle(fontSize: 13.76, height: 1.5, color: t.ink2),
              ),
              const SizedBox(height: 16),
              if (!chat.isLoadingRecent && shown.isEmpty)
                Expanded(
                  child: DashedBox(
                    radius: 12,
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                    child: Center(
                      child: Text(
                        'No past conversations yet — start one from "Start new care".',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink3),
                      ),
                    ),
                  ),
                )
              else
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final c in shown) ...[
                        _ConversationRow(
                          title: c.title.isEmpty ? 'New chat' : c.title,
                          specialitySlug: c.specialitySlug,
                          when: _fmtWhen(c.lastMessageAt),
                          onTap: () => ref
                              .read(novaUiProvider.notifier)
                              .openExistingConversation(c.id, c.specialitySlug),
                        ),
                        const SizedBox(height: 8),
                      ],
                      if (hasMore)
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => context.push('/care'),
                          child: const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'See all active care',
                                  style: TextStyle(
                                    fontSize: 13.28,
                                    fontWeight: FontWeight.w600,
                                    height: 1.5,
                                    color: AppColors.teal,
                                  ),
                                ),
                                SizedBox(width: 6),
                                Icon(PhosphorIconsRegular.arrowRight, size: 12.8, color: AppColors.teal),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConversationRow extends StatelessWidget {
  final String title;
  final String specialitySlug;
  final String when;
  final VoidCallback onTap;

  const _ConversationRow({
    required this.title,
    required this.specialitySlug,
    required this.when,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final spec = specialityBySlug(specialitySlug);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: spec != null ? AppColors.hex(spec.color) : AppColors.teal,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: SpecialityIcon(icon: spec?.icon ?? 'Stethoscope', size: 17, color: Colors.white),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.44,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 1),
                      child: Text(
                        '${spec?.name ?? specialitySlug} · $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11.68, height: 1.5, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Icon(PhosphorIconsRegular.caretRight, size: 14.4, color: t.ink3),
            ],
          ),
        ),
      ),
    );
  }
}
