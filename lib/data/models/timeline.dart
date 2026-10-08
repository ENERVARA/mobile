import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/accent.dart';
import '../constants/specialities.dart';
import 'appointment.dart';
import 'chat.dart';
import 'lab_report.dart';
import 'prescription.dart';
import 'report.dart';

/// One dated health event. The timeline answers "what has happened in my
/// health?", so it only carries things that happened: verified extractions,
/// uploaded documents, consultations and completed appointments. Extractions
/// still awaiting the patient's review are deliberately absent — unconfirmed OCR
/// output is not medical history. Ported from `features/healthRecords/timeline.ts`.
enum TimelineKind { consultation, appointment, lab, prescription, document }

class TimelineEvent {
  final String id;
  final TimelineKind kind;

  /// ISO date the event applies to.
  final String date;
  final String title;
  final String? detail;

  /// In-app route for the event, when it has its own screen.
  final String? to;

  /// Set for consultations, which re-open in Nova rather than a route.
  final ({String id, String specialitySlug})? conversation;

  const TimelineEvent({
    required this.id,
    required this.kind,
    required this.date,
    required this.title,
    this.detail,
    this.to,
    this.conversation,
  });
}

class TimelineSources {
  final List<ChatConversation> conversations;
  final List<LabReportListItem> labReports;
  final List<PrescriptionListItem> prescriptions;
  final List<Report> documents;
  final List<Appointment> appointments;
  const TimelineSources({
    this.conversations = const [],
    this.labReports = const [],
    this.prescriptions = const [],
    this.documents = const [],
    this.appointments = const [],
  });
}

class KindVisual {
  final IconData icon;
  final Accent accent;
  final String label;
  const KindVisual(this.icon, this.accent, this.label);
}

const kTimelineKindVisuals = <TimelineKind, KindVisual>{
  TimelineKind.consultation: KindVisual(PhosphorIconsFill.stethoscope, Accent.teal, 'Consultation'),
  TimelineKind.appointment: KindVisual(PhosphorIconsFill.calendarCheck, Accent.teal, 'Appointment'),
  TimelineKind.lab: KindVisual(PhosphorIconsFill.flask, Accent.cyan, 'Lab report'),
  TimelineKind.prescription: KindVisual(PhosphorIconsFill.prescription, Accent.lav, 'Prescription'),
  TimelineKind.document: KindVisual(PhosphorIconsFill.fileText, Accent.amber, 'Document'),
};

/// Icon + accent for a stored document by mime type (`documentIcon`).
({IconData icon, Accent accent}) documentIconFor(String mimeType) {
  if (mimeType == 'application/pdf') return (icon: PhosphorIconsFill.filePdf, accent: Accent.coral);
  if (mimeType.startsWith('image/')) return (icon: PhosphorIconsFill.image, accent: Accent.teal);
  return (icon: PhosphorIconsFill.file, accent: Accent.lav);
}

const _documentTitles = <String, String>{
  'Lab results': 'Lab document',
  'Imaging': 'Scan',
  'Prescriptions': 'Prescription document',
  'Visits': 'Visit document',
};

String _plural(int count, String word) => '$count $word${count == 1 ? '' : 's'}';

String? _specialityDisplay(String? slug) {
  if (slug == null) return null;
  return specialityBySlug(slug)?.name ?? slug;
}

List<TimelineEvent> buildTimeline(TimelineSources s) {
  final events = <TimelineEvent>[];

  for (final c in s.conversations) {
    // The complaint ("Cold", "Chest pain on exertion") is what the patient
    // actually wants to see here — not which speciality handled it. Falls back
    // to the conversation's own title when the backend hasn't reported a
    // complaint summary yet. No destination: a complaint line is read-only
    // history, not a reopenable thread.
    final complaint = (c.complaintSummary != null && c.complaintSummary!.isNotEmpty)
        ? c.complaintSummary!
        : (c.title.isNotEmpty ? c.title : 'Consultation');
    events.add(TimelineEvent(
      id: 'consultation-${c.id}',
      kind: TimelineKind.consultation,
      date: c.lastMessageAt,
      title: complaint,
    ));
  }

  for (final a in s.appointments) {
    if (a.status != 'COMPLETED') continue;
    final who = (a.provider.displayName != null) ? 'Dr ${a.provider.displayName}' : null;
    events.add(TimelineEvent(
      id: 'appointment-${a.id}',
      kind: TimelineKind.appointment,
      date: a.scheduledAt,
      title:
          'Appointment — ${a.provider.specialityName ?? _specialityDisplay(a.specialitySlug) ?? a.appointmentType}',
      detail: who,
      to: '/care/${a.id}',
    ));
  }

  for (final r in s.labReports) {
    if (r.status != 'SAVED') continue;
    events.add(TimelineEvent(
      id: 'lab-${r.id}',
      kind: TimelineKind.lab,
      date: r.effectiveDate,
      title: 'Lab report — ${labReportTypeLabel(r.reportType)}',
      detail: '${_plural(r.summary.markerCount, 'parameter')} identified',
      to: '/lab-reports/${r.id}',
    ));
  }

  for (final p in s.prescriptions) {
    if (p.status != 'SAVED') continue;
    final detail = [p.prescriberName, p.clinicName].where((x) => x != null && x.isNotEmpty).join(' · ');
    events.add(TimelineEvent(
      id: 'prescription-${p.id}',
      kind: TimelineKind.prescription,
      date: p.effectiveDate,
      title: 'Prescription — ${_plural(p.summary.medicationCount, 'medicine')}',
      detail: detail.isEmpty ? null : detail,
      to: '/prescriptions/${p.id}',
    ));
  }

  for (final d in s.documents) {
    events.add(TimelineEvent(
      id: 'document-${d.id}',
      kind: TimelineKind.document,
      date: d.createdAt,
      title: _documentTitles[d.category] ?? 'Document',
      detail: d.fileName,
      to: '/reports/${d.id}',
    ));
  }

  events.sort((a, b) => b.date.compareTo(a.date));
  return events;
}
