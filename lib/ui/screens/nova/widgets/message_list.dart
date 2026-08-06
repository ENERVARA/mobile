import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/block_content.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/chat.dart';
import '../../../../data/services/chat_service.dart';
import '../../../../state/chat_provider.dart';
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

    final signature =
        chat.messages.length * 100000 +
        chat.streamingContent.length +
        (chat.isStreaming ? 1 : 0);
    if (signature != _lastSignature) {
      _lastSignature = signature;
      // Only follow the tail when the user is already near the bottom.
      final nearBottom =
          !_scroll.hasClients ||
          _scroll.position.pixels >= _scroll.position.maxScrollExtent - 120;
      if (nearBottom) _scrollToBottom();
    }

    final rows = <Widget>[];
    for (final m in chat.messages) {
      final panel = _toPanel(m, chat.imageUploadProgress);
      // Never render an empty assistant bubble (e.g. a turn whose only block
      // is a hidden follow_up_questions chip) — skip the row entirely, same
      // as the dashboard's MessageList.
      final body = _buildMessageBody(context, panel, panel.isUser);
      if (body == null) continue;
      rows.add(
        _MessageRow(message: panel, userInitial: widget.userInitial, body: body),
      );
    }
    if (chat.isStreaming) {
      rows.add(
        _StreamingRow(
          content: chat.streamingContent,
          blocks: chat.streamingBlocks,
        ),
      );
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
              style: TextStyle(
                fontSize: 10.7,
                fontWeight: FontWeight.w700,
                color: t.ink,
              ),
            )
          : const Logo(size: 15, white: true),
    );
  }
}

// ─── Message row ─────────────────────────────────────────────────────────────

/// Builds the rendered body for one message, or `null` when there is
/// genuinely nothing to show. Returning `null` lets the caller skip the
/// whole row so we never draw an avatar next to an empty bubble. Mirrors
/// `MessageList.tsx#buildBody`.
///
/// Emptiness guard: a message can carry blocks that all render to nothing
/// (an interview turn that's only `follow_up_questions`, or a future/unknown
/// block type). Rather than render an empty bubble, fall back to the
/// readable text those blocks carry; if there's none, render nothing at all.
Widget? _buildMessageBody(BuildContext context, PanelMessage message, bool isUser) {
  if (message.imageFileId != null) {
    return _ImageBubble(message: message, isUser: isUser);
  }

  final blocks = message.blocks;
  if (blocks != null && blocks.isNotEmpty) {
    if (blocks.any(isRenderableBlock)) {
      // At least one block renders visibly — render them all (BlockRenderer
      // hides follow_up_questions itself, so trailing chips stay hidden).
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < blocks.length; i++)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
              child: BlockRenderer(block: blocks[i]),
            ),
        ],
      );
    }
    // No block renders visibly → show the content those blocks carry (e.g.
    // the interview question) instead of an empty bubble; nothing if truly empty.
    final fallback = deriveFallbackText(message.text, blocks);
    return fallback.isEmpty ? null : novaTextBubble(context, fallback);
  }

  // Plain text / image-analysis path.
  if (isUser) {
    return _userBubble(message.text);
  }
  final analysis = message.analysis;
  final hasText = message.text.trim().isNotEmpty;
  if (!hasText && analysis == null) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      if (hasText) novaTextBubble(context, message.text),
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

