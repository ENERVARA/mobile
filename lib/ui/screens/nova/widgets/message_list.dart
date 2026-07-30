import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/chat.dart';
import '../../../../state/chat_provider.dart';
import '../../../../state/nova_ui_provider.dart';
import '../../../widgets/logo.dart';
import 'nova_blocks.dart';
import 'nova_thinking.dart';

/// Scrolling message thread (white surface, soft Nova bubbles, teal user
/// bubbles). Mirrors `MessageList.tsx` + the live streaming bubble from
/// `ChatPanel.tsx`.
class MessageList extends ConsumerStatefulWidget {
  final String userInitial;
  const MessageList({super.key, required this.userInitial});

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Signature of what's on screen — only when this grows do we auto-scroll,
  /// so the user can read back through history mid-stream without being
  /// yanked to the bottom on every rebuild (web scrolls on messages/typing only).
  int _lastSignature = -1;

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);

    final signature = chat.messages.length * 100000 +
        chat.streamingContent.length +
        (chat.isStreaming ? 1 : 0);
    if (signature != _lastSignature) {
      _lastSignature = signature;
      // Only follow the tail when the user is already near the bottom.
      final nearBottom = !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
      if (nearBottom) _scrollToBottom();
    }

    final rows = <Widget>[];
    for (final m in chat.messages) {
      rows.add(_MessageRow(
        message: _toPanel(m, chat.imageUploadProgress),
        userInitial: widget.userInitial,
      ));
    }
    if (chat.isStreaming) {
      rows.add(_StreamingRow(
        content: chat.streamingContent,
        blocks: chat.streamingBlocks,
        wakingUp: chat.isWakingUp,
      ));
    }

    // The suggested reply only makes sense while it's still the newest turn.
    final followUp = chat.isStreaming || chat.isSendingImage
        ? null
        : _pendingFollowUp(chat.messages);
    if (followUp != null) {
      rows.add(Padding(
        // Line the chip up with the bubbles, past the avatar gutter.
        padding: const EdgeInsets.only(left: 34, top: 2),
        child: Align(
          alignment: Alignment.centerLeft,
          child: FollowUpChip(
            question: followUp,
            onTap: () => ref.read(novaUiProvider.notifier).send(followUp),
          ),
        ),
      ));
    }

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      children: [
        for (final r in rows)
          Padding(padding: const EdgeInsets.only(bottom: 10), child: r),
      ],
    );
  }

  /// The single follow-up question offered by the last assistant turn, if that
  /// turn is still the tail of the thread. The contract caps it at one; anything
  /// beyond the first is ignored rather than rendered as a wall of chips.
  String? _pendingFollowUp(List<ChatMessage> messages) {
    if (messages.isEmpty) return null;
    final last = messages.last;
    if (last.role != 'assistant') return null;

    final fromBlocks = last.blocks
        ?.whereType<FollowUpQuestionsBlock>()
        .expand((b) => b.questions)
        .where((q) => q.trim().isNotEmpty);
    if (fromBlocks != null && fromBlocks.isNotEmpty) return fromBlocks.first.trim();

    final fromField = last.followupQuestions?.where((q) => q.trim().isNotEmpty);
    if (fromField != null && fromField.isNotEmpty) return fromField.first.trim();
    return null;
  }

  PanelMessage _toPanel(ChatMessage m, int? uploadProgress) {
    final dt = Formatters.tryParse(m.createdAt);
    return PanelMessage(
      id: m.id,
      role: m.role == 'user' ? 'user' : 'nova',
      text: m.content,
      time: dt != null ? Formatters.messageTime(dt) : '',
      blocks: m.blocks,
      imageFileId: m.imageFileId,
      imageMimeType: m.imageMimeType,
      localPreviewUrl: m.localPreviewUrl,
      uploadProgress: m.imageFileId == 'pending' ? uploadProgress : null,
      analysis: m.analysis,
    );
  }
}

// ─── Avatar ──────────────────────────────────────────────────────────────────

class _Avatar extends StatelessWidget {
  final bool isUser;
  final String userInitial;
  const _Avatar({required this.isUser, required this.userInitial});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isUser ? t.soft : AppColors.teal,
        shape: BoxShape.circle,
        border: isUser ? Border.all(color: t.line) : null,
      ),
      child: isUser
          ? Text(
              userInitial,
              style: TextStyle(fontSize: 10.7, fontWeight: FontWeight.w700, color: t.ink),
            )
          : const Logo(size: 15, white: true),
    );
  }
}

// ─── Message row ─────────────────────────────────────────────────────────────

