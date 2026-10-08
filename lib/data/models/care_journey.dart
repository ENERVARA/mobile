import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Care journey — the five-step progress rail shown in Nova in place of chat
/// history: issue → speciality → doctor → documents → resolved. Ported from
/// `components/nova/careJourney.ts`.
///
/// The backend owns the data. It can send a journey in any of three places, all
/// optional, all run through [parseCareJourney]:
///   1. `GET /chat/conversations/:id` → `conversation.journey`   (hydrate on open)
///   2. SSE event `{ type: "journey", journey: {...} }`           (live, mid-turn)
///   3. SSE `done` payload → `journey`                            (end of turn)
///
/// Status per stage: an explicit `status` wins; otherwise stages before
/// `current_stage` are done, the current one is active, later ones pending.
const kJourneyStages = ['issue', 'speciality', 'doctor', 'documents', 'resolved'];

enum JourneyStageStatus { pending, active, done }

class JourneyStage {
  final String key;
  final JourneyStageStatus status;

  /// A few words from the backend; null until that stage has content.
  final String? summary;

  /// ISO datetime the stage happened, when the backend sends one.
  final String? timestamp;

  const JourneyStage({
    required this.key,
    required this.status,
    this.summary,
    this.timestamp,
  });

  JourneyStage withStatus(JourneyStageStatus s) =>
      JourneyStage(key: key, status: s, summary: summary, timestamp: timestamp);
}

class CareJourney {
  final List<JourneyStage> stages;
  final String? current;
  const CareJourney({required this.stages, this.current});
}

class JourneyStageMeta {
  final String title;

  /// Regular weight (a stage that hasn't happened yet) and bold (done / active).
  final IconData icon;
  final IconData iconBold;
  final String placeholder;
  const JourneyStageMeta(this.title, this.icon, this.iconBold, this.placeholder);
}

/// The stage KEYS are the wire contract and never change; `issue`/`resolved`
/// display as "Complaint"/"Complaint cured".
const kJourneyStageMeta = <String, JourneyStageMeta>{
  'issue': JourneyStageMeta(
    'Complaint',
    PhosphorIconsRegular.chatCircleText,
    PhosphorIconsBold.chatCircleText,
    'Tell Nova what’s going on',
  ),
  'speciality': JourneyStageMeta(
    'Speciality agent',
    PhosphorIconsRegular.stethoscope,
    PhosphorIconsBold.stethoscope,
    'Identified from your conversation',
  ),
  'doctor': JourneyStageMeta(
    'Consultation doctor',
    PhosphorIconsRegular.userCirclePlus,
    PhosphorIconsBold.userCirclePlus,
    'Matched when a consult is needed',
  ),
  'documents': JourneyStageMeta(
    'Documents upload',
    PhosphorIconsRegular.fileArrowUp,
    PhosphorIconsBold.fileArrowUp,
    'Reports or prescriptions, if asked',
  ),
  'resolved': JourneyStageMeta(
    'Complaint cured',
    PhosphorIconsRegular.sealCheck,
    PhosphorIconsBold.sealCheck,
    'Closed once you’re sorted',
  ),
};

String? _text(dynamic v) {
  if (v is String && v.trim().isNotEmpty) return v.trim();
  return null;
}

/// A valid ISO datetime, or null — never a string that fails to parse.
String? _isoDate(dynamic v) {
  if (v is! String || v.trim().isEmpty) return null;
  return DateTime.tryParse(v) == null ? null : v;
}

bool _isStageKey(dynamic v) => v is String && kJourneyStages.contains(v);

JourneyStageStatus? _statusOf(dynamic v) {
  switch (v) {
    case 'pending':
      return JourneyStageStatus.pending;
    case 'active':
      return JourneyStageStatus.active;
    case 'done':
      return JourneyStageStatus.done;
  }
  return null;
}

/// Normalises a backend journey payload. Returns null for anything unusable.
CareJourney? parseCareJourney(dynamic raw) {
  if (raw is! Map) return null;
  final o = Map<String, dynamic>.from(raw);
  final current = o['current_stage'] ?? o['currentStage'];
  final stagesRaw = o['stages'] is Map ? Map<String, dynamic>.from(o['stages'] as Map) : <String, dynamic>{};
  if (!_isStageKey(current) && stagesRaw.isEmpty) return null;

  final currentIndex = _isStageKey(current) ? kJourneyStages.indexOf(current as String) : -1;

  final stages = <JourneyStage>[];
  for (var index = 0; index < kJourneyStages.length; index++) {
    final key = kJourneyStages[index];
    final s = stagesRaw[key] is Map ? Map<String, dynamic>.from(stagesRaw[key] as Map) : <String, dynamic>{};
    final summary = _text(s['summary'] ?? s['description']);
    final timestamp = _isoDate(s['timestamp'] ?? s['occurred_at'] ?? s['occurredAt'] ?? s['at']);
    JourneyStageStatus status;
    final explicit = _statusOf(s['status']);
    if (explicit != null) {
      status = explicit;
    } else if (currentIndex == -1) {
      status = summary != null ? JourneyStageStatus.done : JourneyStageStatus.pending;
    } else {
      status = index < currentIndex
          ? JourneyStageStatus.done
          : index == currentIndex
              ? JourneyStageStatus.active
              : JourneyStageStatus.pending;
    }
    stages.add(JourneyStage(key: key, status: status, summary: summary, timestamp: timestamp));
  }

  // Only one stage may glow; if the backend marked several, keep the earliest.
  var seenActive = false;
  for (var i = 0; i < stages.length; i++) {
    if (stages[i].status != JourneyStageStatus.active) continue;
    if (seenActive) stages[i] = stages[i].withStatus(JourneyStageStatus.pending);
    seenActive = true;
  }

  final active = stages.where((s) => s.status == JourneyStageStatus.active).firstOrNull;
  return CareJourney(
    stages: stages,
    current: active?.key ?? (_isStageKey(current) ? current as String : null),
  );
}

/// Local stand-in until the backend sends a journey: only the issue step is
/// known, and it is in progress. [issueTimestamp] is real data when given (the
/// conversation's own `createdAt`) — nothing downstream is guessed.
CareJourney initialCareJourney(String? issueSummary, [String? issueTimestamp]) {
  return CareJourney(
    current: 'issue',
    stages: [
      for (final key in kJourneyStages)
        JourneyStage(
          key: key,
          status: key == 'issue' ? JourneyStageStatus.active : JourneyStageStatus.pending,
          summary: key == 'issue' ? issueSummary : null,
          timestamp: key == 'issue' ? issueTimestamp : null,
        ),
    ],
  );
}
