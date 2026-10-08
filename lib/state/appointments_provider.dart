import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/appointment.dart';
import '../data/services/appointments_service.dart';

final appointmentsServiceProvider = Provider((ref) => const AppointmentsService());

/// The doctors a patient can actually book (`useProviders`). Reads
/// `/api/v1/appointments/providers`, which lists real clinicians from the
/// database. There is no demo list behind this: if it comes back empty, no
/// doctor has been onboarded yet, and the UI says exactly that.
///
/// `AsyncValue` distinguishes "loading", "ready" and "error" — an error is a
/// system fault worth a retry, an empty list is just an empty directory.
final cliniciansProvider = FutureProvider.autoDispose<List<Clinician>>((ref) {
  return ref.read(appointmentsServiceProvider).listProviders();
});
