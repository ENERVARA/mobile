import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/api/sse_client.dart';
import '../data/models/chat.dart';
import '../data/models/soap.dart';
import '../data/services/chat_service.dart';
import '../data/services/soap_service.dart';

final chatServiceProvider = Provider((ref) => const ChatService());
final soapServiceProvider = Provider((ref) => const SoapService());

final chatProvider = StateNotifierProvider<ChatController, ChatState>(
  (ref) => ChatController(ref),
);

/// Doctor-summary / SOAP-note presentation state (one at a time, active conv).
enum SoapStatus { idle, loading, ready, error }

class SoapUiState {
  final SoapStatus status;
  final SoapNote? note;
  final String? error;
  const SoapUiState({this.status = SoapStatus.idle, this.note, this.error});
}

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
  // Sticky per-conversation flag: once the backend sets show_doctor_summary
  // on any turn, the "Show this to your doctor" CTA stays available for the
  // rest of that conversation. Keyed by conversation id.
  final Map<String, bool> doctorSummaryReady;
  // SOAP-note generation/presentation for the active conversation.
  final SoapUiState soap;

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
    this.doctorSummaryReady = const {},
    this.soap = const SoapUiState(),
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
    Map<String, bool>? doctorSummaryReady,
    SoapUiState? soap,
  }) {
    return ChatState(
      conversations: conversations ?? this.conversations,
      recentConversations: recentConversations ?? this.recentConversations,
      isLoadingRecent: isLoadingRecent ?? this.isLoadingRecent,
      activeConversationId: clearActive
          ? null
          : (activeConversationId ?? this.activeConversationId),
      messages: messages ?? this.messages,
      isLoadingList: isLoadingList ?? this.isLoadingList,
      isLoadingMessages: isLoadingMessages ?? this.isLoadingMessages,
      isStreaming: isStreaming ?? this.isStreaming,
      streamingContent: streamingContent ?? this.streamingContent,
      streamingBlocks: streamingBlocks ?? this.streamingBlocks,
      isSendingImage: isSendingImage ?? this.isSendingImage,
      imageUploadProgress: clearImageProgress
          ? null
          : (imageUploadProgress ?? this.imageUploadProgress),
      streamError: clearStreamError ? null : (streamError ?? this.streamError),
      doctorSummaryReady: doctorSummaryReady ?? this.doctorSummaryReady,
      soap: soap ?? this.soap,
    );
  }
}

class ChatController extends StateNotifier<ChatState> {
  ChatController(this._ref) : super(const ChatState());

  final Ref _ref;
  ChatService get _service => _ref.read(chatServiceProvider);
  SoapService get _soapService => _ref.read(soapServiceProvider);
  CancelToken? _cancelToken;

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
      soap: const SoapUiState(),
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
      soap: const SoapUiState(),
    );
    try {
      final res = await _service.getConversation(id);
      state = state.copyWith(
        messages: res.messages,
        conversations: state.conversations
            .map((c) => c.id == res.conversation.id ? res.conversation : c)
            .toList(),
        isLoadingMessages: false,
      );
    } catch (_) {
      state = state.copyWith(isLoadingMessages: false);
    }
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

    await streamChatMessage(
      conversationId: conversationId,
      content: trimmed,
      cancelToken: _cancelToken,
      handlers: ChatStreamHandlers(
        onChunk: (text) {
          state = state.copyWith(
            streamingContent: state.streamingContent + text,
          );
        },
        onBlock: (block) {
          state = state.copyWith(
            streamingBlocks: [
              ...state.streamingBlocks,
              MessageBlock.fromJson(block),
            ],
          );
        },
        onDone: (payload) {
          final fq = payload['followup_questions'];
          if (fq is List) followups = fq.map((e) => e.toString()).toList();
          // Sticky: once true for this conversation, the doctor-summary CTA stays.
          if (payload['show_doctor_summary'] == true) {
            state = state.copyWith(
              doctorSummaryReady: {
                ...state.doctorSummaryReady,
                conversationId: true,
              },
            );
          }
        },
        onError: (message) {
          state = state.copyWith(streamError: message);
        },
      ),
    );

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
      messages: assistant != null
          ? [...state.messages, assistant]
          : state.messages,
      streamingContent: '',
      streamingBlocks: const [],
      isStreaming: false,
      conversations: state.conversations
          .map(
            (c) => c.id == conversationId
                ? c.copyWith(lastMessageAt: DateTime.now().toIso8601String())
                : c,
          )
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
          messages: res.messages,
          conversations: state.conversations
              .map((c) => c.id == res.conversation.id ? res.conversation : c)
              .toList(),
        );
      }
    } catch (_) {}
  }

  Future<void> sendImageMessage(
    String filePath,
    String query,
    String mimeType,
  ) async {
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
        mimeType,
        onProgress: (p) => state = state.copyWith(imageUploadProgress: p),
      );
      if (state.activeConversationId == conversationId) {
        final deduped = state.messages
            .where(
              (m) =>
                  m.id != localId &&
                  m.id != result.userMessage.id &&
                  m.id != result.assistantMessage.id,
            )
            .toList();
        state = state.copyWith(
          messages: [...deduped, result.userMessage, result.assistantMessage],
          conversations: state.conversations
              .map(
                (c) => c.id == conversationId
                    ? c.copyWith(
                        lastMessageAt: DateTime.now().toIso8601String(),
                      )
                    : c,
              )
              .toList(),
        );
      }
    } catch (e) {
      if (state.activeConversationId == conversationId) {
        state = state.copyWith(
          messages: state.messages.where((m) => m.id != localId).toList(),
          streamError: 'Failed to send image',
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
        conversations: state.conversations
            .map((c) => c.id == id ? updated : c)
            .toList(),
      );
    } catch (_) {}
  }

  Future<void> deleteConversation(String id) async {
    try {
      await _service.deleteConversation(id);
      state = state.copyWith(
        conversations: state.conversations.where((c) => c.id != id).toList(),
        recentConversations: state.recentConversations
            .where((c) => c.id != id)
            .toList(),
        clearActive: state.activeConversationId == id,
        messages: state.activeConversationId == id ? const [] : state.messages,
      );
    } catch (_) {}
  }

  void stopStream() {
    _stopped = true;
    _cancelToken?.cancel();
    state = state.copyWith(isStreaming: false);
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
      soap: const SoapUiState(),
    );
  }

  /// Generate (always fresh) + present a SOAP note for the active conversation.
  Future<void> generateSoap() async {
    final conversationId = state.activeConversationId;
    if (conversationId == null) return;
    // Always a fresh request so the note reflects the latest conversation
    // context — re-tapping after more chat regenerates rather than caches.
    state = state.copyWith(soap: const SoapUiState(status: SoapStatus.loading));
    try {
      final note = await _soapService.generate(conversationId);
      // Guard against a conversation switch while the request was in flight.
      if (state.activeConversationId != conversationId) return;
      state = state.copyWith(
        soap: SoapUiState(status: SoapStatus.ready, note: note),
      );
    } catch (e) {
      if (state.activeConversationId != conversationId) return;
      state = state.copyWith(
        soap: SoapUiState(status: SoapStatus.error, error: _errorMessage(e)),
      );
    }
  }

  /// Close the SOAP note overlay and return to the chat.
  void closeSoap() => state = state.copyWith(soap: const SoapUiState());

  static String _errorMessage(Object e) {
    if (e is DioException) {
      final data = e.response?.data;
      if (data is Map && data['message'] is String) {
        return data['message'] as String;
      }
    }
    return 'Could not prepare the summary. Please try again.';
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
