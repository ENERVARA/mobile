import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_gradients.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../core/utils/css_shadow.dart';
import '../../../../data/constants/specialities.dart';
import '../../../../state/chat_provider.dart';
import '../../../../state/nova_ui_provider.dart';
import '../../../../state/voice_provider.dart';
import 'voice_record_bar.dart';

/// Nova input composer — text field + image attach + send/stop, plus an inline
/// stream-error banner. Ported from the input section of `ChatPanel.tsx`.
class NovaComposer extends ConsumerStatefulWidget {
  const NovaComposer({super.key});

  @override
  ConsumerState<NovaComposer> createState() => _NovaComposerState();
}

class _NovaComposerState extends ConsumerState<NovaComposer> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  String? _imagePath;
  String? _imageName;
  String _imageMime = 'image/jpeg';

  static const _maxBytes = 10 * 1024 * 1024;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (mounted) setState(() => _focused = _focusNode.hasFocus);
    });
    // A hand-off from another surface (prescription / lab-report analysis)
    // pre-fills the composer instead of sending for the user.
    WidgetsBinding.instance.addPostFrameCallback((_) => _takeDraft());
  }

  /// Read exactly once, so re-opening the panel later never resurrects an old draft.
  void _takeDraft() {
    if (!mounted) return;
    final draft = ref.read(novaUiProvider.notifier).consumeDraft();
    if (draft != null && draft.isNotEmpty) {
      _controller.text = draft;
      _controller.selection = TextSelection.collapsed(offset: draft.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Voice → text: transcription lands in the input for review, not auto-sent.
  void _appendTranscript(String transcript) {
    final prev = _controller.text.trim();
    _controller.text = prev.isNotEmpty ? '$prev $transcript' : transcript;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _focusNode.requestFocus();
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _pick() async {
    final XFile? file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (file == null) return;
    final ext = file.path.split('.').last.toLowerCase();
    const allowed = {'jpg', 'jpeg', 'png', 'webp', 'heic'};
    if (!allowed.contains(ext)) {
      AppMessenger.error(
        'Unsupported file type. Accepted: JPEG, PNG, WEBP, HEIC',
      );
      return;
    }
    final size = await file.length();
    if (size > _maxBytes) {
      AppMessenger.error('File exceeds the 10 MB limit');
      return;
    }
    if (!mounted) return;
    setState(() {
      _imagePath = file.path;
      _imageName = file.name;
      _imageMime = _mimeFor(ext);
    });
  }

  void _clearImage() => setState(() {
    _imagePath = null;
    _imageName = null;
  });

  void _submit() {
    final text = _controller.text.trim();
    final nova = ref.read(novaUiProvider.notifier);
    if (_imagePath != null) {
      nova.sendImage(_imagePath!, text, _imageMime);
      _controller.clear();
      _clearImage();
      return;
    }
    if (text.isEmpty) return;
    nova.send(text);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final chat = ref.watch(chatProvider);
    final sending = ref.watch(novaUiProvider.select((s) => s.sending));
    final hasImage = _imagePath != null;
    final voice = ref.watch(voiceProvider);

    // Image/blocks capability must reflect the ACTUAL target conversation,
    // not just the focused speciality. Mirrors ChatPanel.tsx's `blocksEnabled`.
    final novaState = ref.watch(novaUiProvider);
    final activeId = chat.activeConversationId;
    final activeMatches = chat.conversations.where((c) => c.id == activeId);
    final resolvedSlug = isSpecialityEnabled(novaState.specialitySlug)
        ? novaState.specialitySlug!
        : kDefaultSpecialitySlug;
    final blocksEnabled = activeId != null
        ? (activeMatches.isEmpty ? false : activeMatches.first.blocksEnabled)
        : resolvedSlug == kDefaultSpecialitySlug;

    ref.listen<String?>(novaUiProvider.select((s) => s.pendingDraft), (_, draft) {
      if (draft != null) _takeDraft();
    });

    ref.listen<VoiceState>(voiceProvider, (prev, next) {
      final transcript = next.transcript;
      if (transcript != null && transcript.isNotEmpty) {
        _appendTranscript(transcript);
        ref.read(voiceProvider.notifier).consumeTranscript();
      }
    });

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chat.streamError != null)
          Container(
            margin: const EdgeInsets.fromLTRB(14, 0, 14, 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.coral.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.coral.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              chat.streamError!,
              style: TextStyle(fontSize: 12.5, color: t.ink),
            ),
          ),
        Container(
          decoration: BoxDecoration(border: Border(top: BorderSide(color: t.line))),
          padding: EdgeInsets.fromLTRB(
            14,
            8,
            14,
            MediaQuery.viewPaddingOf(context).bottom > 16 ? MediaQuery.viewPaddingOf(context).bottom : 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (hasImage)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.fromLTRB(6, 6, 12, 6),
                  decoration: BoxDecoration(
                    color: t.soft,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: t.line),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_imagePath!),
                          width: 36,
                          height: 36,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _imageName ?? 'Image',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12.5, color: t.ink2),
                        ),
                      ),
                      GestureDetector(
                        onTap: _clearImage,
                        child: Icon(
                          PhosphorIconsRegular.x,
                          size: 16,
                          color: t.ink3,
                        ),
                      ),
                    ],
                  ),
                ),
              if (voice.isActive)
                const VoiceRecordBar()
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _focused ? t.card : t.soft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _focused ? AppColors.teal : t.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _iconButton(
                        icon: PhosphorIconsRegular.paperclip,
                        color: blocksEnabled ? t.ink2 : t.ink3,
                        onTap: blocksEnabled ? _pick : null,
                      ),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: TextField(
                            controller: _controller,
                            focusNode: _focusNode,
                            minLines: 1,
                            maxLines: 5,
                            keyboardType: TextInputType.multiline,
                            textInputAction: TextInputAction.newline,
                            style: TextStyle(
                              fontSize: 13.76,
                              height: 1.625,
                              color: t.ink,
                            ),
                            decoration: InputDecoration(
                              isCollapsed: true,
                              border: InputBorder.none,
                              hintText: hasImage
                                  ? 'Add a caption (optional)…'
                                  : 'Ask Nova anything…',
                              hintStyle: TextStyle(
                                fontSize: 13.76,
                                color: t.ink3,
                              ),
                            ),
                          ),
                        ),
                      ),
                      _iconButton(
                        icon: PhosphorIconsRegular.microphone,
                        color: chat.isStreaming ? t.ink3 : t.ink2,
                        onTap: chat.isStreaming
                            ? null
                            : () => ref.read(voiceProvider.notifier).start(),
                      ),
                      const SizedBox(width: 8),
                      if (chat.isStreaming)
                        _sendButton(
                          icon: PhosphorIconsFill.stop,
                          stop: true,
                          onTap: () =>
                              ref.read(chatProvider.notifier).stopStream(),
                        )
                      else
                        _sendButton(
                          icon: PhosphorIconsFill.paperPlaneRight,
                          onTap: sending ? null : _submit,
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 7),
              Text.rich(
                TextSpan(
                  text: 'Nova can make mistakes. Check important information.',
                  children: [
                    const TextSpan(text: ' · '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.baseline,
                      baseline: TextBaseline.alphabetic,
                      child: GestureDetector(
                        onTap: () => context.push('/about/privacy'),
                        child: Text(
                          'Privacy policy',
                          style: TextStyle(
                            fontSize: 9.76,
                            color: t.ink3,
                            decoration: TextDecoration.underline,
                            decorationColor: t.ink3,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 9.76, color: t.ink3),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _iconButton({
    required IconData icon,
    required Color color,
    required VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 28,
        height: 28,
        child: Icon(icon, size: 14.4, color: color),
      ),
    );
  }

  Widget _sendButton({required IconData icon, required VoidCallback? onTap, bool stop = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: 28,
          height: 28,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: stop ? AppColors.teal : null,
            gradient: stop ? null : AppGradients.tealCyan,
            borderRadius: BorderRadius.circular(8),
            boxShadow: stop
                ? const []
                : [cssShadow(AppColors.teal.withValues(alpha: 0.7), y: 3, blur: 10, spread: -3)],
          ),
          child: Icon(icon, size: 14.4, color: Colors.white),
        ),
      ),
    );
  }
}
