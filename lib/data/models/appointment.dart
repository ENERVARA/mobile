// Appointments + the care bridge. Ported from `src/services/appointmentsService.ts`
// (which mirrors `backend/src/controllers/appointments.controller.ts`).

String? _s(dynamic v) {
  if (v == null) return null;
  final s = v.toString();
  return s.isEmpty ? null : s;
}

/// A bookable doctor. (Named `Clinician` — `Provider` collides with Riverpod.)
class Clinician {
  final String id;
  final String fullName;
  final String displayName;
  final String? specialitySlug;
  final String? specialityName;
  final List<String> qualifications;
  final String? registrationNumber;

  const Clinician({
    required this.id,
    required this.fullName,
    required this.displayName,
    this.specialitySlug,
    this.specialityName,
    this.qualifications = const [],
    this.registrationNumber,
  });

  factory Clinician.fromJson(Map<String, dynamic> j) => Clinician(
        id: (j['id'] ?? '').toString(),
        fullName: (j['fullName'] ?? j['displayName'] ?? '').toString(),
        displayName: (j['displayName'] ?? j['fullName'] ?? '').toString(),
        specialitySlug: _s(j['specialitySlug']),
        specialityName: _s(j['specialityName']),
        qualifications: j['qualifications'] is List
            ? (j['qualifications'] as List).map((e) => e.toString()).toList()
            : const [],
        registrationNumber: _s(j['registrationNumber']),
      );
}

class Slot {
  final String startsAt;
  final int durationMinutes;
  const Slot({required this.startsAt, required this.durationMinutes});

  factory Slot.fromJson(Map<String, dynamic> j) => Slot(
        startsAt: (j['startsAt'] ?? '').toString(),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
      );
}

class SlotDay {
  final String date;
  final List<Slot> slots;
  const SlotDay({required this.date, required this.slots});

  factory SlotDay.fromJson(Map<String, dynamic> j) => SlotDay(
        date: (j['date'] ?? '').toString(),
        slots: j['slots'] is List
            ? (j['slots'] as List)
                .whereType<Map>()
                .map((s) => Slot.fromJson(Map<String, dynamic>.from(s)))
                .toList()
            : const [],
      );
}

class AppointmentProviderRef {
  final String id;
  final String? displayName;
  final String? specialitySlug;
  final String? specialityName;
  const AppointmentProviderRef({
    required this.id,
    this.displayName,
    this.specialitySlug,
    this.specialityName,
  });

  factory AppointmentProviderRef.fromJson(Map<String, dynamic> j) => AppointmentProviderRef(
        id: (j['id'] ?? '').toString(),
        displayName: _s(j['displayName']),
        specialitySlug: _s(j['specialitySlug']),
        specialityName: _s(j['specialityName']),
      );
}

const kAppointmentStatusLabels = <String, String>{
  'REQUESTED': 'Requested',
  'CONFIRMED': 'Confirmed',
  'RESCHEDULED': 'Rescheduled',
  'CHECKED_IN': 'Checked in',
  'IN_CONSULTATION': 'In consultation',
  'COMPLETED': 'Completed',
  'CANCELLED': 'Cancelled',
  'NO_SHOW': 'Missed',
  'FOLLOW_UP_DUE': 'Follow-up due',
};

String appointmentStatusLabel(String status) => kAppointmentStatusLabels[status] ?? status;

/// States in which the patient can still change or cancel the appointment.
bool isAppointmentChangeable(String status) => status == 'REQUESTED' || status == 'CONFIRMED';

class Appointment {
  final String id;
  final String scheduledAt;
  final int durationMinutes;
  final String appointmentType;
  final String status;
  final String entrySource; // DIRECT_BOOKING | AI_GUIDED | PROVIDER_CREATED | WALK_IN
  final String? reason;
  final String? specialitySlug;
  final String? careJourneyId;
  final String? originatingConsultationId;
  final String? rescheduledFromId;
  final String? cancellationReason;

  /// Every appointment today is an in-person consultation, so this defaults to
  /// `offline` when the backend omits it.
  final String mode; // agent | offline
  final AppointmentProviderRef provider;

