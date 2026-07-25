import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Nova's opening line (uses the signed-in user's first name).
String novaGreeting([String? name]) {
  final who = (name != null && name.trim().isNotEmpty) ? name.trim() : 'there';
  return "Hi $who! I'm Nova, your AI health assistant. I can help with health info, "
      "medications, reports and more. What can I help with today?";
}

/// The prompt shown above the quick-action grid on a fresh Nova session.
const String kNovaDefaultQuestion = 'How are you feeling today?';

class QuickAction {
  final IconData icon;
  final String label;
  final String text;
  const QuickAction({required this.icon, required this.label, required this.text});
}

/// Default quick-action chips for a generic Nova session.
final List<QuickAction> kNovaDefaultQuick = [
  QuickAction(icon: PhosphorIconsRegular.pill, label: 'Medications', text: 'Tell me about my medications'),
  QuickAction(
      icon: PhosphorIconsRegular.clipboardText, label: 'My reports', text: 'Summarise my latest report'),
  QuickAction(icon: PhosphorIconsRegular.heartbeat, label: 'Symptoms', text: "I'm not feeling well"),
];
