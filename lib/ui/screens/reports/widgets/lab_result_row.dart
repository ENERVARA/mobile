import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/accent.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../data/models/lab_report.dart';
import '../../../widgets/common.dart';
import '../lab_status.dart';

/// One marker. Shared by the review screen and the report detail page so the two
/// can never drift apart in how a value or a flag is presented. Ported from
/// `LabResultRow.tsx` at mobile width (the status pill wraps to its own row).
class LabResultRow extends StatelessWidget {
  final LabResult result;
  final bool first;

  /// Review mode turns the value into an editable input.
  final bool editable;
  final void Function(String resultId, double? value)? onValueChange;

  const LabResultRow({
    super.key,
    required this.result,
    this.first = false,
    this.editable = false,
    this.onValueChange,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final meta = kResultStatusMeta[result.status] ?? kResultStatusMeta['REVIEW']!;
    final reference = formatLabReference(result);
    final lowConfidence = result.confidence != null && result.confidence! < 0.75;

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                result.testName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.72,
                  fontWeight: FontWeight.w600,
                  height: 1.5,
                  color: t.ink,
                ),
              ),
            ),
            if (result.source == 'MANUAL') ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
                child: Text(
                  'Edited',
                  style: TextStyle(fontSize: 10.88, fontWeight: FontWeight.w600, height: 1.5, color: t.ink3),
                ),
              ),
            ],
          ],
        ),
        if (reference != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Reference: $reference${(result.unit != null && result.unit!.isNotEmpty) ? ' ${result.unit}' : ''}',
              style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
            ),
          ),
        if (lowConfidence)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Low confidence reading — compare with the original report.',
              style: TextStyle(fontSize: 12, height: 1.5, color: t.ink3),
            ),
          ),
      ],
    );

    final value = SizedBox(
      width: 132,
      child: editable
          ? _ValueInput(result: result, onChanged: (v) => onValueChange?.call(result.id, v))
          : Text(
              formatLabResultValue(result),
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 15.2,
                fontWeight: FontWeight.w600,
                height: 1.5,
                color: t.ink,
              ),
            ),
    );

    final accent = meta.accent.style;
    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: accent.background, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(meta.icon, size: 13.6, color: accent.color),
          const SizedBox(width: 6),
          Text(
            meta.label,
            style: TextStyle(
              fontSize: 11.84,
              fontWeight: FontWeight.w600,
              height: 1.5,
              color: accent.color,
            ),
          ),
        ],
      ),
    );

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: info), const SizedBox(width: 8), value],
          ),
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerLeft, child: pill),
        ],
      ),
    );
  }
}

class _ValueInput extends StatefulWidget {
  final LabResult result;
  final ValueChanged<double?> onChanged;
  const _ValueInput({required this.result, required this.onChanged});

  @override
  State<_ValueInput> createState() => _ValueInputState();
}

class _ValueInputState extends State<_ValueInput> {
  late final TextEditingController _c = TextEditingController(
    text: widget.result.value == null ? '' : _fmt(widget.result.value!),
  );
  final _focus = FocusNode();
  bool _focused = false;

  static String _fmt(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toString();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _focused ? AppColors.teal : t.line, width: 1.5),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        textAlign: TextAlign.right,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]'))],
        onChanged: (raw) => widget.onChanged(raw.isEmpty ? null : double.tryParse(raw)),
        style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: '—',
          hintStyle: TextStyle(color: t.ink3),
        ),
      ),
    );
  }
}

/// Small pill used on list cards / detail headers for a report's status.
class ReportStatusPill extends StatelessWidget {
  final String status;
  final double fontSize;
  const ReportStatusPill({super.key, required this.status, this.fontSize = 11.2});

  @override
  Widget build(BuildContext context) {
    final meta = kReportStatusMeta[status] ?? kReportStatusMeta['PROCESSING']!;
    return AccentPill(label: meta.label, accent: meta.accent, fontSize: fontSize);
  }
}
