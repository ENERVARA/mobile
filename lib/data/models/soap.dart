/// A doctor-facing SOAP note generated on demand from the conversation.
/// Generation lives entirely on the backend; the client only presents it.
/// Ported from `src/types/chat.ts` (`SoapNote`) + `chatSoapService.ts`.
class SoapNote {
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;

  /// Information the model could not find in the conversation — shown as
  /// "Not documented in this conversation", distinct from confirmed negatives.
  final List<String> unavailable;
  final String? generatedAt;

  const SoapNote({
    this.subjective = '',
    this.objective = '',
    this.assessment = '',
    this.plan = '',
    this.unavailable = const [],
    this.generatedAt,
  });

  Map<String, dynamic> toJson() => {
    'subjective': subjective,
    'objective': objective,
    'assessment': assessment,
    'plan': plan,
    'unavailable': unavailable,
    if (generatedAt != null) 'generatedAt': generatedAt,
  };

  static String _str(dynamic v) {
    if (v is String) return v.trim();
    // Some SOAP backends return a section as a list of bullet strings.
    if (v is List) return v.whereType<String>().join('\n').trim();
    return '';
  }

  /// Normalizes whatever shape the SOAP backend returns into a flat
  /// [SoapNote]. Tolerant of a top-level `{subjective,…}`, a nested
  /// `{soap:{…}}`/`{note:{…}}`, single-letter keys, and snake/camel casing —
  /// so a small upstream contract change doesn't break the UI.
  factory SoapNote.normalize(dynamic data) {
    final root = (data is Map)
        ? Map<String, dynamic>.from(data)
        : <String, dynamic>{};
    final src = (root['soap'] is Map)
        ? Map<String, dynamic>.from(root['soap'] as Map)
        : (root['note'] is Map)
        ? Map<String, dynamic>.from(root['note'] as Map)
        : root;

    String pick(List<String> keys) {
      for (final k in keys) {
        final v = _str(src[k]);
        if (v.isNotEmpty) return v;
      }
      return '';
    }

    final unavailableRaw = src['unavailable'] ?? root['unavailable'];
    final unavailable = (unavailableRaw is List)
        ? unavailableRaw
              .whereType<String>()
              .where((x) => x.trim().isNotEmpty)
              .map((x) => x.trim())
              .toList()
        : <String>[];

    final generatedAt = _str(root['generatedAt'] ?? root['generated_at']);

    return SoapNote(
      subjective: pick(['subjective', 'Subjective', 'S', 's']),
      objective: pick(['objective', 'Objective', 'O', 'o']),
      assessment: pick(['assessment', 'Assessment', 'A', 'a']),
      plan: pick(['plan', 'Plan', 'P', 'p']),
      unavailable: unavailable,
      generatedAt: generatedAt.isNotEmpty ? generatedAt : null,
    );
  }
}

/// Patient demographics snapshot for the SOAP document header — built from
/// the authenticated user's record. Missing fields render as an em dash so a
/// clinician sees what the record does/doesn't hold.
class SoapPatientInfo {
  final String name;
  final String age;
  final String sex;
  final String height;
  final String weight;
  final String? bmi;

  const SoapPatientInfo({
    required this.name,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
    this.bmi,
  });
}
