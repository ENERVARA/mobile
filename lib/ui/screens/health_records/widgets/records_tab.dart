import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/accent.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../data/models/lab_report.dart';
import '../../../../data/models/prescription.dart';
import '../../../../data/models/timeline.dart';
import '../../../../state/lab_reports_provider.dart';
import '../../../../state/prescriptions_provider.dart';
import '../../../../state/reports_provider.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';
import '../add_to_my_health_flow.dart';
import 'documents_list.dart';
import 'lab_results_tab.dart';
import 'prescriptions_tab.dart';

enum _View { all, lab, prescriptions, documents }

const _views = <(_View, String)>[
  (_View.all, 'All'),
  (_View.lab, 'Lab reports'),
  (_View.prescriptions, 'Prescriptions'),
  (_View.documents, 'Documents'),
];

const _pendingLabel = <String, String>{
  'PROCESSING': 'Processing',
  'READY_FOR_REVIEW': 'Ready for your review',
  'FAILED': 'Needs attention',
};

class _RecordRow {
  final String id;
  final String title;
  final String subtitle;
  final String date;
  final IconData icon;
  final Accent accent;

  /// Shown only while a record is not yet part of the verified history.
  final String? pending;
  final String to;
  const _RecordRow({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.date,
    required this.icon,
    required this.accent,
    required this.pending,
    required this.to,
  });
}

/// "Where is my specific document?" — the document-management layer. Ported from
/// `RecordsTab.tsx`.
class RecordsTab extends StatefulWidget {
  const RecordsTab({super.key});

  @override
  State<RecordsTab> createState() => _RecordsTabState();
}

class _RecordsTabState extends State<RecordsTab> {
  _View _view = _View.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final (v, label) in _views)
                RoundedChip(label: label, selected: _view == v, onTap: () => setState(() => _view = v)),
            ],
          ),
        ),
        switch (_view) {
          _View.all => const _AllRecords(),
          _View.lab => LabResultsTab(onScanNew: () => showAddToMyHealthFlow(context)),
          _View.prescriptions => PrescriptionsTab(onScanNew: () => showAddToMyHealthFlow(context)),
          _View.documents => DocumentsList(onAdd: () => showAddToMyHealthFlow(context)),
        },
      ],
    );
  }
}

/// Every record in one searchable list — "where is my specific document?"
class _AllRecords extends ConsumerStatefulWidget {
  const _AllRecords();

  @override
  ConsumerState<_AllRecords> createState() => _AllRecordsState();
}

class _AllRecordsState extends ConsumerState<_AllRecords> {
  List<LabReportListItem>? _lab;
  List<PrescriptionListItem>? _prescriptions;
  String _search = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      ref.read(reportsProvider.notifier).load();
      ref
          .read(labReportsServiceProvider)
          .listReports(sort: 'DATE_DESC')
          .then((v) => mounted ? setState(() => _lab = v) : null)
          .catchError((_) => mounted ? setState(() => _lab = const []) : null);
      ref
          .read(prescriptionsServiceProvider)
          .listPrescriptions(sort: 'DATE_DESC')
          .then((v) => mounted ? setState(() => _prescriptions = v) : null)
          .catchError((_) => mounted ? setState(() => _prescriptions = const []) : null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final documents = ref.watch(reportsProvider).reports;
    final loading = _lab == null || _prescriptions == null;

    final all = <_RecordRow>[
      for (final r in _lab ?? const <LabReportListItem>[])
        _RecordRow(
          id: 'lab-${r.id}',
          title: labReportTypeLabel(r.reportType),
          subtitle: 'Lab report · ${r.summary.markerCount} parameters · ${r.originalFileName}',
          date: r.effectiveDate,
          icon: PhosphorIconsFill.flask,
          accent: Accent.cyan,
          pending: _pendingLabel[r.status],
          to: '/lab-reports/${r.id}',
        ),
      for (final p in _prescriptions ?? const <PrescriptionListItem>[])
        _RecordRow(
          id: 'rx-${p.id}',
          title: (p.prescriberName != null && p.prescriberName!.isNotEmpty)
              ? 'Prescription — ${p.prescriberName}'
              : 'Prescription',
          subtitle: '${p.summary.medicationCount} medicines · ${p.clinicName ?? p.originalFileName}',
          date: p.effectiveDate,
          icon: PhosphorIconsFill.prescription,
          accent: Accent.lav,
          pending: _pendingLabel[p.status],
          to: '/prescriptions/${p.id}',
        ),
      for (final d in documents)
        () {
          final v = documentIconFor(d.mimeType);
          return _RecordRow(
            id: 'doc-${d.id}',
            title: d.fileName,
            subtitle: d.category,
            date: d.createdAt,
            icon: v.icon,
            accent: v.accent,
            pending: null,
            to: '/reports/${d.id}',
          );
        }(),
    ];

    final q = _search.trim().toLowerCase();
    final rows = all
        .where((r) => q.isEmpty || '${r.title} ${r.subtitle}'.toLowerCase().contains(q))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SearchField(
            hint: 'Search your records — a test, a doctor, a file name…',
            onChanged: (v) => setState(() => _search = v),
            radius: 12,
            borderWidth: 1,
            height: null,
            hPad: 14,
            vPad: 10,
            fontSize: 14.08,
          ),
        ),
        if (loading)
          Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                const Skeleton(height: 62, radius: 14),
              ],
            ],
          )
        else if (rows.isEmpty)
          DashedBox(
            radius: 16,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 48),
            child: Text(
              _search.isNotEmpty ? 'No records match your search.' : 'No records yet.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
            ),
          )
        else
          Column(
            children: [
              for (var i = 0; i < rows.length; i++) ...[
                if (i > 0) const SizedBox(height: 8),
                _RecordTile(row: rows[i]),
              ],
            ],
          ),
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final _RecordRow row;
  const _RecordTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push(row.to),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              AccentIconBox(icon: row.icon, accent: row.accent, size: 40, radius: 11, iconSize: 17.6),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      row.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.4,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Text(
                      row.subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                    ),
                  ],
                ),
              ),
              if (row.pending != null) ...[
                const SizedBox(width: 12),
                AccentPill(
                  label: row.pending!,
                  accent: Accent.amber,
                  fontSize: 11.52,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
