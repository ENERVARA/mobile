import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/onboarding.dart';
import '../data/services/onboarding_service.dart';

final onboardingServiceProvider = Provider((ref) => const OnboardingService());

final onboardingProvider =
    StateNotifierProvider<OnboardingController, OnboardingUiState>(
        (ref) => OnboardingController(ref));

class OnboardingUiState {
  final OnboardingMe me;
  final bool isLoaded;
  final bool isLoading;
  final String? error;

  const OnboardingUiState({
    this.me = OnboardingMe.empty,
    this.isLoaded = false,
    this.isLoading = false,
    this.error,
  });

  OnboardingUiState copyWith({
    OnboardingMe? me,
    bool? isLoaded,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return OnboardingUiState(
      me: me ?? this.me,
      isLoaded: isLoaded ?? this.isLoaded,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class OnboardingController extends StateNotifier<OnboardingUiState> {
  OnboardingController(this._ref) : super(const OnboardingUiState());

  final Ref _ref;
  OnboardingService get _service => _ref.read(onboardingServiceProvider);

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final me = await _service.fetchMe();
      state = state.copyWith(me: me, isLoaded: true, isLoading: false);
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<OnboardingMe> submit(List<Map<String, dynamic>> answers) async {
    final me = await _service.submit(answers);
    state = state.copyWith(me: me, isLoaded: true);
    return me;
  }

  void clear() {
    state = const OnboardingUiState();
  }
}