  const Appointment({
    required this.id,
    required this.scheduledAt,
    required this.durationMinutes,
    required this.appointmentType,
    required this.status,
    required this.entrySource,
    required this.provider,
    this.reason,
    this.specialitySlug,
    this.careJourneyId,
    this.originatingConsultationId,
    this.rescheduledFromId,
    this.cancellationReason,
    this.mode = 'offline',
  });

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: (j['id'] ?? '').toString(),
        scheduledAt: (j['scheduledAt'] ?? '').toString(),
        durationMinutes: (j['durationMinutes'] as num?)?.toInt() ?? 0,
        appointmentType: (j['appointmentType'] ?? 'Appointment').toString(),
        status: (j['status'] ?? 'REQUESTED').toString(),
        entrySource: (j['entrySource'] ?? 'DIRECT_BOOKING').toString(),
        reason: _s(j['reason']),
        specialitySlug: _s(j['specialitySlug']),
        careJourneyId: _s(j['careJourneyId']),
        originatingConsultationId: _s(j['originatingConsultationId']),
        rescheduledFromId: _s(j['rescheduledFromId']),
        cancellationReason: _s(j['cancellationReason']),
        mode: j['mode'] == 'agent' ? 'agent' : 'offline',
        provider: j['provider'] is Map
            ? AppointmentProviderRef.fromJson(Map<String, dynamic>.from(j['provider'] as Map))
            : const AppointmentProviderRef(id: ''),
      );
}

const kContextKindLabels = <String, String>{
  'CURRENT_CONCERN': 'Why you are coming in',
  'PATIENT_HISTORY': 'Your health profile',
  'PREVIOUS_CONSULTATION': 'Previous consultation',
  'REPORT': 'Report',
  'PRESCRIPTION': 'Prescription',
  'AI_CONTEXT': 'AI conversation',
};

/// A pointer plus a decision — never the content itself.
class ContextItem {
  final String id;
  final String kind;
  final String label;
  final String? resourceType;
  final String? resourceId;
  final String shareStatus; // PROPOSED | AUTHORIZED | DECLINED | REVOKED
  final String? decidedAt;

  const ContextItem({
    required this.id,
    required this.kind,
    required this.label,
    required this.shareStatus,
    this.resourceType,
    this.resourceId,
    this.decidedAt,
  });

  factory ContextItem.fromJson(Map<String, dynamic> j) => ContextItem(
        id: (j['id'] ?? '').toString(),
        kind: (j['kind'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        resourceType: _s(j['resourceType']),
        resourceId: _s(j['resourceId']),
        shareStatus: (j['shareStatus'] ?? 'PROPOSED').toString(),
        decidedAt: _s(j['decidedAt']),
      );
}

class StatusEvent {
  final String? from;
  final String to;
  final String? reason;
  final String occurredAt;
  const StatusEvent({this.from, required this.to, this.reason, required this.occurredAt});

  factory StatusEvent.fromJson(Map<String, dynamic> j) => StatusEvent(
        from: _s(j['from']),
        to: (j['to'] ?? '').toString(),
        reason: _s(j['reason']),
        occurredAt: (j['occurredAt'] ?? '').toString(),
      );
}

class FollowUp {
  final String id;
  final String careJourneyId;
  final String? consultationId;
  final String kind; // APPOINTMENT | INVESTIGATION | MONITORING | REVIEW
  final String? note;
  final String? dueOn;
  final String status; // OPEN | SCHEDULED | COMPLETED | CANCELLED
  final String? scheduledAppointmentId;

  const FollowUp({
    required this.id,
    required this.careJourneyId,
    required this.kind,
    required this.status,
    this.consultationId,
    this.note,
    this.dueOn,
    this.scheduledAppointmentId,
  });

  factory FollowUp.fromJson(Map<String, dynamic> j) => FollowUp(
        id: (j['id'] ?? '').toString(),
        careJourneyId: (j['careJourneyId'] ?? '').toString(),
        consultationId: _s(j['consultationId']),
        kind: (j['kind'] ?? 'MONITORING').toString(),
        note: _s(j['note']),
        dueOn: _s(j['dueOn']),
        status: (j['status'] ?? 'OPEN').toString(),
        scheduledAppointmentId: _s(j['scheduledAppointmentId']),
      );
}

class AppointmentsList {
  final List<Appointment> upcoming;
  final List<Appointment> past;
  const AppointmentsList({this.upcoming = const [], this.past = const []});
}

class AppointmentDetail {
  final Appointment appointment;
  final List<ContextItem> context;
  final List<StatusEvent> history;
  const AppointmentDetail({
    required this.appointment,
    this.context = const [],
    this.history = const [],
  });
}
