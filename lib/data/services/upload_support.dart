import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/lab_report.dart';

/// Shared plumbing for the presigned-upload flows (lab reports, prescriptions).

/// Where the upload flow failed and whether trying again could plausibly help.
class UploadError {
  final String? code;
  final String message;

  /// False for validation failures, where retrying the same file is pointless.
  final bool retryable;
  const UploadError({this.code, required this.message, required this.retryable});

  /// Reads the backend's `{ code, message }` envelope off a failed request.
  factory UploadError.from(Object err, {String fallback = 'Something went wrong', Set<String>? terminal}) {
    String? code;
    String? message;
    if (err is DioException) {
      final data = err.response?.data;
      if (data is Map) {
        code = data['code']?.toString();
        message = data['message']?.toString();
      }
      message ??= (err.type == DioExceptionType.connectionError ||
              err.type == DioExceptionType.connectionTimeout ||
              err.type == DioExceptionType.receiveTimeout ||
              err.type == DioExceptionType.sendTimeout)
          ? 'Network error. Check your connection and try again.'
          : null;
    }
    message ??= (err is Exception ? err.toString().replaceFirst('Exception: ', '') : null);
    final isTerminal = code != null && (terminal?.contains(code) ?? false);
    return UploadError(
      code: code,
      message: (message == null || message.isEmpty) ? fallback : message,
      retryable: !isTerminal,
    );
  }
}

/// Sends the bytes to wherever the ticket points.
///
/// Deliberately uses a BARE [Dio], not the shared client: for an S3 presigned
/// PUT the signature covers the headers, so the shared client's `Authorization`
/// header would invalidate it — and there is no reason to hand our JWT to a
/// third-party host. The local provider's endpoint carries its own one-time
/// token in the URL for the same reason.
Future<void> putTicketFile(
  UploadTicket ticket,
  String filePath, {
  void Function(int percent)? onProgress,
  CancelToken? cancelToken,
}) async {
  final Uint8List bytes = await File(filePath).readAsBytes();
  final bare = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 120),
      receiveTimeout: const Duration(seconds: 120),
      validateStatus: (s) => s != null && s >= 200 && s < 300,
    ),
  );
  // EXACTLY the headers the server signed — content-type is part of the
  // signature, so a value derived from the file instead of the ticket would be a
  // 403 the moment the two disagree.
  final headers = <String, dynamic>{...ticket.headers};
  await bare.request<dynamic>(
    ticket.uploadUrl,
    data: Stream<List<int>>.fromIterable([bytes]),
    cancelToken: cancelToken,
    options: Options(
      method: ticket.method,
      headers: {
        ...headers,
        Headers.contentLengthHeader: bytes.length,
      },
    ),
    onSendProgress: (sent, total) {
      if (onProgress == null) return;
      final t = total > 0 ? total : bytes.length;
      onProgress(t > 0 ? ((sent / t) * 100).round().clamp(0, 100) : 0);
    },
  );
}

/// The magic-number signature check from `fileValidation.ts` (`sniffSignature`).
String? sniffSignature(Uint8List b) {
  if (b.length < 4) return null;
  // "%PDF"
  if (b[0] == 0x25 && b[1] == 0x50 && b[2] == 0x44 && b[3] == 0x46) return 'application/pdf';
  // JPEG SOI + marker
  if (b[0] == 0xff && b[1] == 0xd8 && b[2] == 0xff) return 'image/jpeg';
  // PNG 8-byte signature
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4e &&
      b[3] == 0x47 &&
      b[4] == 0x0d &&
      b[5] == 0x0a &&
      b[6] == 0x1a &&
      b[7] == 0x0a) {
    return 'image/png';
  }
  // "RIFF" .... "WEBP"
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return 'image/webp';
  }
  return null;
}

// ── Lab/prescription file validation (fileValidation.ts) ────────────────────
//
// The accepted set is deliberately NARROWER than the generic uploader's: a lab
// report is a document or a photo of one, never a DICOM image series.

const kLabFileMaxBytes = 15 * 1024 * 1024;
const kLabFileMinBytes = 512;
const kLabAcceptedExtensions = ['.pdf', '.jpg', '.jpeg', '.png', '.webp'];

const _extToMime = <String, List<String>>{
  '.pdf': ['application/pdf'],
  '.jpg': ['image/jpeg'],
  '.jpeg': ['image/jpeg'],
  '.png': ['image/png'],
  '.webp': ['image/webp'],
};

String _formatMaxSize() => '${(kLabFileMaxBytes / (1024 * 1024)).round()} MB';

String _extensionOf(String fileName) {
  final dot = fileName.lastIndexOf('.');
  if (dot <= 0 || dot == fileName.length - 1) return '';
  return fileName.substring(dot).toLowerCase();
}

class FileCheck {
  final String? mimeType;
  final String? code;
  final String? message;
  const FileCheck.ok(this.mimeType) : code = null, message = null;
  const FileCheck.reject(this.code, this.message) : mimeType = null;
  bool get ok => message == null;
}

/// Full validation: metadata rules (size / extension), then the on-disk
/// signature. The server re-runs the equivalent checks on its own — this layer
/// exists to fail fast and explain clearly, not to be trusted.
Future<FileCheck> validateLabFile(
  String filePath, {
  required String fileName,
  List<({String name, int? size})> existing = const [],
}) async {
  final file = File(filePath);
  final size = await file.length();
  if (size == 0) {
    return const FileCheck.reject('EMPTY_FILE', 'That file is empty. Choose the original lab report file.');
  }
  if (size < kLabFileMinBytes) {
    return const FileCheck.reject(
      'FILE_TOO_SMALL',
      'That file is too small to be a readable lab report. Upload the original document.',
    );
  }
  if (size > kLabFileMaxBytes) {
    return FileCheck.reject('FILE_TOO_LARGE', 'That file is over the ${_formatMaxSize()} limit.');
  }
  final ext = _extensionOf(fileName);
  if (ext.isEmpty || !_extToMime.containsKey(ext)) {
    return FileCheck.reject(
      'UNSUPPORTED_EXTENSION',
      'Unsupported file type. Accepted: ${kLabAcceptedExtensions.join(', ')}.',
    );
  }
  final duplicate = existing.any(
    (e) => e.name.toLowerCase() == fileName.toLowerCase() && e.size == size,
  );
  if (duplicate) {
    return const FileCheck.reject('DUPLICATE_UPLOAD', 'You have already uploaded this file.');
  }

  // Content check — confirms the leading bytes match the declared type.
  final raf = await file.open();
  final head = await raf.read(12);
  await raf.close();
  final actual = sniffSignature(Uint8List.fromList(head));
  if (actual == null) {
    return const FileCheck.reject(
      'CORRUPT_OR_MALFORMED',
      'This file appears to be corrupt or incomplete. Try re-downloading it from your lab.',
    );
  }
  if (!_extToMime[ext]!.contains(actual)) {
    return const FileCheck.reject(
      'MIME_EXTENSION_MISMATCH',
      'This file’s contents do not match its extension. Re-export it and try again.',
    );
  }
  return FileCheck.ok(actual);
}
