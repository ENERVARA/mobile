import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/report.dart';

/// Reports endpoints (`/api/reports/*`). Files stream to/from a Mongo GridFS
/// bucket; these carry metadata + the authenticated blob fetch.
class ReportsService {
  const ReportsService();

  Future<Report> upload(
    String filePath, {
    String? fileName,
    String? category,
    void Function(int percent)? onProgress,
  }) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
      if (category != null) 'category': category,
    });
    final res = await dio.post(
      '/reports',
      data: form,
      onSendProgress: (sent, total) {
        if (onProgress != null && total > 0) onProgress((sent / total * 100).round());
      },
    );
    return Report.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<Report>> list() async {
    final res = await dio.get('/reports');
    if (res.data is! List) return const [];
    return (res.data as List)
        .whereType<Map>()
        .map((r) => Report.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// The JWT-protected blob (a plain URL wouldn't carry the auth header).
  Future<Uint8List> fetchBlob(String id) async {
    final res = await dio.get<List<int>>(
      '/reports/$id/file',
      options: Options(responseType: ResponseType.bytes),
    );
    return Uint8List.fromList(res.data ?? const []);
  }

  Future<void> delete(String id) async {
    await dio.delete('/reports/$id');
  }
}
