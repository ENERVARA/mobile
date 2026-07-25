import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/health_profile.dart';
import '../data/services/health_profile_service.dart';

final healthProfileServiceProvider = Provider((ref) => const HealthProfileService());

final healthProfileProvider =
    StateNotifierProvider<HealthProfileController, HealthProfileState>(
        (ref) => HealthProfileController(ref));

class HealthProfileState {
  final bool isLoaded;
  final bool isLoading;
  final String? error;

  final HealthProfileOverview overview;
  final Lifestyle lifestyle;
  final Wellbeing wellbeing;
  final List<Allergy> allergies;
  final String? noKnownAllergiesConfirmedAt;
  final List<Medication> medications;
  final List<Condition> conditions;
  final String? noKnownConditionsConfirmedAt;
  final ConditionCatalog conditionsCatalog;
  final List<Surgery> surgeries;

  const HealthProfileState({
    this.isLoaded = false,
    this.isLoading = false,
    this.error,
    this.overview = HealthProfileOverview.empty,
    this.lifestyle = Lifestyle.empty,
    this.wellbeing = Wellbeing.empty,
    this.allergies = const [],
    this.noKnownAllergiesConfirmedAt,
    this.medications = const [],
    this.conditions = const [],
    this.noKnownConditionsConfirmedAt,
    this.conditionsCatalog = const {},
    this.surgeries = const [],
  });

  HealthProfileState copyWith({
    bool? isLoaded,
    bool? isLoading,
    String? error,
    HealthProfileOverview? overview,
    Lifestyle? lifestyle,
    Wellbeing? wellbeing,
    List<Allergy>? allergies,
    String? noKnownAllergiesConfirmedAt,
    List<Medication>? medications,
    List<Condition>? conditions,
    String? noKnownConditionsConfirmedAt,
    ConditionCatalog? conditionsCatalog,
    List<Surgery>? surgeries,
  }) {
    return HealthProfileState(
      isLoaded: isLoaded ?? this.isLoaded,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      overview: overview ?? this.overview,
      lifestyle: lifestyle ?? this.lifestyle,
      wellbeing: wellbeing ?? this.wellbeing,
      allergies: allergies ?? this.allergies,
      noKnownAllergiesConfirmedAt:
          noKnownAllergiesConfirmedAt ?? this.noKnownAllergiesConfirmedAt,
      medications: medications ?? this.medications,
      conditions: conditions ?? this.conditions,
      noKnownConditionsConfirmedAt:
          noKnownConditionsConfirmedAt ?? this.noKnownConditionsConfirmedAt,
      conditionsCatalog: conditionsCatalog ?? this.conditionsCatalog,
      surgeries: surgeries ?? this.surgeries,
    );
  }

  /// Sections complete out of 5 (Lifestyle, Allergies, Medications, Conditions,
  /// Wellbeing) — Basic Info is tracked separately on the Profile page.
  int get modulesComplete {
    var n = 0;
    if (overview.lifestyleDone) n++;
    if (overview.allergiesDone) n++;
    if (overview.medicationsDone) n++;
    if (overview.conditionsDone) n++;
    if (overview.wellbeingDone) n++;
    return n;
  }
}

class HealthProfileController extends StateNotifier<HealthProfileState> {
  HealthProfileController(this._ref) : super(const HealthProfileState());

  final Ref _ref;
  HealthProfileService get _s => _ref.read(healthProfileServiceProvider);

  Future<void> load() async {
    if (state.isLoading) return;
    state = state.copyWith(isLoading: true, error: null);
    try {
      final results = await Future.wait([
        _s.fetchOverview(),
        _s.fetchLifestyle(),
        _s.fetchWellbeing(),
        _s.fetchAllergies(),
        _s.fetchMedications(),
        _s.fetchConditions(),
        _s.fetchConditionsCatalog(),
        _s.fetchSurgeries(),
      ]);
      final allergiesRes = results[3] as AllergiesResponse;
      final conditionsRes = results[5] as ConditionsResponse;
      state = state.copyWith(
        overview: results[0] as HealthProfileOverview,
        lifestyle: results[1] as Lifestyle,
        wellbeing: results[2] as Wellbeing,
        allergies: allergiesRes.allergies,
        noKnownAllergiesConfirmedAt: allergiesRes.noKnownAllergiesConfirmedAt,
        medications: results[4] as List<Medication>,
        conditions: conditionsRes.conditions,
        noKnownConditionsConfirmedAt: conditionsRes.noKnownConditionsConfirmedAt,
        conditionsCatalog: results[6] as ConditionCatalog,
        surgeries: results[7] as List<Surgery>,
        isLoaded: true,
        isLoading: false,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString(), isLoading: false);
    }
  }

