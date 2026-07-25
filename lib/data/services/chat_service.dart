import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/chat.dart';

/// Chat endpoints (`/api/chat/*`). Streaming send lives in `sse_client.dart`.
class ChatService {
  const ChatService();

  Future<List<ChatConversation>> listConversations(String specialitySlug) async {
    final res = await dio.get('/chat/conversations',
        queryParameters: {'speciality': specialitySlug});
    return _asConversations(res.data);
  }

  Future<List<ChatConversation>> listRecent({int limit = 5}) async {
    final res = await dio.get('/chat/conversations', queryParameters: {'limit': limit});
    return _asConversations(res.data);
  }

  Future<ChatConversation> createConversation(String specialitySlug) async {
    final res = await dio.post('/chat/conversations', data: {'specialitySlug': specialitySlug});
    return ChatConversation.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<({ChatConversation conversation, List<ChatMessage> messages})> getConversation(
      String id) async {
    final res = await dio.get('/chat/conversations/$id');
    final data = Map<String, dynamic>.from(res.data as Map);
    final conversation =
        ChatConversation.fromJson(Map<String, dynamic>.from(data['conversation'] as Map));
    final messages = (data['messages'] is List)
        ? (data['messages'] as List)
            .whereType<Map>()
            .map((m) => ChatMessage.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <ChatMessage>[];
    return (conversation: conversation, messages: messages);
  }

  Future<ChatConversation> renameConversation(String id, String title) async {
    final res = await dio.patch('/chat/conversations/$id', data: {'title': title});
    return ChatConversation.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteConversation(String id) async {
    await dio.delete('/chat/conversations/$id');
  }

  /// Uploads a chat image (general-medicine only) and returns the persisted
  /// user + assistant message pair.
  Future<({ChatMessage userMessage, ChatMessage assistantMessage})> uploadImage(
    String conversationId,
    String filePath,
    String query, {
    void Function(int percent)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'image': await MultipartFile.fromFile(filePath),
      'query': query,
    });
    final res = await dio.post(
      '/chat/conversations/$conversationId/image',
      data: form,
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) onProgress((sent / total * 100).round());
      },
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return (
      userMessage: ChatMessage.fromJson(Map<String, dynamic>.from(data['userMessage'] as Map)),
      assistantMessage:
          ChatMessage.fromJson(Map<String, dynamic>.from(data['assistantMessage'] as Map)),
    );
  }

  static List<ChatConversation> _asConversations(dynamic data) {
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((c) => ChatConversation.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }
}
