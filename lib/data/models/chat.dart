// Chat models — ported from `src/types/chat.ts` + `components/nova/types.ts`.

class ChatConversation {
  final String id;
  final String sessionId;
  final String specialitySlug;
  final String title;
  final String lastMessageAt;
  final String createdAt;
  final bool blocksEnabled;

  /// Latest known care-journey stage, when the backend includes it on the
  /// conversations LIST endpoint. Absent/null means unknown — treated as still
  /// active, never hidden as "previous".
  final String? currentStage;

  /// How this consultation is being handled — `agent` (Nova/AI) or `offline`.
  /// Every conversation today is Nova-driven, so this defaults to `agent`.
  final String mode;

  /// The care journey's "Complaint" stage summary ("Cold", "Chest pain on
  /// exertion"), mirrored onto the conversations LIST endpoint so the health
  /// timeline can show it without fetching every full journey.
  final String? complaintSummary;

  const ChatConversation({
    required this.id,
    required this.sessionId,
    required this.specialitySlug,
    required this.title,
    required this.lastMessageAt,
    required this.createdAt,
    required this.blocksEnabled,
    this.currentStage,
    this.mode = 'agent',
    this.complaintSummary,
  });

  factory ChatConversation.fromJson(Map<String, dynamic> json) {
    String? opt(dynamic v) {
      final s = v?.toString();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ChatConversation(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      sessionId: (json['sessionId'] ?? '') as String,
      specialitySlug: (json['specialitySlug'] ?? '') as String,
      title: (json['title'] ?? 'New chat') as String,
      lastMessageAt:
          (json['lastMessageAt'] ?? json['createdAt'] ?? '') as String,
      createdAt: (json['createdAt'] ?? '') as String,
      blocksEnabled: json['blocksEnabled'] == true,
      currentStage: opt(json['currentStage']),
      mode: json['mode'] == 'offline' ? 'offline' : 'agent',
      complaintSummary: opt(json['complaintSummary']),
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
      currentStage: currentStage,
      mode: mode,
      complaintSummary: complaintSummary,
    );
  }

  /// A conversation counts as "active" care unless the backend has explicitly
  /// said otherwise (`currentStage == 'resolved'`). Mirrors `isActiveCare`.
  bool get isActiveCare => currentStage != 'resolved';
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
                  .map(
                    (c) => ConditionEntry(
                      name: c['name']?.toString() ?? '',
                      likelihood: c['likelihood']?.toString(),
                    ),
                  )
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
        return BulletListBlock(
          title: data['title']?.toString(),
          items: strList(data['items']),
        );
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
                  .map(
                    (m) => OtcMedication(
                      name: m['name']?.toString() ?? '',
                      purpose: m['purpose']?.toString() ?? '',
                      dosage: m['dosage']?.toString(),
                      caution: m['caution']?.toString(),
                    ),
                  )
                  .toList()
            : <OtcMedication>[];
        return OtcMedicationsBlock(meds);
      case 'lab_tests':
        final tests = (data['tests'] is List)
            ? (data['tests'] as List)
                  .whereType<Map>()
                  .map(
                    (t) => LabTest(
                      name: t['name']?.toString() ?? '',
                      reason: t['reason']?.toString() ?? '',
                      urgency: t['urgency']?.toString(),
                    ),
                  )
                  .toList()
            : <LabTest>[];
        return LabTestsBlock(tests);
      case 'question':
        return QuestionBlock(
          question: data['question']?.toString().trim() ?? '',
          options: strList(data['options'])
              .where((o) => o.trim().isNotEmpty)
              .toList(),
        );
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
  final String? likelihood;
  const ConditionEntry({required this.name, this.likelihood});
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
  const BulletListBlock({this.title, required this.items})
    : super('bullet_list');
}

class KeyPointsBlock extends MessageBlock {
  final List<String> points;
  const KeyPointsBlock(this.points) : super('key_points');
}

class DecisionBlock extends MessageBlock {
  final String
  verdict; // yes | no | possibly | seek_urgent_care | insufficient_information
  final String rationale;
  const DecisionBlock({required this.verdict, required this.rationale})
    : super('decision');
}

class OtcMedication {
  final String name;
  final String purpose;
  final String? dosage;
  final String? caution;
  const OtcMedication({
    required this.name,
    required this.purpose,
    this.dosage,
    this.caution,
  });
}

class OtcMedicationsBlock extends MessageBlock {
  final List<OtcMedication> medications;
  const OtcMedicationsBlock(this.medications) : super('otc_medications');
}

class LabTest {
  final String name;
  final String reason;
  final String? urgency; // routine | soon | urgent
  const LabTest({required this.name, required this.reason, this.urgency});
}

class LabTestsBlock extends MessageBlock {
  final List<LabTest> tests;
  const LabTestsBlock(this.tests) : super('lab_tests');
}

/// One question with tappable quick-reply answers (dealt as a deck of cards).
class QuestionBlock extends MessageBlock {
  final String question;
  final List<String> options;
  const QuestionBlock({required this.question, required this.options})
    : super('question');
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

class MessageAnalysis {
  final String? category;
  final String? route;
  final String? caption;
  final List<String> extractedFacts;

  const MessageAnalysis({
    this.category,
    this.route,
    this.caption,
    this.extractedFacts = const [],
  });

  factory MessageAnalysis.fromJson(Map<String, dynamic> json) {
    return MessageAnalysis(
      category: json['category']?.toString(),
      route: json['route']?.toString(),
      caption: json['caption']?.toString(),
      extractedFacts: (json['extracted_facts'] is List)
          ? (json['extracted_facts'] as List).map((e) => e.toString()).toList()
          : const [],
    );
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

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: (json['id'] ?? json['_id'] ?? '').toString(),
      conversationId: (json['conversationId'] ?? '') as String,
      role: (json['role'] ?? 'assistant') as String,
      content: (json['content'] ?? '') as String,
      followupQuestions: (json['followupQuestions'] is List)
          ? (json['followupQuestions'] as List)
                .map((e) => e.toString())
                .toList()
          : null,
      blocks: (json['blocks'] is List)
          ? (json['blocks'] as List)
                .whereType<Map>()
                .map((b) => MessageBlock.fromJson(Map<String, dynamic>.from(b)))
                .toList()
          : null,
      analysis: (json['analysis'] is Map)
          ? MessageAnalysis.fromJson(
              Map<String, dynamic>.from(json['analysis'] as Map),
            )
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
