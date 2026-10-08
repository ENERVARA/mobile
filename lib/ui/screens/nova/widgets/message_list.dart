import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/block_content.dart';
import '../../../../core/utils/css_shadow.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../data/models/chat.dart';
import '../../../../data/services/chat_service.dart';
import '../../../../state/chat_provider.dart';
import '../../../widgets/entrance.dart';
import '../../../widgets/speciality_icon.dart';
import 'nova_blocks.dart';
import 'nova_thinking.dart';

/// Scrolling message thread (card/soft surface, teal-hairline Nova bubbles, teal
/// user bubbles). Ported from `MessageList.tsx` plus the thread assembly in
/// `ChatPanel.tsx` (greeting when empty, live streaming bubble, typing row).
class MessageList extends ConsumerStatefulWidget {
  final String userInitial;

  /// Drives Nova's avatar — the answering speciality's own icon.
  final String? specialitySlug;

  /// Shared with the leaf tree, which reveals leaves off this scroll position.
  final ScrollController controller;

  /// Nova's opening line, shown while the thread is empty.
  final String greeting;

  const MessageList({
    super.key,
    required this.userInitial,
    required this.specialitySlug,
    required this.controller,
    required this.greeting,
  });

  @override
  ConsumerState<MessageList> createState() => _MessageListState();
}

class _MessageListState extends ConsumerState<MessageList> {
  /// Signature of what's on screen — only when this grows do we auto-scroll.
  int _lastSignature = -1;
  int _lastCount = 0;

  // One visible Nova reply passes through three different ids: the live
  // `streaming` bubble, a `local-…` id when the stream finalises, then the server
  // id after the post-send refetch. Each re-key remounts the row, so a naive
  // entrance would slide the same bubble in three times — cache the decision per
  // id and treat a re-key carrying identical text as the same bubble.
  final Map<String, bool> _animDecisions = {};
  String? _lastNovaText;

  bool _shouldAnimate(PanelMessage m) {
    final cached = _animDecisions[m.id];
    if (cached != null) return cached;
    final isRekey = m.role == 'nova' && m.text.isNotEmpty && m.text == _lastNovaText;
    return _animDecisions[m.id] = !isRekey;
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final c = widget.controller;
      if (!c.hasClients) return;
      c.animateTo(
        c.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final chat = ref.watch(chatProvider);
    final streaming = chat.isStreaming && chat.streamingContent.isNotEmpty;
    final typing = chat.isStreaming && chat.streamingContent.isEmpty;

    final thread = <PanelMessage>[
      for (final m in chat.messages) _toPanel(m, chat.imageUploadProgress),
      if (streaming) PanelMessage(id: 'streaming', role: 'nova', text: chat.streamingContent, time: ''),
    ];
    final display = thread.isNotEmpty
        ? thread
        : [PanelMessage(id: 'greeting', role: 'nova', text: widget.greeting, time: '')];

    final signature = thread.length * 100000 + chat.streamingContent.length + (typing ? 1 : 0);
    if (signature != _lastSignature) {
      _lastSignature = signature;
      final c = widget.controller;
      final nearBottom = !c.hasClients || c.position.pixels >= c.position.maxScrollExtent - 120;
      // A message the user just sent always brings the thread to the bottom.
      final justSent = thread.length > _lastCount && thread.isNotEmpty && thread.last.isUser;
      if (nearBottom || justSent) _scrollToBottom();
    }
    _lastCount = thread.length;

    final rows = <Widget>[];
    for (final m in display) {
      // Never render an empty assistant bubble — skip the row entirely.
      final body = _buildMessageBody(context, m, m.isUser);
      if (body == null) continue;
      rows.add(
        Entrance(
          key: ValueKey(m.id),
          animate: _shouldAnimate(m),
          from: Offset(m.isUser ? 38 : -38, 0),
          duration: const Duration(milliseconds: 380),
          child: _MessageRow(
            message: m,
            userInitial: widget.userInitial,
            specialityIcon: specialityIcon(widget.specialitySlug),
            body: body,
          ),
        ),
      );
    }
    if (typing) {
      rows.add(
        Entrance.fromLeft(
          key: const ValueKey('typing'),
          child: _MessageRow.typing(
            userInitial: widget.userInitial,
            specialityIcon: specialityIcon(widget.specialitySlug),
          ),
        ),
      );
    }
    for (final m in thread.reversed) {
      if (m.role == 'nova') {
        _lastNovaText = m.text;
        break;
      }
    }

    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(padding: EdgeInsets.only(bottom: i == rows.length - 1 ? 0 : 10), child: rows[i]),
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

/// Circular avatar — Nova wears the answering speciality's icon (heartbeat, ear,
/// sun-horizon…) on the brand gradient; the user gets their initial.
class _Avatar extends StatelessWidget {
  final bool isUser;
  final String userInitial;
  final String specialityIcon;
  const _Avatar({required this.isUser, required this.userInitial, required this.specialityIcon});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      margin: const EdgeInsets.only(top: 2),
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isUser ? t.soft : null,
        gradient: isUser ? null : AppGradients.tealCyan,
        border: isUser ? Border.all(color: t.line) : null,
        boxShadow: isUser
            ? const []
            : [cssShadow(AppColors.teal.withValues(alpha: 0.6), y: 2, blur: 8, spread: -2)],
      ),
      child: isUser
          ? Text(
              userInitial,
              style: TextStyle(fontSize: 10.72, fontWeight: FontWeight.w700, color: t.ink),
            )
          : SpecialityIcon(icon: specialityIcon, size: 15, color: Colors.white, filled: true),
    );
  }
}