class _MessageRow extends StatelessWidget {
  final PanelMessage message;
  final String userInitial;
  final Widget body;
  const _MessageRow({
    required this.message,
    required this.userInitial,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    final avatar = _Avatar(isUser: isUser, userInitial: userInitial);

    final bubble = ConstrainedBox(
      constraints: BoxConstraints(maxWidth: context.screenSize.width * 0.82),
      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          body,
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
      mainAxisAlignment: isUser
          ? MainAxisAlignment.end
          : MainAxisAlignment.start,
      children: children,
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
    // Once a message is persisted server-side, the local file-picker path is
    // gone (the echoed message from the backend never carries one) — fall
    // back to fetching the actual bytes from the JWT-protected image route.
    final canFetchRemote =
        message.imageFileId != null &&
        message.imageFileId != 'pending' &&
        !message.id.startsWith('local-');

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
                  child: Image.file(File(preview), fit: BoxFit.cover),
                )
              else if (canFetchRemote)
                _RemoteChatImage(messageId: message.id)
              else
                Container(
                  height: 140,
                  color: t.card,
                  alignment: Alignment.center,
                  child: Icon(
                    PhosphorIconsRegular.image,
                    size: 26,
                    color: t.ink3,
                  ),
                ),
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

// ─── Remote (server-persisted) chat image ────────────────────────────────────

class _RemoteChatImage extends StatefulWidget {
  final String messageId;
  const _RemoteChatImage({required this.messageId});

  @override
  State<_RemoteChatImage> createState() => _RemoteChatImageState();
}

class _RemoteChatImageState extends State<_RemoteChatImage> {
  static const _service = ChatService();
  late final Future<Uint8List> _future = _service.fetchImageBytes(
    widget.messageId,
  );

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return FutureBuilder<Uint8List>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return Container(
            height: 140,
            color: t.card,
            alignment: Alignment.center,
            child: const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        if (snap.hasError || !snap.hasData || snap.data!.isEmpty) {
          return Container(
            height: 140,
            color: t.card,
            alignment: Alignment.center,
            child: Icon(PhosphorIconsRegular.image, size: 26, color: t.ink3),
          );
        }
        return ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: Image.memory(snap.data!, fit: BoxFit.cover),
        );
      },
    );
  }
}

// ─── Media analysis card ─────────────────────────────────────────────────────

const Map<String, String> _categoryLabel = {
  'lab_report': 'Lab report',
  'prescription': 'Prescription',
  'document_extraction': 'Document analysis',
};

class _AnalysisCard extends StatelessWidget {
  final MessageAnalysis analysis;
  const _AnalysisCard({required this.analysis});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final facts = analysis.extractedFacts;
    final cat = analysis.category;
    final label = cat != null ? (_categoryLabel[cat] ?? cat) : null;
    if (label == null &&
        (analysis.caption == null || analysis.caption!.isEmpty) &&
        facts.isEmpty) {
      return const SizedBox.shrink();
    }
    final headerText = [
      label,
      analysis.caption,
    ].whereType<String>().where((s) => s.isNotEmpty).join(' — ');

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
          if (headerText.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Row(
                children: [
                  const Icon(
                    PhosphorIconsRegular.fileMagnifyingGlass,
                    size: 14,
                    color: AppColors.teal,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      headerText.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.4,
                        color: t.ink2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
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
                          decoration: const BoxDecoration(
                            color: AppColors.teal,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            facts[i],
                            style: TextStyle(
                              fontSize: 13.4,
                              height: 1.35,
                              color: t.ink,
                            ),
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
}

// ─── Live streaming row ──────────────────────────────────────────────────────

class _StreamingRow extends StatelessWidget {
  final String content;
  final List<MessageBlock> blocks;
  const _StreamingRow({required this.content, required this.blocks});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final children = <Widget>[];

    // Only count blocks that actually render something (mirrors
    // isRenderableBlock) — otherwise a turn that's so far only produced a
    // hidden follow_up_questions block would add invisible padding and never
    // fall through to the "thinking" indicator below.
    for (final b in blocks) {
      if (!isRenderableBlock(b)) continue;
      children.add(
        Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
          child: BlockRenderer(block: b),
        ),
      );
    }
    if (content.isNotEmpty) {
      children.add(
        Padding(
          padding: EdgeInsets.only(top: children.isEmpty ? 0 : 8),
          child: novaTextBubble(context, content),
        ),
      );
    }
    if (children.isEmpty) {
      // Nothing streamed yet — the staged "thinking" indicator in a soft bubble.
      children.add(
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
          child: const NovaThinking(),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Avatar(isUser: false, userInitial: ''),
        const SizedBox(width: 8),
        Flexible(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: context.screenSize.width * 0.82,
            ),
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
