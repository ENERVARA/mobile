import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/constants/specialities.dart';
import 'chat_provider.dart';

/// Nova panel orchestration — mirrors `novaUiStore.ts`. Owns open/closed + which
/// speciality the panel is focused on, and the prepare/send flow that drives
/// `chatProvider` underneath. On mobile the web renders the panel as a
/// full-height overlay under the app header; [AppShell] reads [NovaUiState.open]
/// to slide it in.
final novaUiProvider =
    StateNotifierProvider<NovaUiController, NovaUiState>((ref) => NovaUiController(ref));

class NovaUiState {
  /// The Nova panel is showing.
  final bool open;

  /// Speciality the panel is focused on, or null for a generic conversation.
  final String? specialitySlug;

  /// Conversation setup (load + open/reset) in flight.
  final bool preparing;

  /// A send (create + stream kickoff) in flight — re-entrancy guard.
  final bool sending;

  /// Text waiting to be placed in the composer, set by a hand-off from another
  /// surface (a prescription / lab-report summary). Deliberately NOT auto-sent —
  /// the user reads and can edit it before anything reaches the assistant.
  final String? pendingDraft;

  const NovaUiState({
    this.open = false,
    this.specialitySlug,
    this.preparing = false,
    this.sending = false,
    this.pendingDraft,
  });

  NovaUiState copyWith({
    bool? open,
    String? specialitySlug,
    bool clearSlug = false,
    bool? preparing,
    bool? sending,
    String? pendingDraft,
    bool clearDraft = false,
  }) {
    return NovaUiState(
      open: open ?? this.open,
      specialitySlug: clearSlug ? null : (specialitySlug ?? this.specialitySlug),
      preparing: preparing ?? this.preparing,
      sending: sending ?? this.sending,
      pendingDraft: clearDraft ? null : (pendingDraft ?? this.pendingDraft),
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

  /// Always starts a fresh conversation — never resumes history. Still loads the
  /// speciality's conversation list, but the active conversation stays cleared;
  /// `send()`'s lazy-create picks up from there. The one intentional exception
  /// is [openExistingConversation], used only by "Resume previous care" and the
  /// Health Timeline / My Care rows.
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

  /// Set the speciality context WITHOUT opening the panel (speciality detail).
  void focusSpeciality(String slug) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    if (next == state.specialitySlug) return;
    state = state.copyWith(specialitySlug: next, clearSlug: next == null);
    // If the panel is already open, re-load the conversation for the newly
    // focused speciality — otherwise a send() would post into the previously
    // active (wrong-speciality) thread.
    if (state.open) _prepare(_resolveSlug());
  }

  /// Generic entry point (header Nova button, drawer orb) — always starts in
  /// general medicine, regardless of whatever speciality was last focused by
  /// browsing a speciality detail page.
  Future<void> openChat() {
    state = state.copyWith(open: true, clearSlug: true);
    return _prepare(_resolveSlug());
  }

  /// Open Nova (fullscreen on mobile), optionally focused on a speciality.
  Future<void> openFullscreen([String? slug]) {
    if (slug != null) {
      final next = isSpecialityEnabled(slug) ? slug : null;
      state = state.copyWith(specialitySlug: next, clearSlug: next == null);
    }
    state = state.copyWith(open: true);
    return _prepare(_resolveSlug());
  }

  void closeChat() => state = state.copyWith(open: false);

  /// Focus Nova on a speciality AND open the panel ("Ask Nova").
  Future<void> personalize(String slug) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    state = state.copyWith(specialitySlug: next, clearSlug: next == null, open: true);
    return _prepare(_resolveSlug());
  }

  /// Open Nova on a speciality with [text] pre-filled in the composer.
  Future<void> openWithDraft(String slug, String text) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    state = state.copyWith(
      specialitySlug: next,
      clearSlug: next == null,
      open: true,
      pendingDraft: text,
    );
    return _prepare(_resolveSlug());
  }

  /// Composer reads the draft exactly once, then clears it.
  String? consumeDraft() {
    final draft = state.pendingDraft;
    if (draft != null) state = state.copyWith(clearDraft: true);
    return draft;
  }

  /// Re-open one specific past conversation — the only path that intentionally
  /// resumes history. Every other entry point starts fresh via [_prepare].
  Future<void> openExistingConversation(String conversationId, String slug) {
    final next = isSpecialityEnabled(slug) ? slug : null;
    state = state.copyWith(
      specialitySlug: next,
      clearSlug: next == null,
      open: true,
      preparing: true,
    );
    _chat.clearActive();
    final future = _chat.openConversation(conversationId);
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
