import '../../core/api/api_client.dart';
import '../../core/config/app_config.dart';
import '../models/soap.dart';

class SoapShareLink {
  final String token;

  /// Absolute URL a doctor can open — points at the deployed web app's
  /// public `SoapSharePage`, not this app (a doctor opens it in a browser).
  final String url;
  final String expiresAt;
  const SoapShareLink({
    required this.token,
    required this.url,
    required this.expiresAt,
  });
}

/// SOAP-note endpoints (`/api/chat/conversations/:id/soap*`,
/// `/api/chat/soap/share/:token`). Mirrors `chatSoapService.ts` +
/// `soapShareService.ts`.
class SoapService {
  const SoapService();

  /// Triggers backend SOAP-note generation for a conversation. Generation
  /// logic is entirely server-side — this only kicks it off and normalizes
  /// the reply. Always a fresh call (no caching) so the latest conversation
  /// context is used.
  Future<SoapNote> generate(String conversationId) async {
    final res = await dio.post(
      '/chat/conversations/$conversationId/soap',
      data: {},
    );
    return SoapNote.normalize(res.data);
  }

  /// Creates (or refreshes) a public shareable link for the conversation's
  /// SOAP note. The clinical note is snapshotted from what the user is
  /// viewing; the patient identity is snapshotted server-side from their record.
  Future<SoapShareLink> createShare(
    String conversationId,
    SoapNote note,
  ) async {
    final res = await dio.post(
      '/chat/conversations/$conversationId/soap/share',
      data: {'note': note.toJson()},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    final token = (data['token'] ?? '').toString();
    final expiresAt = (data['expiresAt'] ?? '').toString();
    return SoapShareLink(
      token: token,
      url: '${AppConfig.webAppUrl}/share/soap/$token',
      expiresAt: expiresAt,
    );
  }

  Future<void> revokeShare(String token) async {
    await dio.delete('/chat/soap/share/$token');
  }
}
