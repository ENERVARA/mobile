import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../state/health_records_provider.dart';
import '../../../state/reports_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import 'add_to_my_health_flow.dart';
import 'widgets/timeline_tab.dart';

/// "What has happened to me over time?" — every dated health event
/// (consultations, completed appointments, saved lab reports/prescriptions,
/// documents), across the user's whole record. Ported from
/// `HealthTimelinePage.tsx`: split out of Health Records into its own nav
/// destination — this is a history view; Health Records is "where is my specific
/// document?".
class HealthTimelinePage extends ConsumerStatefulWidget {
  const HealthTimelinePage({super.key});

  @override
  ConsumerState<HealthTimelinePage> createState() => _HealthTimelinePageState();
}

class _HealthTimelinePageState extends ConsumerState<HealthTimelinePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(healthRecordsProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final records = ref.watch(healthRecordsProvider);

    // A plain document finishes uploading after the add flow has closed; its
    // arrival in the documents provider is the cue to refresh the timeline.
    ref.listen(reportsProvider.select((s) => s.reports.length), (_, __) {
      ref.read(healthRecordsProvider.notifier).load();
    });

    return ShellPage(
      children: [
        const PageHeader(
          title: 'Health Timeline',
          subtitle: "Everything that's happened in your care, over time.",
        ),
        TimelineTab(
          events: records.events,
          isLoaded: records.isLoaded,
          onAdd: () => showAddToMyHealthFlow(context),
        ),
      ],
    );
  }
}
