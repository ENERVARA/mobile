import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/api_client.dart';
import '../core/api/sse_client.dart';
import '../data/models/chat.dart';
import '../data/services/chat_service.dart';

final chatServiceProvider = Provider((ref) => const ChatService());

final chatProvider =
    StateNotifierProvider<ChatController, ChatState>((ref) => ChatController(ref));

class ChatState {
  final List<ChatConversation> conversations;
  final List<ChatConversation> recentConversations;
  final bool isLoadingRecent;
  final String? activeConversationId;
  final List<ChatMessage> messages;
  final bool isLoadingList;
  final bool isLoadingMessages;
  final bool isStreaming;
  final String streamingContent;
  final List<MessageBlock> streamingBlocks;
  final bool isSendingImage;
  final int? imageUploadProgress;
  final String? streamError;

  /// Sticky for the conversation — flipped true by an `answer_state` block and
  /// never back down until the thread changes. Reveals the SOAP-note action.
  final bool showDoctorSummary;

  /// Nothing has come back yet and we're past the grace period — the backend
  /// is probably cold-starting.
  final bool isWakingUp;

  const ChatState({
    this.conversations = const [],
    this.recentConversations = const [],
    this.isLoadingRecent = false,
    this.activeConversationId,
    this.messages = const [],
    this.isLoadingList = false,
    this.isLoadingMessages = false,
    this.isStreaming = false,
    this.streamingContent = '',
    this.streamingBlocks = const [],
    this.isSendingImage = false,
    this.imageUploadProgress,
    this.streamError,
    this.showDoctorSummary = false,
    this.isWakingUp = false,
  });

