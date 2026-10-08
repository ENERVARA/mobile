import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/care_journey.dart';
import 'chat_provider.dart';

/// The active conversation's care journey — whatever the backend last reported,
/// or a local stand-in (only the Complaint step known, from the conversation's
/// own title/createdAt) until it reports one. Mirrors `useCurrentCareJourney`.
final currentCareJourneyProvider = Provider<CareJourney>((ref) {
  final activeId = ref.watch(chatProvider.select((s) => s.activeConversationId));
  final reported = ref.watch(
    chatProvider.select((s) => activeId == null ? null : s.journeys[activeId]),
  );
  final conversation = ref.watch(
    chatProvider.select((s) => s.conversations.where((c) => c.id == activeId).firstOrNull),
  );
  final hasMessages = ref.watch(chatProvider.select((s) => s.messages.isNotEmpty));

  return reported ??
      initialCareJourney(
        hasMessages && conversation != null && conversation.title.isNotEmpty ? conversation.title : null,
        conversation?.createdAt,
      );
});
