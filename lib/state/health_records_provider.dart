import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/appointment.dart';
import '../data/models/chat.dart';
import '../data/models/lab_report.dart';
import '../data/models/prescription.dart';
import '../data/models/report.dart';
import '../data/models/timeline.dart';
import 'appointments_provider.dart';
import 'chat_provider.dart';
import 'lab_reports_provider.dart';
import 'prescriptions_provider.dart';
import 'reports_provider.dart';

/// The patient's health timeline, shared by the Home preview and the Health
/// Timeline page so both always show the same events. Ported from
/// `healthRecordsStore.ts`.
///
/// Every source is fetched independently of the Records tab's own search and
/// filter state — the timeline is the whole record, never a filtered view.
/// Sources load independently: one unreachable service leaves a gap in the
/// timeline rather than blanking it. Not persisted.
final healthRecordsProvider =
    StateNotifierProvider<HealthRecordsController, HealthRecordsState>(
  (ref) => HealthRecordsController(ref),
);

class HealthRecordsState {
  final List<TimelineEvent> events;
  final bool isLoaded;
  final bool isLoading;
  const HealthRecordsState({this.events = const [], this.isLoaded = false, this.isLoading = false});

  HealthRecordsState copyWith({List<TimelineEvent>? events, bool? isLoaded, bool? isLoading}) =>
      HealthRecordsState(
        events: events ?? this.events,
        isLoaded: isLoaded ?? this.isLoaded,
        isLoading: isLoading ?? this.isLoading,
      );
}

class HealthRecordsController extends StateNotifier<HealthRecordsState> {
  HealthRecordsController(this._ref) : super(const HealthRecordsState());

  final Ref _ref;

  /// Guards against a stale load() overwriting a newer one's result.
  int _runToken = 0;

  Future<void> load() async {
    final token = ++_runToken;
    state = state.copyWith(isLoading: true);

    // Fire every source at once; each swallows its own failure.
    final conversations = _ref
        .read(chatServiceProvider)
        .listAll(limit: 50)
        .catchError((_) => <ChatConversation>[]);
    final labs = _ref
        .read(labReportsServiceProvider)
        .listReports(status: 'SAVED', sort: 'DATE_DESC')
        .catchError((_) => <LabReportListItem>[]);
    final prescriptions = _ref
        .read(prescriptionsServiceProvider)
        .listPrescriptions(status: 'SAVED', sort: 'DATE_DESC')
        .catchError((_) => <PrescriptionListItem>[]);
    final documents =
        _ref.read(reportsServiceProvider).list().catchError((_) => <Report>[]);
    final appointments = _ref
        .read(appointmentsServiceProvider)
        .listMine()
        .then((r) => <Appointment>[...r.upcoming, ...r.past])
        .catchError((_) => <Appointment>[]);

    final sources = TimelineSources(
      conversations: await conversations,
      labReports: await labs,
      prescriptions: await prescriptions,
      documents: await documents,
      appointments: await appointments,
    );
    if (token != _runToken || !mounted) return;

    state = state.copyWith(events: buildTimeline(sources), isLoaded: true, isLoading: false);
  }
}