// ─── Message body ────────────────────────────────────────────────────────────

/// Builds the rendered body for one message, or `null` when there is genuinely
/// nothing to show — so the caller skips the whole row and never draws an avatar
/// next to an empty bubble. Mirrors `MessageList.tsx#buildBody`.
Widget? _buildMessageBody(BuildContext context, PanelMessage message, bool isUser) {
  if (message.imageFileId != null) {
    return _ImageBubble(message: message, isUser: isUser);
  }

  final blocks = message.blocks;
  if (blocks != null && blocks.isNotEmpty) {
    if (blocks.any(isRenderableBlock)) {
      // At least one block renders visibly — render them all (BlockRenderer hides
      // follow_up_questions itself, so trailing chips stay hidden).
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
    // No block renders visibly → show the content those blocks carry (e.g. the
    // interview question) instead of an empty bubble; nothing if truly empty.
    final fallback = deriveFallbackText(message.text, blocks);
    return fallback.isEmpty ? null : novaTextBubble(context, fallback);
  }

  // Plain text / image-analysis path.
  if (isUser) return _userBubble(message.text);
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
          padding: EdgeInsets.only(top: hasText ? 8 : 0),
          child: _AnalysisCard(analysis: analysis),
        ),
    ],
  );
}

Widget _userBubble(String text) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
    decoration: BoxDecoration(
      color: AppColors.teal,
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(4),
        bottomRight: Radius.circular(16),
        bottomLeft: Radius.circular(16),
      ),
      boxShadow: [cssShadow(AppColors.teal.withValues(alpha: 0.55), y: 6, blur: 16, spread: -8)],
    ),
    child: Text(text, style: const TextStyle(fontSize: 13.76, height: 1.5, color: Colors.white)),
  );
}

class _MessageRow extends StatelessWidget {
  final PanelMessage? message;
  final String userInitial;
  final String specialityIcon;
  final Widget? body;

  const _MessageRow({
    required PanelMessage this.message,
    required this.userInitial,
    required this.specialityIcon,
    required Widget this.body,
  });

  /// Nova's "thinking" row: avatar + ECG trace and staged status phrases.
  const _MessageRow.typing({required this.userInitial, required this.specialityIcon})
    : message = null,
      body = null;

  @override
  Widget build(BuildContext context) {
    final m = message;
    final isUser = m?.isUser ?? false;
    final avatar = _Avatar(isUser: isUser, userInitial: userInitial, specialityIcon: specialityIcon);
    final content = m == null
        ? const NovaBubble(child: NovaThinking())
        : Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              body!,
              if (m.time.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 3),
                  child: Text(m.time, style: TextStyle(fontSize: 9.92, color: context.tokens.ink3)),
                ),
            ],
          );

    // `max-w-[82%]` resolves against the row, not the space left after the avatar.
    return LayoutBuilder(
      builder: (context, c) {
        final bubble = Flexible(
          child: ConstrainedBox(constraints: BoxConstraints(maxWidth: c.maxWidth * 0.82), child: content),
        );
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
          children: isUser
              ? [bubble, const SizedBox(width: 8), avatar]
              : [avatar, const SizedBox(width: 8), bubble],
        );
      },
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
