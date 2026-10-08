// Canonical prescription domain model. Ported from
// `src/services/prescriptions/{types,serialization,chatSummary}.ts`.
//
// Scope note: this feature TRANSCRIBES a prescription and carries neutral drug
// information. There is deliberately no field for interactions, severity or
// suitability — the product does not assess whether a prescription is right for
// the person holding it.

const kPrescriptionStatuses = ['PROCESSING', 'READY_FOR_REVIEW', 'SAVED', 'FAILED'];

/// Legibility of one line. A statement about the scan, never about the medicine.
const kMedicationReadStatuses = ['CLEAR', 'PARTIAL', 'NEEDS_REVIEW'];

const kMedicationFormLabels = <String, String>{
  'TABLET': 'Tablet',
  'CAPSULE': 'Capsule',
  'SYRUP': 'Syrup',
  'INJECTION': 'Injection',
  'DROPS': 'Drops',
  'CREAM': 'Cream',
  'INHALER': 'Inhaler',
  'OTHER': 'Other',
};

const kPrescriptionSorts = ['DATE_DESC', 'DATE_ASC', 'UPLOADED_DESC', 'UPLOADED_ASC'];

const kPrescriptionSortLabels = <String, String>{
  'DATE_DESC': 'Prescribed — newest',
  'DATE_ASC': 'Prescribed — oldest',
  'UPLOADED_DESC': 'Uploaded — newest',
  'UPLOADED_ASC': 'Uploaded — oldest',
};

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

class Medication {
  final String id;
  final String prescriptionId;

  /// Exactly as printed on the document.
  final String name;
  final String? genericName;
  final String? strength;
  final String form;
  final String route;
  final String? dosage;
  final String? frequency;
  final String? timing;
  final String? durationText;
  final int? durationDays;
  final String? instructions;

  /// Neutral drug-class information. Never a statement about this patient.
  final String? commonUse;
  final String readStatus; // CLEAR | PARTIAL | NEEDS_REVIEW
  final double? confidence;
  final String source;
  final int order;

  const Medication({
    required this.id,
    required this.prescriptionId,
    required this.name,
    required this.form,
    required this.route,
    required this.readStatus,
    required this.source,
    required this.order,
    this.genericName,
    this.strength,
    this.dosage,
    this.frequency,
    this.timing,
    this.durationText,
    this.durationDays,
    this.instructions,
    this.commonUse,
    this.confidence,
  });

  factory Medication.fromJson(Map<String, dynamic> j) => Medication(
        id: (j['id'] ?? '').toString(),
        prescriptionId: (j['prescriptionId'] ?? '').toString(),
        name: (j['name'] ?? '').toString(),
        genericName: _optStr(j['genericName']),
        strength: _optStr(j['strength']),
        form: _oneOf(j['form'], kMedicationFormLabels.keys.toList(), 'OTHER'),
        route: (j['route'] ?? 'ORAL').toString(),
        dosage: _optStr(j['dosage']),
        frequency: _optStr(j['frequency']),
        timing: _optStr(j['timing']),
        durationText: _optStr(j['durationText']),
        durationDays: (j['durationDays'] as num?)?.toInt(),
        instructions: _optStr(j['instructions']),
        commonUse: _optStr(j['commonUse']),
        // Defaulting to NEEDS_REVIEW is the safe direction: an unrecognised grade
        // asks the user to check the line rather than quietly presenting it as read.
        readStatus: _oneOf(j['readStatus'], kMedicationReadStatuses, 'NEEDS_REVIEW'),
        confidence: _optNum(j['confidence']),
        source: (j['source'] ?? 'EXTRACTED').toString(),
        order: (j['order'] as num?)?.toInt() ?? 0,
      );

