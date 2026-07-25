import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/constants/specialities.dart';
import 'chat_provider.dart';

/// Nova panel orchestration — mirrors `novaUiStore.ts`. Owns the focused
/// speciality + the prepare/send flow that drives `chatProvider` underneath.
final novaUiProvider =
    StateNotifierProvider<NovaUiController, NovaUiState>((ref) => NovaUiController(ref));

class NovaUiState {
  final String? specialitySlug;
  final bool preparing;
  final bool sending;
  const NovaUiState({this.specialitySlug, this.preparing = false, this.sending = false});

  NovaUiState copyWith({
    String? specialitySlug,
    bool clearSlug = false,
    bool? preparing,
    bool? sending,
  }) {
    return NovaUiState(
      specialitySlug: clearSlug ? null : (specialitySlug ?? this.specialitySlug),
      preparing: preparing ?? this.preparing,
      sending: sending ?? this.sending,
    );
  }
}

class NovaUiController extends StateNotifier<NovaUiState> {
  NovaUiController(this._ref) : super(const NovaUiState());

  final Ref _ref;
  ChatController get _chat => _ref.read(chatProvider.notifier);
  Future<void>? _prep;

  /// The backend slug to talk to: the focused one if chat-enabled, else general.
  String _resolveSlug() {
    final s = state.specialitySlug;
    return isSpecialityEnabled(s) ? s! : kDefaultSpecialitySlug;
  }

  /// Load the speciality's conversation list but ALWAYS start a fresh thread —
  /// never auto-resume history (matches `novaUiStore.prepare`). Resuming is
  /// only ever explicit, via [openExistingConversation].
  Future<void> _prepare(String slug) {
    state = state.copyWith(preparing: true);
    _chat.clearActive();
    final future = () async {
      await _chat.loadConversations(slug);
      _chat.clearActive();
    }();
    _prep = future;
    future.whenComplete(() {
      if (_prep == future) _prep = null;
      if (mounted) state = state.copyWith(preparing: false);
    });
    return future;
  }

  /// Open Nova focused on a speciality (or general) and prepare its thread.
  Future<void> open({String? slug}) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    state = state.copyWith(specialitySlug: next, clearSlug: next == null);
    return _prepare(_resolveSlug());
  }

  /// Re-open one specific past conversation (Resume previous care).
  Future<void> openExistingConversation(String conversationId, String slug) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    state = state.copyWith(specialitySlug: next, clearSlug: next == null, preparing: true);
    final future = () async {
      await _chat.loadConversations(_resolveSlug());
      await _chat.openConversation(conversationId);
    }();
    _prep = future;
    future.whenComplete(() {
      if (_prep == future) _prep = null;
      if (mounted) state = state.copyWith(preparing: false);
    });
    return future;
  }

  void newChat() => _chat.clearActive();

  Future<void> send(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || state.sending) return;
    state = state.copyWith(sending: true);
    try {
      if (_prep != null) {
        try {
          await _prep;
        } catch (_) {}
      }
      final slug = _resolveSlug();
      if (_ref.read(chatProvider).activeConversationId == null) {
        await _chat.createConversation(slug);
      }
      await _chat.sendMessage(text);
    } finally {
      if (mounted) state = state.copyWith(sending: false);
    }
  }

  Future<void> sendImage(String filePath, String query, String mimeType) async {
    if (state.sending) return;
    state = state.copyWith(sending: true);
    try {
      if (_prep != null) {
        try {
          await _prep;
        } catch (_) {}
      }
      final slug = _resolveSlug();
      if (_ref.read(chatProvider).activeConversationId == null) {
        await _chat.createConversation(slug);
      }
      await _chat.sendImageMessage(filePath, query, mimeType);
    } finally {
      if (mounted) state = state.copyWith(sending: false);
    }
  }
}
