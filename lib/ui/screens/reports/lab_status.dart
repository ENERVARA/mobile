import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/accent.dart';

/// Presentation for lab statuses — one place, so no screen invents its own label
/// or colour. Ported from `features/reports/components/labStatus.ts`.
///
/// WORDING RULE: these strings describe the DOCUMENT, never the patient. A marker
/// outside its range is "Above range" / "Needs review", never "abnormal", "high
/// risk" or anything a reader could take as a diagnosis. The reference range
/// shown is the one printed on the uploaded report, and the UI always points back
/// to the original document.
class ResultStatusMeta {
  final String label;

  /// Longer phrasing for the detail view.
  final String description;
  final Accent accent;
  final IconData icon;
  const ResultStatusMeta(this.label, this.description, this.accent, this.icon);
}

const kResultStatusMeta = <String, ResultStatusMeta>{
  'NORMAL': ResultStatusMeta(
    'In range',
    'Within the reference range printed on the report',
    Accent.teal,
    PhosphorIconsBold.checkCircle,
  ),
  'HIGH': ResultStatusMeta(
    'Above range',
    'Above the reference range printed on the report',
    Accent.coral,
    PhosphorIconsBold.arrowUpRight,
  ),
  'LOW': ResultStatusMeta(
    'Below range',
    'Below the reference range printed on the report',
    Accent.cyan,
    PhosphorIconsBold.arrowDownRight,
  ),
  'REVIEW': ResultStatusMeta(
    'Needs review',
    'We could not compare this value — check it against the original report',
    Accent.amber,
    PhosphorIconsBold.question,
  ),
};

class ReportStatusMeta {
  final String label;
  final Accent accent;
  final IconData icon;
  const ReportStatusMeta(this.label, this.accent, this.icon);
}

const kReportStatusMeta = <String, ReportStatusMeta>{
  'PROCESSING': ReportStatusMeta('Processing', Accent.lav, PhosphorIconsRegular.circleNotch),
  'READY_FOR_REVIEW': ReportStatusMeta('Ready for review', Accent.amber, PhosphorIconsRegular.eye),
  'SAVED': ReportStatusMeta('Saved', Accent.teal, PhosphorIconsRegular.checkCircle),
  'FAILED': ReportStatusMeta('Needs attention', Accent.coral, PhosphorIconsRegular.warningCircle),
};