  /// Review edits: each editable field takes the new value (null clears it).
  Medication edit({
    String? name,
    bool setDosage = false,
    String? dosage,
    bool setFrequency = false,
    String? frequency,
    bool setTiming = false,
    String? timing,
    bool setDuration = false,
    String? durationText,
  }) =>
      Medication(
        id: id,
        prescriptionId: prescriptionId,
        name: name ?? this.name,
        genericName: genericName,
        strength: strength,
        form: form,
        route: route,
        dosage: setDosage ? dosage : this.dosage,
        frequency: setFrequency ? frequency : this.frequency,
        timing: setTiming ? timing : this.timing,
        durationText: setDuration ? durationText : this.durationText,
        durationDays: durationDays,
        instructions: instructions,
        commonUse: commonUse,
        readStatus: readStatus,
        confidence: confidence,
        source: source,
        order: order,
      );

  /// "1 tablet · Twice daily · After food · 5 days", skipping whatever is absent.
  List<String> get scheduleParts =>
      [dosage, frequency, timing, durationText].whereType<String>().where((s) => s.isNotEmpty).toList();
}

class PrescriptionSummary {
  final int medicationCount;
  final int clearCount;
  final int partialCount;
  final int needsReviewCount;
  const PrescriptionSummary({
    this.medicationCount = 0,
    this.clearCount = 0,
    this.partialCount = 0,
    this.needsReviewCount = 0,
  });

  factory PrescriptionSummary.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    int n(String k) => (j[k] as num?)?.toInt() ?? 0;
    return PrescriptionSummary(
      medicationCount: n('medicationCount'),
      clearCount: n('clearCount'),
      partialCount: n('partialCount'),
      needsReviewCount: n('needsReviewCount'),
    );
  }
}

class PrescriptionMetadata {
  final String? prescriberName;
  final String? prescriberRegistration;
  final String? clinicName;
  final String? patientName;

  /// Indication as printed on the page. Not a diagnosis.
  final String? indicationNotes;
  final String? notes;
  final String? mimeType;
  final int? sizeBytes;

  const PrescriptionMetadata({
    this.prescriberName,
    this.prescriberRegistration,
    this.clinicName,
    this.patientName,
    this.indicationNotes,
    this.notes,
    this.mimeType,
    this.sizeBytes,
  });

  factory PrescriptionMetadata.fromJson(dynamic raw) {
    final j = raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};
    return PrescriptionMetadata(
      prescriberName: _optStr(j['prescriberName']),
      prescriberRegistration: _optStr(j['prescriberRegistration']),
      clinicName: _optStr(j['clinicName']),
      patientName: _optStr(j['patientName']),
      indicationNotes: _optStr(j['indicationNotes']),
      notes: _optStr(j['notes']),
      mimeType: _optStr(j['mimeType']),
      sizeBytes: (j['sizeBytes'] as num?)?.toInt(),
    );
  }
}

/// Row shape for the Prescriptions list — no medications, so listing stays cheap.
class PrescriptionListItem {
  final String id;
  final String originalFileName;
  final String? prescribedDate;
  final String? uploadedAt;
  final String createdAt;
  final String updatedAt;
  final String status;
  final PrescriptionSummary summary;
  final String? prescriberName;
  final String? clinicName;
  final String? failureReason;

  const PrescriptionListItem({
    required this.id,
    required this.originalFileName,
    required this.createdAt,
    required this.updatedAt,
    required this.status,
    required this.summary,
    this.prescribedDate,
    this.uploadedAt,
    this.prescriberName,
    this.clinicName,
    this.failureReason,
  });

  factory PrescriptionListItem.fromJson(Map<String, dynamic> j) => PrescriptionListItem(
        id: (j['id'] ?? '').toString(),
        originalFileName: (j['originalFileName'] ?? '').toString(),
        prescribedDate: _optStr(j['prescribedDate']),
        uploadedAt: _optStr(j['uploadedAt']),
        createdAt: (j['createdAt'] ?? '').toString(),
        updatedAt: (j['updatedAt'] ?? j['createdAt'] ?? '').toString(),
        status: _oneOf(j['status'], kPrescriptionStatuses, 'PROCESSING'),
        summary: PrescriptionSummary.fromJson(j['summary']),
        prescriberName: _optStr(j['prescriberName']),
        clinicName: _optStr(j['clinicName']),
        failureReason: _optStr(j['failureReason']),
      );

