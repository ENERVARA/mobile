import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../widgets/common.dart';
import '../../widgets/page_header.dart';
import 'add_to_my_health_flow.dart';
import 'widgets/records_tab.dart';

/// "Where is my specific document?" — every lab report, prescription and
/// document in one searchable place, each with its own category view. Ported from
/// `HealthRecordsPage.tsx`. (Timeline and Insights were split into their own
/// destinations, so this page is Records on its own and needs no tab bar.)
class HealthRecordsPage extends StatelessWidget {
  const HealthRecordsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ShellPage(
      children: [
        PageHeader(
          title: 'Health Records',
          subtitle: 'Your lab reports, prescriptions and documents, all in one place.',
          action: WebButton(
            label: 'Add to My Health',
            icon: PhosphorIconsFill.plusCircle,
            shadow: true,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            onTap: () => showAddToMyHealthFlow(context),
          ),
        ),
        const RecordsTab(),
      ],
    );
  }
}