class _MessageRow extends StatelessWidget {
  final PanelMessage message;
  final String userInitial;
  const _MessageRow({required this.message, required this.userInitial});

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final avatar = _Avatar(isUser: isUser, userInitial: userInitial);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.screenSize.width * 0.82),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _content(context, isUser),
          if (message.time.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                message.time,
                style: TextStyle(fontSize: 10, color: context.tokens.ink3),
              ),
            ),
        ],
      ),
    );

    final children = isUser
        ? [bubble, const SizedBox(width: 8), avatar]
        : [avatar, const SizedBox(width: 8), bubble];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: children,
    );
  }

  Widget _content(BuildContext context, bool isUser) {
    if (message.imageFileId != null) {
      return _ImageBubble(message: message, isUser: isUser);
    }
    final analysis = message.analysis;
    final blocks = message.blocks;
    if (blocks != null && blocks.isNotEmpty) {
      final calm = isCrisisTurn(blocks);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: BlockRenderer(block: blocks[i], calmCritical: calm),
            ),
          // An image turn can carry both — don't let the blocks swallow the
          // "what we made of your upload" card.
          if (analysis != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: _AnalysisCard(analysis: analysis),
            ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        isUser ? _userBubble(message.text) : novaTextBubble(context, message.text),
        if (analysis != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AnalysisCard(analysis: analysis),
          ),
      ],
    );
  }

  Widget _userBubble(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
      decoration: const BoxDecoration(
        color: AppColors.teal,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(4),
          bottomRight: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 13.8, height: 1.4, color: Colors.white),
      ),
    );
  }
}

// ─── Image bubble ────────────────────────────────────────────────────────────

class _ImageBubble extends StatelessWidget {
  final PanelMessage message;
  final bool isUser;
  const _ImageBubble({required this.message, required this.isUser});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final radius = isUser
        ? const BorderRadius.only(
            topLeft: Radius.circular(16),
            topRight: Radius.circular(4),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(4),
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          );
    final caption = message.text;
    final showCaption = caption.isNotEmpty && caption != 'Sent an image';
    final progress = message.uploadProgress;
    final preview = message.localPreviewUrl;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: isUser ? AppColors.teal : t.soft,
        borderRadius: radius,
        border: isUser ? null : Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            children: [
              if (preview != null && preview.isNotEmpty)
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: Image.file(
                    File(preview),
                    fit: BoxFit.cover,
                    // The picker writes to a cache dir the OS can reclaim.
                    errorBuilder: (_, __, ___) => _imagePlaceholder(t),
                  ),
                )
              else
                // No on-device copy — an upload from an earlier session.
                _imagePlaceholder(t),
              if (progress != null)
                Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black.withValues(alpha: 0.4),
                    child: Center(
                      child: Text(
                        'Sending… $progress%',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (showCaption)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
              child: Text(
                caption,
                style: TextStyle(
                  fontSize: 13.8,
                  height: 1.4,
                  color: isUser ? Colors.white : t.ink,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _imagePlaceholder(AppTokens t) {
  return Container(
    height: 140,
    color: t.card,
    alignment: Alignment.center,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(PhosphorIconsRegular.image, size: 26, color: t.ink3),
        const SizedBox(height: 6),
        Text(
          'Image sent',
          style: TextStyle(fontSize: 11.5, color: t.ink3),
        ),
      ],
    ),
  );
}

// ─── Media analysis card ─────────────────────────────────────────────────────

/// What the backend made of an upload. The service classifies the image itself
/// and reports back via `category` / `route`, so this just reflects its
/// decision — a photo it looked at, or a document it parsed.
class _AnalysisCard extends StatelessWidget {
  final MessageAnalysis analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final facts = analysis.extractedFacts;
    if (analysis.isEmpty) return const SizedBox.shrink();

    final label = analysis.categoryLabel;
    final caption = analysis.caption?.trim();
    final isDoc = analysis.isDocument;

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: t.soft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (label != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  Icon(
                    isDoc
                        ? PhosphorIconsRegular.fileMagnifyingGlass
                        : PhosphorIconsRegular.camera,
                    size: 14,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: t.ink2,
                      ),
                    ),
                  ),
                  if (analysis.sizeBytes != null)
                    Text(
                      _fileSize(analysis.sizeBytes!),
                      style: TextStyle(fontSize: 10.5, color: t.ink3),
                    ),
                ],
              ),
            ),
          if (caption != null && caption.isNotEmpty) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                caption,
                style: TextStyle(fontSize: 12.9, height: 1.35, color: t.ink2),
              ),
            ),
          ],
          if (facts.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(
                color: t.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < facts.length; i++) ...[
                    if (i > 0) const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 5,
                          height: 5,
                          decoration: const BoxDecoration(color: AppColors.teal, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            facts[i],
                            style: TextStyle(fontSize: 13.4, height: 1.35, color: t.ink),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _fileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
}

// ─── Live streaming row ──────────────────────────────────────────────────────

class _StreamingRow extends StatelessWidget {
  final String content;
  final List<MessageBlock> blocks;
  final bool wakingUp;
  const _StreamingRow({required this.content, required this.blocks, this.wakingUp = false});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final children = <Widget>[];

    if (blocks.isNotEmpty) {
      final calm = isCrisisTurn(blocks);
      for (var i = 0; i < blocks.length; i++) {
        children.add(Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: BlockRenderer(block: blocks[i], calmCritical: calm),
        ));
      }
    }
    if (content.isNotEmpty) {
      children.add(Padding(
        padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
        child: novaTextBubble(context, content),
      ));
    }
    if (children.isEmpty) {
      // Nothing streamed yet — the staged "thinking" indicator in a soft bubble.
      children.add(Container(
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
        child: NovaThinking(wakingUp: wakingUp),
      ));
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Avatar(isUser: false, userInitial: ''),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: context.screenSize.width * 0.82),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
