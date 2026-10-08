import 'package:dio/dio.dart';

import '../../core/api/api_client.dart';
import '../models/lab_report.dart' show DownloadTicket, UploadTicket;
import '../models/prescription.dart';
import 'upload_support.dart';

/// Typed HTTP client for `/api/v1/prescriptions`. Ported from
/// `services/prescriptions/api.ts`.
class PrescriptionsService {
  const PrescriptionsService();

  static const _base = '/v1/prescriptions';

  /// Extraction is a slow upstream call — well past the shared default.
  static const _processTimeout = Duration(seconds: 120);

  Future<UploadTicket> createUpload({
    required String fileName,
    required String mimeType,
    required int sizeBytes,
  }) async {
    final res = await dio.post(
      '$_base/upload-url',
      data: {'fileName': fileName, 'mimeType': mimeType, 'sizeBytes': sizeBytes},
    );
    return UploadTicket.fromJson(
      Map<String, dynamic>.from(res.data as Map),
      idKey: 'prescriptionId',
    );
  }

  Future<void> uploadFile(
    UploadTicket ticket,
    String filePath, {
    void Function(int percent)? onProgress,
    CancelToken? cancelToken,
  }) =>
      putTicketFile(ticket, filePath, onProgress: onProgress, cancelToken: cancelToken);

  Future<PrescriptionListItem> completeUpload(String prescriptionId) async {
    final res = await dio.post('$_base/$prescriptionId/upload-complete');
    // Returns a list-shaped row: extraction has not run yet.
    return PrescriptionListItem.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Prescription> processPrescription(String prescriptionId, {CancelToken? cancelToken}) async {
    final res = await dio.post(
      '$_base/$prescriptionId/process',
      cancelToken: cancelToken,
      options: Options(sendTimeout: _processTimeout, receiveTimeout: _processTimeout),
    );
    return Prescription.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<Prescription> savePrescription(String prescriptionId, Map<String, dynamic> payload) async {
    final res = await dio.post('$_base/$prescriptionId/save', data: payload);
    return Prescription.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<List<PrescriptionListItem>> listPrescriptions({
    String? search,
    String? status,
    String? sort,
  }) async {
    final res = await dio.get(
      _base,
      queryParameters: {
        if (search != null && search.isNotEmpty) 'search': search,
        if (status != null && status != 'ALL') 'status': status,
        if (sort != null) 'sort': sort,
      },
    );
    if (res.data is! List) return const [];
    return (res.data as List)
        .whereType<Map>()
        .map((r) => PrescriptionListItem.fromJson(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<Prescription> getPrescription(String prescriptionId) async {
    final res = await dio.get('$_base/$prescriptionId');
    return Prescription.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<DownloadTicket> getDownloadUrl(String prescriptionId) async {
    final res = await dio.get('$_base/$prescriptionId/download-url');
    return DownloadTicket.fromJson(Map<String, dynamic>.from(res.data as Map));
  }

  Future<void> deletePrescription(String prescriptionId) async {
    await dio.delete('$_base/$prescriptionId');
  }
}
