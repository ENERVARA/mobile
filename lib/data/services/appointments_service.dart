import '../../core/api/api_client.dart';
import '../models/appointment.dart';

/// Appointments and the care bridge (`/api/v1/appointments/*`). Ported from
/// `appointmentsService.ts`. Nothing here calls or waits on an AI service:
/// booking a doctor is reachable from the very first screen, and an AI
/// conversation only ever appears as one more piece of context the patient may
/// choose to share.
class AppointmentsService {
  const AppointmentsService();

  static const _base = '/v1/appointments';

  Future<List<Clinician>> listProviders({String? speciality}) async {
    final res = await dio.get(
      '$_base/providers',
      queryParameters: speciality != null ? {'speciality': speciality} : null,
    );
    final list = (res.data is Map ? res.data['providers'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((p) => Clinician.fromJson(Map<String, dynamic>.from(p)))
        .toList();
  }

  Future<List<SlotDay>> listSlots(String doctorId, {int days = 14}) async {
    final res = await dio.get(
      '$_base/providers/$doctorId/slots',
      queryParameters: {'days': days},
    );
    final list = (res.data is Map ? res.data['days'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((d) => SlotDay.fromJson(Map<String, dynamic>.from(d)))
        .toList();
  }

  Future<Appointment> book({
    required String doctorId,
    required String scheduledAt,
    String? appointmentType,
    String? reason,
    String? specialitySlug,
    String? entrySource,
    String? conversationId,
    String? followUpRequestId,
    String? careJourneyId,
  }) async {
    final res = await dio.post(
      _base,
      data: {
        'doctorId': doctorId,
        'scheduledAt': scheduledAt,
        if (appointmentType != null) 'appointmentType': appointmentType,
        'reason': reason,
        'specialitySlug': specialitySlug,
        if (entrySource != null) 'entrySource': entrySource,
        'conversationId': conversationId,
        'followUpRequestId': followUpRequestId,
        'careJourneyId': careJourneyId,
      },
    );
    return Appointment.fromJson(
      Map<String, dynamic>.from((res.data as Map)['appointment'] as Map),
    );
  }

  Future<AppointmentsList> listMine() async {
    final res = await dio.get(_base);
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    List<Appointment> parse(dynamic v) => v is List
        ? v
            .whereType<Map>()
            .map((a) => Appointment.fromJson(Map<String, dynamic>.from(a)))
            .toList()
        : <Appointment>[];
    return AppointmentsList(upcoming: parse(data['upcoming']), past: parse(data['past']));
  }

  Future<AppointmentDetail> get(String id) async {
    final res = await dio.get('$_base/$id');
    final data = Map<String, dynamic>.from(res.data as Map);
    return AppointmentDetail(
      appointment: Appointment.fromJson(Map<String, dynamic>.from(data['appointment'] as Map)),
      context: data['context'] is List
          ? (data['context'] as List)
              .whereType<Map>()
              .map((c) => ContextItem.fromJson(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
      history: data['history'] is List
          ? (data['history'] as List)
              .whereType<Map>()
              .map((h) => StatusEvent.fromJson(Map<String, dynamic>.from(h)))
              .toList()
          : const [],
    );
  }

  Future<Appointment> cancel(String id, {String? reason}) async {
    final res = await dio.post('$_base/$id/cancel', data: {'reason': reason});
    return Appointment.fromJson(
      Map<String, dynamic>.from((res.data as Map)['appointment'] as Map),
    );
  }

  Future<ContextItem> decideContext(String appointmentId, String itemId, String decision) async {
    final res = await dio.post(
      '$_base/$appointmentId/context/$itemId',
      data: {'decision': decision},
    );
    return ContextItem.fromJson(Map<String, dynamic>.from((res.data as Map)['item'] as Map));
  }

  Future<List<ContextItem>> decideAllContext(String appointmentId, String decision) async {
    final res = await dio.post(
      '$_base/$appointmentId/context/decide-all',
      data: {'decision': decision},
    );
    final list = (res.data as Map)['context'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((c) => ContextItem.fromJson(Map<String, dynamic>.from(c)))
        .toList();
  }

  Future<List<FollowUp>> listFollowUps() async {
    final res = await dio.get('$_base/follow-ups');
    final list = (res.data is Map ? res.data['followUps'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((f) => FollowUp.fromJson(Map<String, dynamic>.from(f)))
        .toList();
  }
}
