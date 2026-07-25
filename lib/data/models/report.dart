/// An uploaded medical report (metadata only — the blob streams from GridFS).
/// Ported from `src/services/reportsService.ts`.
class Report {
  final String id;
  final String fileName;
  final String mimeType;
  final int sizeBytes;
  final String category; // Lab results | Imaging | Prescriptions | Visits
  final String createdAt;

  const Report({
    required this.id,
    required this.fileName,
    required this.mimeType,
    required this.sizeBytes,
    required this.category,
    required this.createdAt,
  });

  factory Report.fromJson(Map<String, dynamic> json) {
    return Report(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      fileName: (json['fileName'] ?? 'Untitled') as String,
      mimeType: (json['mimeType'] ?? '') as String,
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      category: (json['category'] ?? 'Visits') as String,
      createdAt: (json['createdAt'] ?? '') as String,
    );
  }

  bool get isPdf => mimeType == 'application/pdf';
  bool get isImage => mimeType.startsWith('image/');
}

const reportCategories = <String>['Lab results', 'Imaging', 'Prescriptions', 'Visits'];
