import '../../core/api/api_client.dart';
import '../models/health_profile.dart';

/// Health-profile endpoints (`/api/health-profile/*`). Create/update patches
/// are passed as maps built by the UI, matching the flexible merge semantics.
class HealthProfileService {
  const HealthProfileService();

  Future<HealthProfileOverview> fetchOverview() async {
    final res = await dio.get('/health-profile/overview');
    return HealthProfileOverview.fromJson(_map(res.data));
  }

  // ── Lifestyle ──
  Future<Lifestyle> fetchLifestyle() async {
    final res = await dio.get('/health-profile/lifestyle');
    return Lifestyle.fromJson(_map(res.data));
  }

  Future<Lifestyle> saveLifestyle(Map<String, dynamic> patch) async {
    final res = await dio.put('/health-profile/lifestyle', data: patch);
    return Lifestyle.fromJson(_map(res.data));
  }

  // ── Wellbeing ──
  Future<Wellbeing> fetchWellbeing() async {
    final res = await dio.get('/health-profile/wellbeing');
    return Wellbeing.fromJson(_map(res.data));
  }

  Future<Wellbeing> saveWellbeing(Map<String, dynamic> patch) async {
    final res = await dio.put('/health-profile/wellbeing', data: patch);
    return Wellbeing.fromJson(_map(res.data));
  }

  // ── Allergies ──
  Future<AllergiesResponse> fetchAllergies() async {
    final res = await dio.get('/health-profile/allergies');
    return AllergiesResponse.fromJson(_map(res.data));
  }

  Future<Allergy> createAllergy(Map<String, dynamic> input) async {
    final res = await dio.post('/health-profile/allergies', data: input);
    return Allergy.fromJson(_map(res.data));
  }

  Future<Allergy> updateAllergy(String id, Map<String, dynamic> patch) async {
    final res = await dio.patch('/health-profile/allergies/$id', data: patch);
    return Allergy.fromJson(_map(res.data));
  }

  Future<void> deleteAllergy(String id) async {
    await dio.delete('/health-profile/allergies/$id');
  }

  Future<String> confirmNoAllergies() async {
    final res = await dio.post('/health-profile/allergies/confirm-none');
    return (res.data?['confirmedAt'] ?? '') as String;
  }

  // ── Medications ──
  Future<List<Medication>> fetchMedications() async {
    final res = await dio.get('/health-profile/medications');
    return _list(res.data, Medication.fromJson);
  }

  Future<Medication> createMedication(Map<String, dynamic> input) async {
    final res = await dio.post('/health-profile/medications', data: input);
    return Medication.fromJson(_map(res.data));
  }

  Future<Medication> updateMedication(String id, Map<String, dynamic> patch) async {
    final res = await dio.patch('/health-profile/medications/$id', data: patch);
    return Medication.fromJson(_map(res.data));
  }

  Future<void> deleteMedication(String id) async {
    await dio.delete('/health-profile/medications/$id');
  }

  // ── Conditions ──
  Future<ConditionCatalog> fetchConditionsCatalog() async {
    final res = await dio.get('/health-profile/conditions/catalog');
    final map = _map(res.data);
    final out = <String, List<ConditionCatalogEntry>>{};
    map.forEach((category, entries) {
      if (entries is List) {
        out[category] = entries
            .whereType<Map>()
            .map((e) => ConditionCatalogEntry.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      }
    });
    return out;
  }

  Future<ConditionsResponse> fetchConditions() async {
    final res = await dio.get('/health-profile/conditions');
    return ConditionsResponse.fromJson(_map(res.data));
  }

  Future<Condition> createCondition(Map<String, dynamic> input) async {
    final res = await dio.post('/health-profile/conditions', data: input);
    return Condition.fromJson(_map(res.data));
  }

  Future<Condition> updateCondition(String id, Map<String, dynamic> patch) async {
    final res = await dio.patch('/health-profile/conditions/$id', data: patch);
    return Condition.fromJson(_map(res.data));
  }

  Future<void> deleteCondition(String id) async {
    await dio.delete('/health-profile/conditions/$id');
  }

  Future<String> confirmNoConditions() async {
    final res = await dio.post('/health-profile/conditions/confirm-none');
    return (res.data?['confirmedAt'] ?? '') as String;
  }

  // ── Surgeries ──
  Future<List<Surgery>> fetchSurgeries() async {
    final res = await dio.get('/health-profile/surgeries');
    return _list(res.data, Surgery.fromJson);
  }

  Future<Surgery> createSurgery(Map<String, dynamic> input) async {
    final res = await dio.post('/health-profile/surgeries', data: input);
    return Surgery.fromJson(_map(res.data));
  }

  Future<Surgery> updateSurgery(String id, Map<String, dynamic> patch) async {
    final res = await dio.patch('/health-profile/surgeries/$id', data: patch);
    return Surgery.fromJson(_map(res.data));
  }

  Future<void> deleteSurgery(String id) async {
    await dio.delete('/health-profile/surgeries/$id');
  }

  static Map<String, dynamic> _map(dynamic data) =>
      data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};

  static List<T> _list<T>(dynamic data, T Function(Map<String, dynamic>) fromJson) {
    if (data is! List) return const [];
    return data.whereType<Map>().map((e) => fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
