import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

import 'api_client.dart';

/// Typed callbacks for the chat SSE stream (mirrors `useChatStream.ts`).
class ChatStreamHandlers {
  final void Function(String text)? onChunk;
  final void Function(Map<String, dynamic> payload)? onDone;
  final void Function(String message)? onError;
  final void Function(Map<String, dynamic> block)? onBlock;

  const ChatStreamHandlers({this.onChunk, this.onDone, this.onError, this.onBlock});
}

/// POSTs a user message to the backend's SSE proxy and parses the streamed
/// `data: {...}` events into typed callbacks. Byte 1:1 port of the web parser.
Future<void> streamChatMessage({
  required String conversationId,
  required String content,
  CancelToken? cancelToken,
  ChatStreamHandlers handlers = const ChatStreamHandlers(),
}) async {
  Response<ResponseBody> res;
  try {
    res = await dio.post<ResponseBody>(
      '/chat/conversations/$conversationId/messages',
      data: {'content': content},
      options: Options(
        responseType: ResponseType.stream,
        headers: {'Accept': 'text/event-stream'},
      ),
      cancelToken: cancelToken,
    );
  } on DioException catch (e) {
    if (CancelToken.isCancel(e)) return;
    handlers.onError?.call('Network error');
    return;
  }

  final status = res.statusCode ?? 0;
  if (status < 200 || status >= 300 || res.data == null) {
    handlers.onError?.call('HTTP $status');
    return;
  }

  // utf8.decoder in chunked (bound) mode stitches multi-byte chars split
  // across network chunks — same guarantee TextDecoder({stream:true}) gives.
  final Stream<String> text = utf8.decoder.bind(res.data!.stream);
  var buf = '';

  try {
    await for (final piece in text) {
      buf += piece;
      final events = buf.split('\n\n');
      buf = events.removeLast(); // trailing partial event stays buffered

      for (final event in events) {
        if (event.trim().isEmpty) continue;
        final dataLine = event
            .split('\n')
            .firstWhere((l) => l.startsWith('data: '), orElse: () => '');
        if (dataLine.isEmpty) continue;

        final payload = dataLine.substring(6).trim();
        if (payload == '[DONE]') continue;

        try {
          final parsed = jsonDecode(payload);
          if (parsed is! Map<String, dynamic>) continue;
          switch (parsed['type']) {
            case 'chunk':
              if (parsed['data'] is String) handlers.onChunk?.call(parsed['data'] as String);
              break;
            case 'done':
              handlers.onDone?.call(parsed);
              break;
            case 'error':
              handlers.onError?.call((parsed['message'] as String?) ?? 'Chat error');
              break;
            case 'block':
              final block = parsed['block'];
              if (block is Map<String, dynamic>) handlers.onBlock?.call(block);
              break;
          }
        } catch (_) {
          /* non-JSON event, skip */
        }
      }
    }
  } catch (e) {
    if (e is DioException && CancelToken.isCancel(e)) return;
    handlers.onError?.call('Stream interrupted');
  }
}
