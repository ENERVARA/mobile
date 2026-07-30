// Chat models — ported from `src/types/chat.ts` + `components/nova/types.ts`.

class ChatConversation {
  final String id;
  final String sessionId;
  final String specialitySlug;
  final String title;
  final String lastMessageAt;
  final String createdAt;
  final bool blocksEnabled;

  const ChatConversation({
    required this.id,
    required this.sessionId,
    required this.specialitySlug,
    required this.title,
    required this.lastMessageAt,
    required this.createdAt,
    required this.blocksEnabled,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    return ChatConversation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '') as String,
      specialitySlug: (json['specialitySlug'] ?? '') as String,
      title: (json['title'] ?? 'New chat') as String,
      lastMessageAt: (json['lastMessageAt'] ?? json['createdAt'] ?? '') as String,
      createdAt: (json['createdAt'] ?? '') as String,
      blocksEnabled: json['blocksEnabled'] == true,
    );
  }

  ChatConversation copyWith({String? title, String? lastMessageAt}) {
    return ChatConversation(
      id: id,
      sessionId: sessionId,
      specialitySlug: specialitySlug,
      title: title ?? this.title,
      lastMessageAt: lastMessageAt ?? this.lastMessageAt,
      createdAt: createdAt,
      blocksEnabled: blocksEnabled,
    );
  }
}

// ─── Structured response blocks (general-medicine only) ──────────────────────

abstract class MessageBlock {
  final String type;
  const MessageBlock(this.type);

  factory MessageBlock.fromJson(Map<String, dynamic> json) {
    final type = (json['type'] ?? '').toString();
    final data = (json['data'] is Map)
        ? Map<String, dynamic>.from(json['data'] as Map)
        : <String, dynamic>{};

    List<String> strList(dynamic v) =>
        (v is List) ? v.map((e) => e.toString()).toList() : const [];

    switch (type) {
      case 'summary':
        return SummaryBlock(data['text']?.toString() ?? '');
      case 'condition_list':
        final conditions = (data['conditions'] is List)
            ? (data['conditions'] as List)
                .whereType<Map>()
                .map((c) => ConditionEntry(
                      name: c['name']?.toString() ?? '',
                      likelihood: c['likelihood']?.toString(),
                      description: c['description']?.toString(),
                    ))
                .toList()
            : <ConditionEntry>[];
        return ConditionListBlock(conditions);
      case 'warning':
        return WarningBlock(
          text: data['text']?.toString(),
          severity: data['severity']?.toString(),
        );
      case 'next_steps':
        return NextStepsBlock(strList(data['steps']));
      case 'bullet_list':
        return BulletListBlock(title: data['title']?.toString(), items: strList(data['items']));
      case 'key_points':
        return KeyPointsBlock(strList(data['points']));
      case 'decision':
        return DecisionBlock(
          verdict: data['verdict']?.toString() ?? 'insufficient_information',
          rationale: data['rationale']?.toString() ?? '',
        );
      case 'otc_medications':
        final meds = (data['medications'] is List)
            ? (data['medications'] as List)
                .whereType<Map>()
                .map((m) => OtcMedication(
                      name: m['name']?.toString() ?? '',
                      purpose: m['purpose']?.toString() ?? '',
                      dosage: m['dosage']?.toString(),
                      caution: m['caution']?.toString(),
                    ))
                .toList()
            : <OtcMedication>[];
        return OtcMedicationsBlock(meds);
      case 'lab_tests':
        final tests = (data['tests'] is List)
            ? (data['tests'] as List)
                .whereType<Map>()
                .map((t) => LabTest(
                      name: t['name']?.toString() ?? '',
                      reason: t['reason']?.toString() ?? '',
                      urgency: t['urgency']?.toString(),
                    ))
                .toList()
            : <LabTest>[];
        return LabTestsBlock(tests);
      case 'answer_state':
        return AnswerStateBlock(showDoctorSummary: data['show_doctor_summary'] == true);
      case 'follow_up_questions':
        return FollowUpQuestionsBlock(strList(data['questions']));
      default:
        return UnknownBlock(type, data, data['text']?.toString());
    }
  }
}

class SummaryBlock extends MessageBlock {
  final String text;
  const SummaryBlock(this.text) : super('summary');
}

class ConditionEntry {
  final String name;
  final String? likelihood; // "most likely" | "possible" | "less likely" | null
  final String? description;
  const ConditionEntry({required this.name, this.likelihood, this.description});
}

class ConditionListBlock extends MessageBlock {
  final List<ConditionEntry> conditions;
  const ConditionListBlock(this.conditions) : super('condition_list');
}

class WarningBlock extends MessageBlock {
  final String? text;
  final String? severity;
  const WarningBlock({this.text, this.severity}) : super('warning');
}

class NextStepsBlock extends MessageBlock {
  final List<String> steps;
  const NextStepsBlock(this.steps) : super('next_steps');
}