  String get effectiveDate => prescribedDate ?? uploadedAt ?? createdAt;
}

class Prescription extends PrescriptionListItem {
  final String userId;

  /// Where the follow-up chat opens. Validated server-side against enabled specialities.
  final String suggestedSpecialitySlug;
  final String? suggestedSpecialityReason;
  final PrescriptionMetadata metadata;
  final List<Medication> medications;

  const Prescription({
    required super.id,
    required super.originalFileName,
    required super.createdAt,
    required super.updatedAt,
    required super.status,
    required super.summary,
    super.prescribedDate,
    super.uploadedAt,
    super.prescriberName,
    super.clinicName,
    super.failureReason,
    required this.userId,
    required this.suggestedSpecialitySlug,
    this.suggestedSpecialityReason,
    this.metadata = const PrescriptionMetadata(),
    this.medications = const [],
  });

  factory Prescription.fromJson(Map<String, dynamic> j) {
    final base = PrescriptionListItem.fromJson(j);
    final meds = j['medications'] is List
        ? (j['medications'] as List)
            .whereType<Map>()
            .map((m) => Medication.fromJson(Map<String, dynamic>.from(m)))
            .toList()
        : <Medication>[];
    meds.sort((a, b) => a.order.compareTo(b.order));
    return Prescription(
      id: base.id,
      originalFileName: base.originalFileName,
      createdAt: base.createdAt,
      updatedAt: base.updatedAt,
      status: base.status,
      summary: base.summary,
      prescribedDate: base.prescribedDate,
      uploadedAt: base.uploadedAt,
      prescriberName: base.prescriberName,
      clinicName: base.clinicName,
      failureReason: base.failureReason,
      userId: (j['userId'] ?? '').toString(),
      suggestedSpecialitySlug: _optStr(j['suggestedSpecialitySlug']) ?? 'general-medicine',
      suggestedSpecialityReason: _optStr(j['suggestedSpecialityReason']),
      metadata: PrescriptionMetadata.fromJson(j['metadata']),
      medications: meds,
    );
  }

  Prescription withMedications(List<Medication> next) => Prescription(
        id: id,
        originalFileName: originalFileName,
        createdAt: createdAt,
        updatedAt: updatedAt,
        status: status,
        summary: summary,
        prescribedDate: prescribedDate,
        uploadedAt: uploadedAt,
        prescriberName: prescriberName,
        clinicName: clinicName,
        failureReason: failureReason,
        userId: userId,
        suggestedSpecialitySlug: suggestedSpecialitySlug,
        suggestedSpecialityReason: suggestedSpecialityReason,
        metadata: metadata,
        medications: next,
      );

  /// Only the fields a reviewer may correct. Grades and counts are server-derived.
  Map<String, dynamic> toSavePayload() => {
        'prescribedDate': prescribedDate,
        'medications': [
          for (final m in medications)
            {
              'id': m.id,
              'name': m.name,
              'strength': m.strength,
              'dosage': m.dosage,
              'frequency': m.frequency,
              'timing': m.timing,
              'durationText': m.durationText,
              'instructions': m.instructions,
            },
        ],
      };
}

// ── Wording for a medication's read status (medicationStatus.ts) ────────────
//
// Every label describes the SCAN, never the medicine: "hard to read", not
// "incorrect"; "compare with the original", not "unsafe".

class ReadStatusCopy {
  final String label;
  final String hint;
  final String tone; // neutral | amber | coral
  const ReadStatusCopy(this.label, this.hint, this.tone);
}

