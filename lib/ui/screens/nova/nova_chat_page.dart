import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/constants/nova_data.dart';
import '../../../data/constants/specialities.dart';
import '../../../state/auth_provider.dart';
import '../../../state/chat_provider.dart';
import '../../../state/nova_ui_provider.dart';
import '../../widgets/logo.dart';
import '../../widgets/nova_orb.dart';
import 'widgets/message_list.dart';
import 'widgets/nova_composer.dart';

/// Fullscreen Nova chat — redesigned white background with teal Nova bubbles,
/// cyan user bubbles and the gradient dot-sphere orb. Mirrors `ChatPanel.tsx`.
class NovaChatPage extends ConsumerStatefulWidget {
  final String? specialitySlug;

  /// When set (Resume previous care), re-opens that exact past conversation
  /// instead of starting from the speciality's most recent thread.
  final String? conversationId;

  const NovaChatPage({super.key, this.specialitySlug, this.conversationId});

  @override
  ConsumerState<NovaChatPage> createState() => _NovaChatPageState();
}

class _NovaChatPageState extends ConsumerState<NovaChatPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final notifier = ref.read(novaUiProvider.notifier);
      final conversationId = widget.conversationId;
      if (conversationId != null && conversationId.isNotEmpty) {
        notifier.openExistingConversation(
          conversationId,
          widget.specialitySlug ?? kDefaultSpecialitySlug,
        );
      } else {
        notifier.open(slug: widget.specialitySlug);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    final slug = ref.watch(novaUiProvider.select((s) => s.specialitySlug));
    final user = ref.watch(authProvider.select((s) => s.user));
    final userInitial = user?.initial ?? 'U';

    final showEmpty = chat.messages.isEmpty && !chat.isStreaming;

    return Scaffold(
      backgroundColor: t.card,
      body: SafeArea(
        child: Column(
          children: [
            _header(context, slug),
            Divider(height: 1, thickness: 1, color: t.line),
            Expanded(
              child: showEmpty
                  ? _EmptyState(firstName: user?.firstName)
                  : MessageList(userInitial: userInitial),
            ),
            const NovaComposer(),
          ],
        ),
      ),
    );
  }

  Widget _header(BuildContext context, String? slug) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 8, 12, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => context.pop(),
            icon: Icon(PhosphorIconsRegular.arrowLeft, size: 20, color: t.ink),
            splashRadius: 22,
          ),
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
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
                  style: TextStyle(fontSize: 15.2, fontWeight: FontWeight.w700, color: t.ink),
                ),
                Text(
                  specialityName(slug),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            onPressed: () => _showHistorySheet(context),
            icon: Icon(PhosphorIconsRegular.clockCounterClockwise, size: 20, color: t.ink2),
            splashRadius: 22,
            tooltip: 'Previous conversations',
          ),
          GestureDetector(
            onTap: () => ref.read(novaUiProvider.notifier).newChat(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.teal,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(PhosphorIconsRegular.plus, size: 14, color: Colors.white),
                  SizedBox(width: 6),
                  Text(
                    'New chat',
                    style: TextStyle(fontSize: 12.8, fontWeight: FontWeight.w600, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showHistorySheet(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _HistorySheet(),
    );
  }
}

// ─── Conversation history sheet ──────────────────────────────────────────────

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    final conversations = [...chat.conversations]
      ..sort((a, b) {
        final da = Formatters.tryParse(a.lastMessageAt) ?? DateTime(0);
        final db = Formatters.tryParse(b.lastMessageAt) ?? DateTime(0);
        return db.compareTo(da);
      });

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.75),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(999)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Previous conversations',
                    style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700, color: t.ink),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, size: 20, color: t.ink3),
                ),
              ],
            ),
          ),
          Flexible(
            child: conversations.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
                    child: Text(
                      'No previous conversations yet.',
                      style: TextStyle(fontSize: 13.5, color: t.ink3),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: conversations.length,
                    itemBuilder: (context, i) {
                      final c = conversations[i];
                      final active = c.id == chat.activeConversationId;
                      final when = Formatters.tryParse(c.lastMessageAt);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            ref.read(chatProvider.notifier).openConversation(c.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: active ? AppColors.teal.withValues(alpha: 0.08) : t.soft,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: active ? AppColors.teal.withValues(alpha: 0.4) : t.line,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  PhosphorIconsRegular.chatCircleText,
                                  size: 18,
                                  color: active ? AppColors.teal : t.ink3,
                                ),
                                const SizedBox(width: 11),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        c.title.isEmpty ? 'New chat' : c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 13.8,
                                          fontWeight: FontWeight.w600,
                                          color: t.ink,
                                        ),
                                      ),
                                      if (when != null) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          Formatters.timeAgo(when),
                                          style: TextStyle(fontSize: 11.5, color: t.ink3),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(PhosphorIconsRegular.caretRight, size: 15, color: t.ink3),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state: orb + greeting + quick actions ────────────────────────────

class _EmptyState extends ConsumerWidget {
  final String? firstName;
  const _EmptyState({this.firstName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NovaOrb(preset: OrbPreset.chat),
            const SizedBox(height: 18),
            Text(
              novaGreeting(firstName),
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.45, color: t.ink),
            ),
            const SizedBox(height: 22),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final qa in kNovaDefaultQuick)
                  _QuickChip(
                    action: qa,
                    onTap: () => ref.read(novaUiProvider.notifier).send(qa.text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  final QuickAction action;
  final VoidCallback onTap;
  const _QuickChip({required this.action, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: t.soft,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: t.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 16, color: AppColors.teal),
            const SizedBox(width: 7),
            Text(
              action.label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: t.ink),
            ),
          ],
        ),
      ),
    );
  }
}
