// Canonical LabReport domain model. Ported from
// `src/services/labReports/{types,serialization}.ts` — the single source of
// truth for lab-report shape across the app.

// ── Enums / constants ───────────────────────────────────────────────────────

const kLabReportStatuses = ['PROCESSING', 'READY_FOR_REVIEW', 'SAVED', 'FAILED'];

/// Per-result flag. Deliberately NOT a clinical judgement — `HIGH`/`LOW` mean
/// "outside the reference range printed on the source document", `REVIEW`
/// means "we could not compare it confidently".
const kLabResultStatuses = ['NORMAL', 'HIGH', 'LOW', 'REVIEW'];

const kLabReportTypes = [
  'CBC',
  'LFT',
  'LIPID',
  'KFT',
  'THYROID',
  'HBA1C',
  'URINALYSIS',
  'OTHER',
];

const kLabReportTypeLabels = <String, String>{
  'CBC': 'Complete Blood Count',
  'LFT': 'Liver Function Test',
  'LIPID': 'Lipid Profile',
  'KFT': 'Kidney Function Test',
  'THYROID': 'Thyroid Profile',
  'HBA1C': 'HbA1c (Glycated Haemoglobin)',
  'URINALYSIS': 'Urinalysis',
  'OTHER': 'Lab Report',
};

String labReportTypeLabel(String type) =>
    kLabReportTypeLabels[type] ?? kLabReportTypeLabels['OTHER']!;

const kLabReportSorts = ['DATE_DESC', 'DATE_ASC', 'UPLOADED_DESC', 'UPLOADED_ASC'];

const kLabReportSortLabels = <String, String>{
  'DATE_DESC': 'Report date — newest',
  'DATE_ASC': 'Report date — oldest',
  'UPLOADED_DESC': 'Upload date — newest',
  'UPLOADED_ASC': 'Upload date — oldest',
};

// ── Entities ────────────────────────────────────────────────────────────────