class BulletListBlock extends MessageBlock {
  final String? title;
  final List<String> items;
  const BulletListBlock({this.title, required this.items}) : super('bullet_list');
}

class KeyPointsBlock extends MessageBlock {
  final List<String> points;
  const KeyPointsBlock(this.points) : super('key_points');
}

class DecisionBlock extends MessageBlock {
  final String verdict; // yes | no | possibly | seek_urgent_care | insufficient_information
  final String rationale;
  const DecisionBlock({required this.verdict, required this.rationale}) : super('decision');
}

class OtcMedication {
  final String name;
  final String purpose;
  final String? dosage;
  final String? caution;
  const OtcMedication({required this.name, required this.purpose, this.dosage, this.caution});
}

class OtcMedicationsBlock extends MessageBlock {
  final List<OtcMedication> medications;
  const OtcMedicationsBlock(this.medications) : super('otc_medications');
}

class LabTest {
  final String name;
  final String reason;
  final String? urgency; // "routine" | "soon" | "urgent" | null
  const LabTest({required this.name, required this.reason, this.urgency});
}

/// Suggested investigations to discuss with a doctor/lab — never orders.
/// Only arrives on a concluded answer, just before [OtcMedicationsBlock].
class LabTestsBlock extends MessageBlock {
  final List<LabTest> tests;
  const LabTestsBlock(this.tests) : super('lab_tests');
}

/// Control block — always the final block of a turn, never rendered. Carries
/// the sticky `show_doctor_summary` flag that reveals the SOAP-note action.
class AnswerStateBlock extends MessageBlock {
  final bool showDoctorSummary;
  const AnswerStateBlock({required this.showDoctorSummary}) : super('answer_state');
}

class FollowUpQuestionsBlock extends MessageBlock {
  final List<String> questions;
  const FollowUpQuestionsBlock(this.questions) : super('follow_up_questions');
}

class UnknownBlock extends MessageBlock {
  final Map<String, dynamic> data;
  final String? text;
  const UnknownBlock(super.type, this.data, this.text);
}

// ─── Image analysis (from /chat/image `media`) ───────────────────────────────

/// The `media` object returned by the image endpoint. The backend classifies
/// the upload itself, so [category] and [route] are how the UI learns whether
/// it got a photo read by the vision model or a document that was parsed.
class MessageAnalysis {
  /// clinical_photo | general_photo | lab_report | radiology_report |
  /// document | other_medical_document | unknown
  final String? category;

  /// multimodal_llm | document_extraction
  final String? route;
  final String? caption;
  final List<String> extractedFacts;
  final String? mimeType;
  final int? sizeBytes;
  final String? filename;

  /// Backend reference, not a fetchable URL — never render it as one.
  final String? storageUri;

  const MessageAnalysis({
    this.category,
    this.route,
    this.caption,
    this.extractedFacts = const [],
    this.mimeType,
    this.sizeBytes,
    this.filename,
    this.storageUri,
  });

  factory MessageAnalysis.fromJson(Map<String, dynamic> json) {
    final size = json['size_bytes'] ?? json['sizeBytes'];
    return MessageAnalysis(
      category: json['category']?.toString(),
      route: json['route']?.toString(),
      caption: json['caption']?.toString(),
      extractedFacts: (json['extracted_facts'] is List)
          ? (json['extracted_facts'] as List).map((e) => e.toString()).toList()
          : (json['extractedFacts'] is List)
              ? (json['extractedFacts'] as List).map((e) => e.toString()).toList()
              : const [],
      mimeType: (json['mime_type'] ?? json['mimeType'])?.toString(),
      sizeBytes: size is int ? size : int.tryParse(size?.toString() ?? ''),
      filename: json['filename']?.toString(),
      storageUri: (json['storage_uri'] ?? json['storageUri'])?.toString(),
    );
  }

  /// True when the upload was parsed as a document rather than looked at as a
  /// photo — drives the "📄 Lab report" vs "📷 Photo" labelling.
  bool get isDocument =>
      route == 'document_extraction' ||
      const {'lab_report', 'radiology_report', 'document', 'other_medical_document'}
          .contains(category);

  /// Human label for [category], falling back to the route when the backend
  /// couldn't classify it.
  String? get categoryLabel {
    switch (category) {
      case 'clinical_photo':
        return 'Clinical photo';
      case 'general_photo':
        return 'Photo';
      case 'lab_report':
        return 'Lab report';
      case 'radiology_report':
        return 'Radiology report';
      case 'document':
        return 'Document';
      case 'other_medical_document':
        return 'Medical document';
      case 'unknown':
      case null:
        return isDocument ? 'Document' : null;
      default:
        return category;
    }
  }

  /// Nothing worth drawing a card for.
  bool get isEmpty =>
      categoryLabel == null &&
      (caption == null || caption!.trim().isEmpty) &&
      extractedFacts.isEmpty;
}

// ─── Doctor-facing SOAP note (from /chat/.../soap) ───────────────────────────

