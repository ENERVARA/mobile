import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// First-run state for new users. Only [welcomeSeen] is persisted (the feature
/// tour is a per-install thing); the post-onboarding health-setup prompt is
/// driven by a one-time route transition, not a stored flag.
class FirstRunState {
  final bool loaded;
  final bool welcomeSeen;
  const FirstRunState({this.loaded = false, this.welcomeSeen = false});

  FirstRunState copyWith({bool? loaded, bool? welcomeSeen}) => FirstRunState(
        loaded: loaded ?? this.loaded,
        welcomeSeen: welcomeSeen ?? this.welcomeSeen,
      );
}

final firstRunProvider =
    StateNotifierProvider<FirstRunController, FirstRunState>((ref) => FirstRunController());

class FirstRunController extends StateNotifier<FirstRunState> {
  FirstRunController() : super(const FirstRunState()) {
    _load();
  }

  static const _kWelcome = 'enervara_welcome_seen';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    state = state.copyWith(loaded: true, welcomeSeen: prefs.getBool(_kWelcome) ?? false);
  }

  /// Mark the feature-tour as seen (so it never shows again on this install).
  Future<void> markWelcomeSeen() async {
    state = state.copyWith(welcomeSeen: true);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kWelcome, true);
  }
}