String? _optStr(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

double? _optNum(dynamic v) {
  if (v == null || v == '') return null;
  if (v is num) return v.isFinite ? v.toDouble() : null;
  final n = double.tryParse(v.toString());
  return (n != null && n.isFinite) ? n : null;
}

String _oneOf(dynamic v, List<String> allowed, String fallback) {
  final s = v?.toString();
  return (s != null && allowed.contains(s)) ? s : fallback;
}

/// One measured marker. `value` is the numeric reading when the document gave
/// one; `valueText` carries qualitative readings ("Negative", "Trace").
class LabResult {
  final String id;
  final String panelId;
  final String reportId;
  final String testName;
  final double? value;
  final String? valueText;
  final String? unit;
  final double? referenceLow;
  final double? referenceHigh;

  /// Verbatim reference as printed, for ranges we cannot parse numerically.
  final String? referenceText;
  final String status; // NORMAL | HIGH | LOW | REVIEW
  final double? confidence;
  final String source; // EXTRACTED | MANUAL | DERIVED
  final int order;

  const LabResult({
    required this.id,
    required this.panelId,
    required this.reportId,
    required this.testName,
    required this.status,
    required this.source,
    required this.order,
    this.value,
    this.valueText,
    this.unit,
    this.referenceLow,
    this.referenceHigh,
    this.referenceText,
    this.confidence,
  });

  factory LabResult.fromJson(Map<String, dynamic> j) => LabResult(
        id: (j['id'] ?? '').toString(),
        panelId: (j['panelId'] ?? '').toString(),
        reportId: (j['reportId'] ?? '').toString(),
        testName: (j['testName'] ?? '').toString(),
        value: _optNum(j['value']),
        valueText: _optStr(j['valueText']),
        unit: _optStr(j['unit']),
        referenceLow: _optNum(j['referenceLow']),
        referenceHigh: _optNum(j['referenceHigh']),
        referenceText: _optStr(j['referenceText']),
        status: _oneOf(j['status'], kLabResultStatuses, 'REVIEW'),
        confidence: _optNum(j['confidence']),
        source: _oneOf(j['source'], const ['EXTRACTED', 'MANUAL', 'DERIVED'], 'EXTRACTED'),
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  LabResult copyWith({double? value, bool clearValue = false, String? unit}) => LabResult(
        id: id,
        panelId: panelId,
        reportId: reportId,
        testName: testName,
        value: clearValue ? null : (value ?? this.value),
        valueText: valueText,
        unit: unit ?? this.unit,
        referenceLow: referenceLow,
        referenceHigh: referenceHigh,
        referenceText: referenceText,
        status: status,
        confidence: confidence,
        source: source,
        order: order,
      );
}

class LabPanel {
  final String id;
  final String reportId;
  final String name;
  final int order;
  final List<LabResult> results;

  const LabPanel({
    required this.id,
    required this.reportId,
    required this.name,
    required this.order,
    required this.results,
  });

  factory LabPanel.fromJson(Map<String, dynamic> j) {
    final results = j['results'] is List
        ? (j['results'] as List)
            .whereType<Map>()
            .map((r) => LabResult.fromJson(Map<String, dynamic>.from(r)))
            .toList()
        : <LabResult>[];
    results.sort((a, b) => a.order.compareTo(b.order));
    return LabPanel(
      id: (j['id'] ?? '').toString(),
      reportId: (j['reportId'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      order: (j['order'] as num?)?.toInt() ?? 0,
      results: results,
    );
  }

  LabPanel copyWith({List<LabResult>? results}) => LabPanel(
        id: id,
        reportId: reportId,
        name: name,
        order: order,
        results: results ?? this.results,
      );
}

/// Counts derived from results — never stored by hand, always recomputed.
class LabReportSummary {
  final int markerCount;
  final int normalCount;
  final int highCount;
  final int lowCount;
  final int reviewCount;

  /// high + low + review — what the list card shows as "N need review".
  final int abnormalCount;

  const LabReportSummary({
    this.markerCount = 0,
    this.normalCount = 0,
    this.highCount = 0,
    this.lowCount = 0,
    this.reviewCount = 0,
    this.abnormalCount = 0,
  });

  factory LabReportSummary.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return LabReportSummary(
      markerCount: n('markerCount'),
      normalCount: n('normalCount'),
      highCount: n('highCount'),
      lowCount: n('lowCount'),
      reviewCount: n('reviewCount'),
      abnormalCount: n('abnormalCount'),
    );
  }
}

class LabReportMetadata {
  final String? labName;
  final String? referringDoctor;
  final String? collectedAt;
  final String? accessionNumber;
  final String? mimeType;
  final int? sizeBytes;
  final String? notes;

  const LabReportMetadata({
    this.labName,
    this.referringDoctor,
    this.collectedAt,
    this.accessionNumber,
    this.mimeType,
    this.sizeBytes,
    this.notes,
  });

  factory LabReportMetadata.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return LabReportMetadata(
      labName: _optStr(j['labName']),
      referringDoctor: _optStr(j['referringDoctor']),
      collectedAt: _optStr(j['collectedAt']),
      accessionNumber: _optStr(j['accessionNumber']),
      mimeType: _optStr(j['mimeType']),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
      notes: _optStr(j['notes']),
    );
  }
}

/// Row shape for the Lab Results list — no panels, so listing stays cheap.
class LabReportListItem {
  final String id;
  final String originalFileName;
  final String reportType;

  /// Date printed on the report. Null until processing extracts it.
  final String? reportDate;
  final String? uploadedAt;
  final String createdAt;
  final String updatedAt;
  final String status; // PROCESSING | READY_FOR_REVIEW | SAVED | FAILED
  final LabReportSummary summary;
  final String? failureReason;

  const LabReportListItem({
    required this.id,
    required this.originalFileName,
    required this.reportType,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.summary,
    this.reportDate,
    this.uploadedAt,
    this.failureReason,
  });

  factory LabReportListItem.fromJson(Map<String, dynamic> j) => LabReportListItem(
        id: (j['id'] ?? '').toString(),
        originalFileName: (j['originalFileName'] ?? '').toString(),
        reportType: _oneOf(j['reportType'], kLabReportTypes, 'OTHER'),
        reportDate: _optStr(j['reportDate']),
        uploadedAt: _optStr(j['uploadedAt']),
        createdAt: (j['createdAt'] ?? '').toString(),
        updatedAt: (j['updatedAt'] ?? j['createdAt'] ?? '').toString(),
        status: _oneOf(j['status'], kLabReportStatuses, 'PROCESSING'),
        summary: LabReportSummary.fromJson(j['summary']),
        failureReason: _optStr(j['failureReason']),
      );

  /// The date a report's values apply to: printed date first, upload last.
  String get effectiveDate => reportDate ?? uploadedAt ?? createdAt;
}

/// Full report, as returned by `getReport(id)`.
class LabReport extends LabReportListItem {
  final String userId;
  final String? fileId;
  final List<LabPanel> panels;
  final LabReportMetadata metadata;

  const LabReport({
    required super.id,
    required super.originalFileName,
    required super.reportType,
    required super.createdAt,
    required super.updatedAt,
    required super.status,
    required super.summary,
    super.reportDate,
    super.uploadedAt,
    super.failureReason,
    required this.userId,
    this.fileId,
    this.panels = const [],
    this.metadata = const LabReportMetadata(),
  });

  factory LabReport.fromJson(Map<String, dynamic> j) {
    final base = LabReportListItem.fromJson(j);
    final panels = j['panels'] is List
        ? (j['panels'] as List)
            .whereType<Map>()
            .map((p) => LabPanel.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <LabPanel>[];
    panels.sort((a, b) => a.order.compareTo(b.order));
    return LabReport(
      id: base.id,
      originalFileName: base.originalFileName,
      reportType: base.reportType,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      status: base.status,
      summary: base.summary,
      reportDate: base.reportDate,
      uploadedAt: base.uploadedAt,
      failureReason: base.failureReason,
      userId: (j['userId'] ?? '').toString(),
      fileId: _optStr(j['fileId']),
      panels: panels,
      metadata: LabReportMetadata.fromJson(j['metadata']),
    );
  }

  @override
  String get effectiveDate => reportDate ?? metadata.collectedAt ?? uploadedAt ?? createdAt;

  List<LabResult> get allResults => [for (final p in panels) ...p.results];

  LabReport copyWith({
    List<LabPanel>? panels,
    String? reportType,
    String? reportDate,
    bool clearReportDate = false,
  }) =>
      LabReport(
        id: id,
        originalFileName: originalFileName,
        reportType: reportType ?? this.reportType,
        createdAt: createdAt,
        updatedAt: updatedAt,
        status: status,
        summary: summary,
        reportDate: clearReportDate ? null : (reportDate ?? this.reportDate),
        uploadedAt: uploadedAt,
        failureReason: failureReason,
        userId: userId,
        fileId: fileId,
        panels: panels ?? this.panels,
        metadata: metadata,
      );

  /// Payload for saving a reviewed report. Only the fields a reviewer may
  /// correct are sent; `status` and every derived count are recomputed
  /// server-side, so the client can't assert a marker is normal.
  Map<String, dynamic> toSavePayload() => {
        'reportType': reportType,
        'reportDate': reportDate,
        'results': [
          for (final r in allResults)
            {
              'id': r.id,
              'value': r.value,
              'valueText': r.valueText,
              'unit': r.unit,
              'referenceLow': r.referenceLow,
              'referenceHigh': r.referenceHigh,
            },
        ],
      };
}

/// Instruction returned by `createUpload()`. The app performs the same
/// `PUT uploadUrl` regardless of provider — for S3 a presigned URL, for local
/// storage a backend endpoint carrying its own one-time token.
class UploadTicket {
  final String reportId; // report id (lab) / prescription id (rx)
  final String? fileId;
  final String uploadUrl;
  final String method; // PUT | POST
  final Map<String, String> headers;
  final String expiresAt;

  const UploadTicket({
    required this.reportId,
    this.fileId,
    required this.uploadUrl,
    required this.method,
    required this.headers,
    required this.expiresAt,
  });

  factory UploadTicket.fromJson(Map<String, dynamic> j, {String idKey = 'reportId'}) {
    final headers = <String, String>{};
    if (j['headers'] is Map) {
      (j['headers'] as Map).forEach((k, v) => headers[k.toString()] = v.toString());
    }
    return UploadTicket(
      reportId: (j[idKey] ?? '').toString(),
      fileId: _optStr(j['fileId']),
      uploadUrl: (j['uploadUrl'] ?? '').toString(),
      method: (j['method'] == 'POST') ? 'POST' : 'PUT',
      headers: headers,
      expiresAt: (j['expiresAt'] ?? '').toString(),
    );
  }
}

class DownloadTicket {
  final String url;
  final String expiresAt;
  final String fileName;
  final String mimeType;
  const DownloadTicket({
    required this.url,
    required this.expiresAt,
    required this.fileName,
    required this.mimeType,
  });

  factory DownloadTicket.fromJson(Map<String, dynamic> j) => DownloadTicket(
        url: (j['url'] ?? '').toString(),
        expiresAt: (j['expiresAt'] ?? '').toString(),
        fileName: (j['fileName'] ?? '').toString(),
        mimeType: (j['mimeType'] ?? '').toString(),
      );
}

// ── Presentation (labStatus.ts) ─────────────────────────────────────────────
//
// WORDING RULE: these strings describe the DOCUMENT, never the patient. A
// marker outside its range is "Above range" / "Needs review", never
// "abnormal" or anything a reader could take as a diagnosis.

/// "10.8 g/dL", or the qualitative reading, or an em dash when absent.
String formatLabResultValue(LabResult r) {
  if (r.valueText != null && r.valueText!.isNotEmpty) return r.valueText!;
  if (r.value == null) return '—';
  final v = _numToString(r.value!);
  return (r.unit != null && r.unit!.isNotEmpty) ? '$v ${r.unit}' : v;
}

String _numToString(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// The reference as the document printed it. Falls back to composing one from
/// the numeric bounds when no verbatim text was captured.
String? formatLabReference(LabResult r) {
  if (r.referenceText != null && r.referenceText!.isNotEmpty) return r.referenceText;
  final low = r.referenceLow, high = r.referenceHigh;
  if (low != null && high != null) return '${_numToString(low)} – ${_numToString(high)}';
  if (high != null) return '< ${_numToString(high)}';
  if (low != null) return '> ${_numToString(low)}';
  return null;
}

/// "2 need review", "All in range" — the list card's one-line summary.
String labSummaryLine(int abnormalCount, int markerCount) {
  if (markerCount == 0) return 'No markers extracted';
  if (abnormalCount == 0) return 'All in range';
  return '$abnormalCount need${abnormalCount == 1 ? 's' : ''} review';
}