const kReadStatusCopy = <String, ReadStatusCopy>{
  'CLEAR': ReadStatusCopy(
    'Read clearly',
    'This line was read cleanly from your prescription.',
    'neutral',
  ),
  'PARTIAL': ReadStatusCopy(
    'Incomplete',
    'Some details were not printed on the prescription. Add them if you know them.',
    'amber',
  ),
  'NEEDS_REVIEW': ReadStatusCopy(
    'Needs review',
    'This line was hard to read. Please compare it with the original document.',
    'coral',
  ),
};

// ── Chat hand-off (chatSummary.ts) ──────────────────────────────────────────

String? _gbDate(String? iso) {
  if (iso == null || iso.isEmpty) return null;
  final d = DateTime.tryParse(iso)?.toLocal();
  if (d == null) return null;
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return '${d.day} ${months[d.month - 1]} ${d.year}';
}

/// "Paracetamol 500 mg (tablet)" — omitting whatever the page did not say.
String _describeMedicine(Medication m) {
  final head = [m.name, m.strength].where((s) => s != null && s.isNotEmpty).join(' ');
  final form = m.form != 'OTHER' ? (kMedicationFormLabels[m.form] ?? '').toLowerCase() : null;
  // The name often already contains the form ("Mometasone cream"); don't
  // repeat it just because the field is populated.
  final needsForm = form != null && form.isNotEmpty && !head.toLowerCase().contains(form);
  return needsForm ? '$head ($form)' : head;
}

/// "1 tablet, twice daily, after food, for 5 days"
String? _describeSchedule(Medication m) {
  final parts = [m.dosage, m.frequency, m.timing].whereType<String>().where((s) => s.isNotEmpty).toList();
  if (m.durationText != null && m.durationText!.isNotEmpty) parts.add('for ${m.durationText}');
  return parts.isNotEmpty ? parts.join(', ') : null;
}

/// Turns an extracted prescription into the message that opens the follow-up
/// chat — written in the user's own voice and placed in the composer for them to
/// read and edit BEFORE sending.
String buildPrescriptionChatMessage(Prescription p, {bool includeUnclearNote = true}) {
  final lines = <String>["I've uploaded a prescription and I'd like to understand it better."];

  final context = <String>[];
  final prescribedOn = _gbDate(p.prescribedDate);
  if (prescribedOn != null) context.add('Prescribed on $prescribedOn');
  if (p.prescriberName != null && p.prescriberName!.isNotEmpty) context.add('by ${p.prescriberName}');
  if (p.clinicName != null && p.clinicName!.isNotEmpty) context.add('at ${p.clinicName}');
  if (context.isNotEmpty) lines.addAll(['', '${context.join(' ')}.']);

  if (p.metadata.indicationNotes != null) {
    lines.addAll(['', 'Noted on the prescription: ${p.metadata.indicationNotes}']);
  }

  if (p.medications.isNotEmpty) {
    lines.addAll(['', 'Medicines listed:']);
    for (var i = 0; i < p.medications.length; i++) {
      final m = p.medications[i];
      final schedule = _describeSchedule(m);
      lines.add('${i + 1}. ${_describeMedicine(m)}${schedule != null ? ' — $schedule' : ''}');
      if (m.instructions != null) lines.add('   Instructions: ${m.instructions}');
    }
  }

  // Flagging the unclear lines is what keeps the summary honest.
  final unclear = p.medications.where((m) => m.readStatus == 'NEEDS_REVIEW').toList();
  if (includeUnclearNote && unclear.isNotEmpty) {
    final names = unclear.map((m) => m.name).join(', ');
    lines.addAll([
      '',
      unclear.length == 1
          ? 'One line was hard to read ($names), so please treat it as uncertain.'
          : '${unclear.length} lines were hard to read ($names), so please treat them as uncertain.',
    ]);
  }

  lines.addAll(['', 'Could you explain what these are typically used for?']);
  return lines.join('\n');
}