  Future<void> saveLifestyle(Map<String, dynamic> patch) async {
    final lifestyle = await _s.saveLifestyle(patch);
    state = state.copyWith(
        lifestyle: lifestyle, overview: state.overview.copyWith(lifestyleDone: true));
  }

  Future<void> saveWellbeing(Map<String, dynamic> patch) async {
    final wellbeing = await _s.saveWellbeing(patch);
    state = state.copyWith(
        wellbeing: wellbeing, overview: state.overview.copyWith(wellbeingDone: true));
  }

  // ── Allergies ──
  Future<void> addAllergy(Map<String, dynamic> input) async {
    final a = await _s.createAllergy(input);
    state = state.copyWith(
        allergies: [a, ...state.allergies], overview: state.overview.copyWith(allergiesDone: true));
  }

  Future<void> editAllergy(String id, Map<String, dynamic> patch) async {
    final a = await _s.updateAllergy(id, patch);
    state = state.copyWith(allergies: state.allergies.map((x) => x.id == id ? a : x).toList());
  }

  Future<void> removeAllergy(String id) async {
    await _s.deleteAllergy(id);
    state = state.copyWith(allergies: state.allergies.where((x) => x.id != id).toList());
  }

  Future<void> confirmNoAllergies() async {
    final at = await _s.confirmNoAllergies();
    state = state.copyWith(
        noKnownAllergiesConfirmedAt: at, overview: state.overview.copyWith(allergiesDone: true));
  }

  // ── Medications ──
  Future<void> addMedication(Map<String, dynamic> input) async {
    final m = await _s.createMedication(input);
    state = state.copyWith(
        medications: [m, ...state.medications],
        overview: state.overview.copyWith(medicationsDone: true));
  }

  Future<void> editMedication(String id, Map<String, dynamic> patch) async {
    final m = await _s.updateMedication(id, patch);
    state = state.copyWith(medications: state.medications.map((x) => x.id == id ? m : x).toList());
  }

  Future<void> removeMedication(String id) async {
    await _s.deleteMedication(id);
    state = state.copyWith(medications: state.medications.where((x) => x.id != id).toList());
  }

  // ── Conditions ──
  Future<void> addCondition(Map<String, dynamic> input) async {
    final c = await _s.createCondition(input);
    state = state.copyWith(
        conditions: [c, ...state.conditions],
        overview: state.overview.copyWith(conditionsDone: true));
  }

  Future<void> editCondition(String id, Map<String, dynamic> patch) async {
    final c = await _s.updateCondition(id, patch);
    state = state.copyWith(conditions: state.conditions.map((x) => x.id == id ? c : x).toList());
  }

  Future<void> removeCondition(String id) async {
    await _s.deleteCondition(id);
    state = state.copyWith(conditions: state.conditions.where((x) => x.id != id).toList());
  }

  Future<void> confirmNoConditions() async {
    final at = await _s.confirmNoConditions();
    state = state.copyWith(
        noKnownConditionsConfirmedAt: at, overview: state.overview.copyWith(conditionsDone: true));
  }

  // ── Surgeries ──
  Future<void> addSurgery(Map<String, dynamic> input) async {
    final s = await _s.createSurgery(input);
    state = state.copyWith(
        surgeries: [s, ...state.surgeries], overview: state.overview.copyWith(surgeriesDone: true));
  }

  Future<void> editSurgery(String id, Map<String, dynamic> patch) async {
    final s = await _s.updateSurgery(id, patch);
    state = state.copyWith(surgeries: state.surgeries.map((x) => x.id == id ? s : x).toList());
  }

  Future<void> removeSurgery(String id) async {
    await _s.deleteSurgery(id);
    state = state.copyWith(surgeries: state.surgeries.where((x) => x.id != id).toList());
  }
}