  ChatState copyWith({
    List<ChatConversation>? conversations,
    List<ChatConversation>? recentConversations,
    bool? isLoadingRecent,
    String? activeConversationId,
    bool clearActive = false,
    List<ChatMessage>? messages,
    bool? isLoadingList,
    bool? isLoadingMessages,
    bool? isStreaming,
    String? streamingContent,
    List<MessageBlock>? streamingBlocks,
    bool? isSendingImage,
    int? imageUploadProgress,
    bool clearImageProgress = false,
    String? streamError,
    bool clearStreamError = false,
    bool? showDoctorSummary,
    bool? isWakingUp,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      recentConversations: recentConversations ?? this.recentConversations,
      isLoadingRecent: isLoadingRecent ?? this.isLoadingRecent,
      activeConversationId:
          clearActive ? null : (activeConversationId ?? this.activeConversationId),
      messages: messages ?? this.messages,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingBlocks: streamingBlocks ?? this.streamingBlocks,
      isSendingImage: isSendingImage ?? this.isSendingImage,
      imageUploadProgress:
          clearImageProgress ? null : (imageUploadProgress ?? this.imageUploadProgress),
      streamError: clearStreamError ? null : (streamError ?? this.streamError),
      showDoctorSummary: showDoctorSummary ?? this.showDoctorSummary,
      isWakingUp: isWakingUp ?? this.isWakingUp,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;
  ChatService get _service => _ref.read(chatServiceProvider);
  CancelToken? _cancelToken;

  /// On-device paths for images uploaded during this session, keyed by the
  /// persisted message id. The server round-trip only returns a file id, so
  /// without this every refetch would blank the user's photo back to a
  /// placeholder. Images from *earlier* sessions have no entry here — they
  /// need a backend blob route to display (see `_ImageBubble`).
  final Map<String, String> _localPreviews = {};

  /// Re-attaches any known local preview to server-sourced messages.
  List<ChatMessage> _withPreviews(List<ChatMessage> messages) {
    if (_localPreviews.isEmpty) return messages;
    return messages
        .map((m) => _localPreviews.containsKey(m.id)
            ? m.copyWith(localPreviewUrl: _localPreviews[m.id])
            : m)
        .toList();
  }

  /// Set when the user hits Stop, so we keep the partial reply on screen
  /// instead of refetching a server thread that never persisted it.
  bool _stopped = false;

  Future<void> loadConversations(String specialitySlug) async {
    state = state.copyWith(isLoadingList: true);
    try {
      final list = await _service.listConversations(specialitySlug);
      state = state.copyWith(conversations: list, isLoadingList: false);
    } catch (_) {
      state = state.copyWith(isLoadingList: false);
    }
  }

  Future<void> loadRecentConversations({int limit = 5}) async {
    state = state.copyWith(isLoadingRecent: true);
    try {
      final list = await _service.listRecent(limit: limit);
      state = state.copyWith(recentConversations: list, isLoadingRecent: false);
    } catch (_) {
      state = state.copyWith(isLoadingRecent: false);
    }
  }

  Future<ChatConversation> createConversation(String specialitySlug) async {
    final created = await _service.createConversation(specialitySlug);
    state = state.copyWith(
      conversations: [created, ...state.conversations],
      activeConversationId: created.id,
      messages: const [],
      streamingContent: '',
      streamingBlocks: const [],
      clearStreamError: true,
      showDoctorSummary: false,
    );
    return created;
  }

  Future<void> openConversation(String id) async {
    state = state.copyWith(
      isLoadingMessages: true,
      activeConversationId: id,
      messages: const [],
      streamingContent: '',
      streamingBlocks: const [],
      clearStreamError: true,
      showDoctorSummary: false,
    );
    try {
      final res = await _service.getConversation(id);
      state = state.copyWith(
        messages: _withPreviews(res.messages),
        conversations: state.conversations
            .map((c) => c.id == res.conversation.id ? res.conversation : c)
            .toList(),
        isLoadingMessages: false,
        showDoctorSummary: _doctorSummaryIn(res.messages),
      );
    } catch (_) {
      state = state.copyWith(isLoadingMessages: false);
    }
  }

  /// The flag is sticky, so any `answer_state` in the thread's history that
  /// turned it on keeps it on when the conversation is re-opened.
  static bool _doctorSummaryIn(List<ChatMessage> messages) {
    return messages.any((m) =>
        m.blocks?.whereType<AnswerStateBlock>().any((b) => b.showDoctorSummary) ?? false);
  }

  Future<void> sendMessage(String content) async {
    final conversationId = state.activeConversationId;
    if (conversationId == null) return;
    final trimmed = content.trim();
    if (trimmed.isEmpty) return;

    final now = DateTime.now();
    final optimisticUser = ChatMessage(
      id: 'local-${now.millisecondsSinceEpoch}',
      conversationId: conversationId,
      role: 'user',
      content: trimmed,
      createdAt: now.toIso8601String(),
    );

    _cancelToken = CancelToken();
    _stopped = false;
    state = state.copyWith(
      messages: [...state.messages, optimisticUser],
      isStreaming: true,
      streamingContent: '',
      streamingBlocks: const [],
      clearStreamError: true,
    );

    var followups = <String>[];

    // A cold container takes 10–15 s to boot. Past 3 s of total silence, say
    // we're waking it rather than showing pipeline stages that aren't running.
    final wakeTimer = Timer(const Duration(seconds: 3), () {
      if (state.isStreaming) state = state.copyWith(isWakingUp: true);
    });
    void settled() {
      wakeTimer.cancel();
      if (state.isWakingUp) state = state.copyWith(isWakingUp: false);
    }

    await streamChatMessage(
      conversationId: conversationId,
      content: trimmed,
      cancelToken: _cancelToken,
      handlers: ChatStreamHandlers(
        onFirstEvent: settled,
        onChunk: (text) {
          state = state.copyWith(streamingContent: state.streamingContent + text);
        },
        onBlock: (block) {
          final parsed = MessageBlock.fromJson(block);
          // `answer_state` is control, not content — read the flag, don't render.
          if (parsed is AnswerStateBlock) {
            if (parsed.showDoctorSummary) {
              state = state.copyWith(showDoctorSummary: true);
            }
            return;
          }
          state = state.copyWith(streamingBlocks: [...state.streamingBlocks, parsed]);
        },
        onDone: (payload) {
          final fq = payload['followup_questions'];
          if (fq is List) followups = fq.map((e) => e.toString()).toList();
        },
        onError: (message) {
          settled();
          state = state.copyWith(streamError: message);
        },
      ),
    );
    settled();

    // Finalise the streamed content into a real assistant message.
    final buffered = state.streamingContent;
    final blocks = state.streamingBlocks;
    final summary = blocks.whereType<SummaryBlock>().firstOrNull;
    final fallback = summary?.text ?? '[Nova sent a structured response]';
    final assistant = (buffered.isNotEmpty || blocks.isNotEmpty)
        ? ChatMessage(
            id: 'local-${DateTime.now().millisecondsSinceEpoch + 1}',
            conversationId: conversationId,
            role: 'assistant',
            content: buffered.isNotEmpty ? buffered : fallback,
            followupQuestions: followups,
            blocks: blocks.isNotEmpty ? blocks : null,
            createdAt: DateTime.now().toIso8601String(),
          )
        : null;

    state = state.copyWith(
      messages: assistant != null ? [...state.messages, assistant] : state.messages,
      streamingContent: '',
      streamingBlocks: const [],
      isStreaming: false,
      conversations: state.conversations
          .map((c) => c.id == conversationId
              ? c.copyWith(lastMessageAt: DateTime.now().toIso8601String())
              : c)
          .toList(),
    );
    _cancelToken = null;

    // A user-aborted turn may not be persisted upstream — keep the partial
    // reply on screen rather than refetching it away.
    if (_stopped) {
      _stopped = false;
      return;
    }

    // Refetch so we capture canonical server IDs + auto-title.
    try {
      final res = await _service.getConversation(conversationId);
      if (state.activeConversationId == conversationId) {
        state = state.copyWith(
          messages: _withPreviews(res.messages),
          conversations: state.conversations
              .map((c) => c.id == res.conversation.id ? res.conversation : c)
              .toList(),
          showDoctorSummary: state.showDoctorSummary || _doctorSummaryIn(res.messages),
        );
      }
    } catch (_) {}
  }

  /// Regenerates the doctor-facing SOAP note for the active conversation.
  /// Returns null if there's no active thread or the request fails (the Dio
  /// interceptor has already surfaced the error toast).
  Future<SoapNote?> generateSoapNote() async {
    final conversationId = state.activeConversationId;
    if (conversationId == null) return null;
    try {
      return await _service.generateSoapNote(conversationId);
    } catch (_) {
      return null;
    }
  }

  Future<void> sendImageMessage(String filePath, String query, String mimeType) async {
    final conversationId = state.activeConversationId;
    if (conversationId == null) return;

    final trimmedQuery = query.trim().isEmpty ? 'Sent an image' : query.trim();
    final localId = 'local-${DateTime.now().millisecondsSinceEpoch}';
    final optimisticUser = ChatMessage(
      id: localId,
      conversationId: conversationId,
      role: 'user',
      content: trimmedQuery,
      imageFileId: 'pending',
      imageMimeType: mimeType,
      localPreviewUrl: filePath,
      createdAt: DateTime.now().toIso8601String(),
    );

    state = state.copyWith(
      messages: [...state.messages, optimisticUser],
      isSendingImage: true,
      imageUploadProgress: 0,
      clearStreamError: true,
    );

    try {
      final result = await _service.uploadImage(
        conversationId,
        filePath,
        trimmedQuery,
        mimeType: mimeType,
        onProgress: (p) => state = state.copyWith(imageUploadProgress: p),
      );
      // Remember the on-device path under the persisted id so later refetches
      // can still show the photo the user actually sent.
      _localPreviews[result.userMessage.id] = filePath;
      if (state.activeConversationId == conversationId) {
        final deduped = state.messages
            .where((m) =>
                m.id != localId &&
                m.id != result.userMessage.id &&
                m.id != result.assistantMessage.id)
            .toList();
        state = state.copyWith(
          messages: [
            ...deduped,
            result.userMessage.copyWith(localPreviewUrl: filePath),
            result.assistantMessage,
          ],
          conversations: state.conversations
              .map((c) => c.id == conversationId
                  ? c.copyWith(lastMessageAt: DateTime.now().toIso8601String())
                  : c)
              .toList(),
          showDoctorSummary: state.showDoctorSummary ||
              _doctorSummaryIn([result.assistantMessage]),
        );
      }
    } catch (e) {
      if (state.activeConversationId == conversationId) {
        // Surface what the service actually said — a rejected format, an
        // oversized file, or uploads being disabled all land here.
        final apiError = (e is DioException) ? e.error : null;
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != localId).toList(),
          streamError:
              apiError is ApiError ? apiError.message : "Couldn't send that image",
        );
      }
    } finally {
      state = state.copyWith(isSendingImage: false, clearImageProgress: true);
    }
  }

  Future<void> renameConversation(String id, String title) async {
    final next = title.trim();
    if (next.isEmpty) return;
    try {
      final updated = await _service.renameConversation(id, next);
      state = state.copyWith(
        conversations: state.conversations.map((c) => c.id == id ? updated : c).toList(),
      );
    } catch (_) {}
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _service.deleteConversation(id);
      state = state.copyWith(
        conversations: state.conversations.where((c) => c.id != id).toList(),
        recentConversations: state.recentConversations.where((c) => c.id != id).toList(),
        clearActive: state.activeConversationId == id,
        messages: state.activeConversationId == id ? const [] : state.messages,
      );
    } catch (_) {}
  }

  void stopStream() {
    _stopped = true;
    _cancelToken?.cancel();
    state = state.copyWith(isStreaming: false, isWakingUp: false);
    _cancelToken = null;
  }

  void clearActive() {
    _cancelToken?.cancel();
    _cancelToken = null;
    state = state.copyWith(
      clearActive: true,
      messages: const [],
      streamingContent: '',
      streamingBlocks: const [],
      isStreaming: false,
      clearStreamError: true,
      showDoctorSummary: false,
      isWakingUp: false,
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
