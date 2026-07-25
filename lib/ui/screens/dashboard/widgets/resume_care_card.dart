import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../state/chat_provider.dart';
import '../../../widgets/speciality_icon.dart';

/// CTA 2 — "Resume previous care". Lists the user's real recent conversations;
/// tapping one re-opens it in Nova. Ported from `ResumeCareCard.tsx`.
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
      if (mounted) ref.read(chatProvider.notifier).loadRecentConversations(limit: 3);
    });
  }

  /// Mirrors the web's `fmtWhen`: Today / 1 day ago / N days ago / N weeks ago.
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

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    final recent = chat.recentConversations;

    return Container(
      constraints: const BoxConstraints(minHeight: 240),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.lav.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              PhosphorIconsFill.clockCounterClockwise,
              size: 22,
              color: AppColors.lav,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Resume previous care',
            style: TextStyle(
              fontSize: 17.9,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.18,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pick up a past consultation right where you left off.',
            style: TextStyle(fontSize: 13.8, height: 1.5, color: t.ink2),
          ),
          const SizedBox(height: 16),
          if (!chat.isLoadingRecent && recent.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: t.line),
              ),
              child: Text(
                'No past conversations yet — start one from "Start new care".',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.1, color: t.ink3),
              ),
            )
          else
            for (final c in recent) ...[
              _ConversationRow(
                title: c.title.isEmpty ? 'New chat' : c.title,
                specialitySlug: c.specialitySlug,
                when: _fmtWhen(c.lastMessageAt),
                // Re-open this exact thread, matching the web's
                // openExistingConversation(c.id, c.specialitySlug).
                onTap: () => context.push(
                  '/nova?speciality=${c.specialitySlug}&conversation=${c.id}',
                ),
              ),
              const SizedBox(height: 8),
            ],
        ],
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
    return GestureDetector(
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
              decoration: BoxDecoration(
                color: spec != null ? AppColors.hex(spec.color) : AppColors.teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: SpecialityIcon(
                icon: spec?.icon ?? 'Stethoscope',
                size: 17,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.4,
                      fontWeight: FontWeight.w600,
                      height: 1.15,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    '${spec?.name ?? specialitySlug} · $when',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.7, color: t.ink3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(PhosphorIconsRegular.caretRight, size: 14, color: t.ink3),
          ],
        ),
      ),
    );
  }
}
