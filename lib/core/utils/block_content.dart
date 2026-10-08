import '../../data/models/chat.dart';

/// Placeholder the backend stores as an assistant message's `content` when a
/// structured (blocks) turn has no summary text. Treated as "no body" so it
/// is never shown as a message bubble on its own. Mirrors
/// `blockContent.ts`'s `STRUCTURED_PLACEHOLDER` — single source of truth on
/// the web side, ported here since Dart can't import it directly.
const String kStructuredPlaceholder = '[Nova sent a structured response]';

bool _hasText(String? s) => s != null && s.trim().isNotEmpty;

/// Does this block produce visible output when passed to [BlockRenderer]?
/// Mirrors `blockContent.ts#isRenderableBlock` — keep both in sync.
///
/// `follow_up_questions` is intentionally hidden as trailing chips in normal
/// turns, so it counts as NOT visible here — a turn whose only block is
/// follow_up_questions (an interview/triage question) then falls back to
/// [deriveFallbackText] instead of rendering an empty bubble.
bool isRenderableBlock(MessageBlock block) {
  if (block is SummaryBlock) return _hasText(block.text);
  if (block is WarningBlock) return true;
  if (block is DecisionBlock) return true;
  if (block is ConditionListBlock) return block.conditions.isNotEmpty;
  if (block is NextStepsBlock) return block.steps.isNotEmpty;
  if (block is BulletListBlock) return block.items.isNotEmpty;
  if (block is KeyPointsBlock) return block.points.isNotEmpty;
  if (block is OtcMedicationsBlock) return block.medications.isNotEmpty;
  if (block is LabTestsBlock) return block.tests.isNotEmpty;
  // Unlike follow_up_questions, this block IS shown: the options are the
  // interaction, so hiding it would remove the only way to answer.
  if (block is QuestionBlock) {
    return _hasText(block.question) || block.options.isNotEmpty;
  }
  if (block is FollowUpQuestionsBlock) return false;
  if (block is UnknownBlock) return _hasText(block.text);
  return false;
}

/// Best-effort human-readable text pulled out of a single block. Mirrors
/// `blockContent.ts#blockPlainText`.
String blockPlainText(MessageBlock block) {
  final parts = <String>[];

  if (block is SummaryBlock && _hasText(block.text)) parts.add(block.text.trim());
  if (block is WarningBlock && _hasText(block.text)) parts.add(block.text!.trim());
  if (block is UnknownBlock && _hasText(block.text)) parts.add(block.text!.trim());
  if (block is DecisionBlock && _hasText(block.rationale)) {
    parts.add(block.rationale.trim());
  }
  if (block is FollowUpQuestionsBlock && block.questions.isNotEmpty) {
    parts.add(block.questions.join('\n'));
  }
  // `question` carries its prompt under a distinct key so that a question-only
  // turn still yields readable fallback text.
  if (block is QuestionBlock) {
    if (_hasText(block.question)) parts.add(block.question.trim());
    if (block.options.isNotEmpty) parts.add(block.options.join('\n'));
  }
  if (block is KeyPointsBlock && block.points.isNotEmpty) {
    parts.add(block.points.join('\n'));
  }
  if (block is BulletListBlock && block.items.isNotEmpty) {
    parts.add(block.items.join('\n'));
  }
  if (block is NextStepsBlock && block.steps.isNotEmpty) {
    parts.add(block.steps.join('\n'));
  }
  // lab_tests carries objects, not string arrays — flatten to "name — reason".
  if (block is LabTestsBlock && block.tests.isNotEmpty) {
    final lines = block.tests
        .map((t) => [t.name, t.reason].where(_hasText).join(' — '))
        .where((s) => s.isNotEmpty)
        .toList();
    if (lines.isNotEmpty) parts.add(lines.join('\n'));
  }

  return parts.join('\n\n');
}

/// Fallback text to show when NONE of a message's blocks render visibly — so
/// an interview turn (only `follow_up_questions`) or a future unrecognised
/// block still shows its content instead of a blank bubble. Prefers text
/// extracted from the blocks; otherwise the message body, unless that's the
/// structured placeholder. Empty string => genuinely nothing to render
/// (caller should draw no bubble at all rather than an empty one). Mirrors
/// `blockContent.ts#deriveFallbackText`.
String deriveFallbackText(String text, List<MessageBlock>? blocks) {
  final fromBlocks = (blocks ?? const <MessageBlock>[])
      .map(blockPlainText)
      .where((s) => s.isNotEmpty)
      .join('\n\n');
  if (fromBlocks.isNotEmpty) return fromBlocks;
  final body = text.trim();
  return (body.isNotEmpty && body != kStructuredPlaceholder) ? body : '';
}
