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

  /// Routing + partial timings, delivered once before any content. Also the
  /// earliest signal that the backend is awake and working.
  final void Function(Map<String, dynamic> meta)? onMeta;

  /// Fires on the first parsed event of any kind — used to drop the
  /// "waking up" state once the backend actually responds.
  final void Function()? onFirstEvent;

  const ChatStreamHandlers({
    this.onChunk,
    this.onDone,
    this.onError,
    this.onBlock,
    this.onMeta,
    this.onFirstEvent,
  });
}

/// Event types that carry stream control rather than renderable content.
const _controlTypes = {'chunk', 'meta', 'done', 'error', 'block'};

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
  var sawEvent = false;

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

          if (!sawEvent) {
            sawEvent = true;
            handlers.onFirstEvent?.call();
          }

          final type = parsed['type']?.toString();
          switch (type) {
            case 'chunk':
              if (parsed['data'] is String) handlers.onChunk?.call(parsed['data'] as String);
              break;
            case 'meta':
              final meta = parsed['data'];
              handlers.onMeta?.call(
                meta is Map ? Map<String, dynamic>.from(meta) : const {},
              );
              break;
            case 'done':
              handlers.onDone?.call(parsed);
              break;
            case 'error':
              handlers.onError?.call(_errorMessage(parsed));
              break;
            case 'block':
              final block = parsed['block'];
              if (block is Map<String, dynamic>) handlers.onBlock?.call(block);
              break;
            default:
              // A bare typed block (`{"type":"summary","data":{…}}`) — what the
              // service emits directly. Anything with a Map `data` and a
              // non-control type is one.
              if (type != null && !_controlTypes.contains(type) && parsed['data'] is Map) {
                handlers.onBlock?.call(parsed);
              }
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

/// The terminal error frame comes as either a flat `{message}` or the
/// documented nested `{error: {code, message}}`.
String _errorMessage(Map<String, dynamic> parsed) {
  final err = parsed['error'];
  if (err is Map) {
    final message = err['message']?.toString();
    if (message != null && message.isNotEmpty) return message;
    final code = err['code']?.toString();
    if (code != null && code.isNotEmpty) return code;
  }
  return parsed['message']?.toString() ?? 'Chat error';
}
