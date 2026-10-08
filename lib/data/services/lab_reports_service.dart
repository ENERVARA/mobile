import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/lab_report.dart';
import 'upload_support.dart';

/// Typed HTTP client for `/api/v1/lab-reports`. Ported from
/// `services/labReports/api.ts` — the ONLY place that knows the endpoint
/// shapes. Everything else talks to the providers built on top of it.
class LabReportsService {
  const LabReportsService();

  static const _base = '/v1/lab-reports';

  /// Uploads and processing both outlive the client's default timeouts.
  static const _uploadTimeout = Duration(seconds: 120);
  static const _processTimeout = Duration(seconds: 60);

  Future<UploadTicket> createUpload({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final res = await dio.post(
      '$_base/upload-url',
      data: {'fileName': fileName, 'mimeType': mimeType, 'sizeBytes': sizeBytes},
    );
    return UploadTicket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> putFile(
    UploadTicket ticket,
    String filePath, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) =>
      putTicketFile(ticket, filePath, onProgress: onProgress, cancelToken: cancelToken);

  /// Takes NO request body — the server identifies the report from the URL.
  Future<LabReport> completeUpload(String reportId) async {
    final res = await dio.post(
      '$_base/$reportId/upload-complete',
      options: Options(sendTimeout: _uploadTimeout, receiveTimeout: _uploadTimeout),
    );
    return LabReport.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<LabReport> processReport(String reportId, {CancelToken? cancelToken}) async {
    final res = await dio.post(
      '$_base/$reportId/process',
      cancelToken: cancelToken,
      options: Options(sendTimeout: _processTimeout, receiveTimeout: _processTimeout),
    );
    return LabReport.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<LabReport> saveReport(String reportId, Map<String, dynamic> payload) async {
    final res = await dio.post('$_base/$reportId/save', data: payload);
    return LabReport.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<LabReportListItem>> listReports({
    String? search,
    String? reportType,
    String? status,
    String? sort,
  }) async {
    final params = <String, String>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (reportType != null && reportType != 'ALL') params['reportType'] = reportType;
    if (status != null && status != 'ALL') params['status'] = status;
    if (sort != null) params['sort'] = sort;
    final res = await dio.get(_base, queryParameters: params);
    if (res.data is! List) return const [];
    return (res.data as List)
        .whereType<Map>()
        .map((r) => LabReportListItem.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<LabReport> getReport(String reportId) async {
    final res = await dio.get('$_base/$reportId');
    return LabReport.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DownloadTicket> getDownloadUrl(String reportId) async {
    final res = await dio.get('$_base/$reportId/download-url');
    return DownloadTicket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deleteReport(String reportId) async {
    await dio.delete('$_base/$reportId');
  }
}