/// Regenerated on demand from the full conversation — the "Show this to your
/// doctor" export. Grounded strictly in what was said; anything clinically
/// relevant but missing is listed in [unavailable].
class SoapNote {
  final String subjective;
  final String objective;
  final String assessment;
  final String plan;
  final List<String> unavailable;
  final String? generatedAt;

  const SoapNote({
    required this.subjective,
    required this.objective,
    required this.assessment,
    required this.plan,
    this.unavailable = const [],
    this.generatedAt,
  });

  factory SoapNote.fromJson(Map<String, dynamic> json) {
    return SoapNote(
      subjective: json['subjective']?.toString() ?? '',
      objective: json['objective']?.toString() ?? '',
      assessment: json['assessment']?.toString() ?? '',
      plan: json['plan']?.toString() ?? '',
      unavailable: (json['unavailable'] is List)
          ? (json['unavailable'] as List).map((e) => e.toString()).toList()
          : const [],
      generatedAt: json['generated_at']?.toString() ?? json['generatedAt']?.toString(),
    );
  }

  /// Plain-text rendering for share / copy.
  String toPlainText() {
    final b = StringBuffer()
      ..writeln('SUBJECTIVE')
      ..writeln(subjective)
      ..writeln()
      ..writeln('OBJECTIVE')
      ..writeln(objective)
      ..writeln()
      ..writeln('ASSESSMENT')
      ..writeln(assessment)
      ..writeln()
      ..writeln('PLAN')
      ..writeln(plan);
    if (unavailable.isNotEmpty) {
      b
        ..writeln()
        ..writeln('NOT DOCUMENTED IN THIS CONVERSATION');
      for (final u in unavailable) {
        b.writeln('- $u');
      }
    }
    return b.toString();
  }
}

// ─── Persisted message ───────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String conversationId;
  final String role; // user | assistant
  final String content;
  final List<String>? followupQuestions;
  final List<MessageBlock>? blocks;
  final MessageAnalysis? analysis;
  final String? imageFileId;
  final String? imageMimeType;
  final String? localPreviewUrl;
  final int? uploadProgress;
  final String createdAt;

  const ChatMessage({
    required this.id,
    required this.conversationId,
    required this.role,
    required this.content,
    this.followupQuestions,
    this.blocks,
    this.analysis,
    this.imageFileId,
    this.imageMimeType,
    this.localPreviewUrl,
    this.uploadProgress,
    required this.createdAt,
  });

  /// Mainly used to carry [localPreviewUrl] across the optimistic → persisted
  /// swap: the server message knows the file id but not the on-device path, so
  /// without this the user's photo would blank out the moment the upload lands.
  ChatMessage copyWith({
    String? localPreviewUrl,
    int? uploadProgress,
    bool clearUploadProgress = false,
  }) {
    return ChatMessage(
      id: id,
      conversationId: conversationId,
      role: role,
      content: content,
      followupQuestions: followupQuestions,
      blocks: blocks,
      analysis: analysis,
      imageFileId: imageFileId,
      imageMimeType: imageMimeType,
      localPreviewUrl: localPreviewUrl ?? this.localPreviewUrl,
      uploadProgress: clearUploadProgress ? null : (uploadProgress ?? this.uploadProgress),
      createdAt: createdAt,
    );
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '') as String,
      role: (json['role'] ?? 'assistant') as String,
      content: (json['content'] ?? '') as String,
      followupQuestions: (json['followupQuestions'] is List)
          ? (json['followupQuestions'] as List).map((e) => e.toString()).toList()
          : null,
      blocks: (json['blocks'] is List)
          ? (json['blocks'] as List)
              .whereType<Map>()
              .map((b) => MessageBlock.fromJson(Map<String, dynamic>.from(b)))
              .toList()
          : null,
      // The service calls this `media`; the BFF persists it as `analysis`.
      analysis: (json['analysis'] is Map)
          ? MessageAnalysis.fromJson(Map<String, dynamic>.from(json['analysis'] as Map))
          : (json['media'] is Map)
              ? MessageAnalysis.fromJson(Map<String, dynamic>.from(json['media'] as Map))
              : null,
      imageFileId: json['imageFileId'] as String?,
      imageMimeType: json['imageMimeType'] as String?,
      createdAt: (json['createdAt'] ?? '') as String,
    );
  }
}

// ─── Panel-local message (assistant → nova) ──────────────────────────────────

class PanelMessage {
  final String id;
  final String role; // nova | user
  final String text;
  final String time;
  final List<MessageBlock>? blocks;
  final String? imageFileId;
  final String? imageMimeType;
  final String? localPreviewUrl;
  final int? uploadProgress;
  final MessageAnalysis? analysis;

  const PanelMessage({
    required this.id,
    required this.role,
    required this.text,
    required this.time,
    this.blocks,
    this.imageFileId,
    this.imageMimeType,
    this.localPreviewUrl,
    this.uploadProgress,
    this.analysis,
  });

  bool get isUser => role == 'user';
}
