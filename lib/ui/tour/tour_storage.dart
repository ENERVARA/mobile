import 'package:shared_preferences/shared_preferences.dart';

/// When the product tour should run on its own. Ported from
/// `features/tour/tourStorage.ts`.
///
/// There is no server-side "has seen the tour" flag, so this combines two
/// client-side signals: the account is NEW (created recently), and this device
/// hasn't already shown it to that user. The recency window is what keeps the
/// tour from ambushing every existing user the day it ships.
String _storageKey(String userId) => 'enervara:tour:v1:$userId';

/// An account counts as "new" for a week after it was created.
const kNewAccountWindow = Duration(days: 7);

Future<bool> hasSeenTour(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_storageKey(userId)) != null;
  } catch (_) {
    // Storage unavailable: treat as seen rather than risk replaying the tour on
    // every load with no way to record that it was dismissed.
    return true;
  }
}

Future<void> markTourSeen(String userId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey(userId), DateTime.now().toIso8601String());
  } catch (_) {
    /* nothing to do — see hasSeenTour */
  }
}

bool isNewAccount(String? createdAt, [DateTime? now]) {
  if (createdAt == null || createdAt.isEmpty) return false;
  final created = DateTime.tryParse(createdAt);
  if (created == null) return false;
  return (now ?? DateTime.now()).difference(created) <= kNewAccountWindow;
}

Future<bool> shouldAutoStartTour(String userId, String? createdAt) async {
  return isNewAccount(createdAt) && !(await hasSeenTour(userId));
}
