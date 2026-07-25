import 'package:flutter/material.dart';

import '../../../../core/theme/context_ext.dart';
import '../../../widgets/app_button.dart';

/// Shared bottom-sheet chrome for the health-profile form sheets:
/// grabber → title → scrollable body → Save action.
class FormSheet extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final String saveLabel;
  final bool saving;
  final VoidCallback? onSave;

  const FormSheet({
    super.key,
    required this.title,
    required this.children,
    required this.onSave,
    this.saveLabel = 'Save',
    this.saving = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: t.line, borderRadius: BorderRadius.circular(999)),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: t.ink),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 20, color: t.ink3),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: children),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.viewPaddingOf(context).bottom),
              child: AppButton(
                label: saveLabel,
                height: 46,
                loading: saving,
                onPressed: onSave,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Multi-select chip row used by the reaction-type / time-of-day pickers.
class ChipMultiSelect extends StatelessWidget {
  final List<String> options;
  final Set<String> selected;
  final ValueChanged<String> onToggle;
  final String Function(String)? labelOf;

  const ChipMultiSelect({
    super.key,
    required this.options,
    required this.selected,
    required this.onToggle,
    this.labelOf,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final o in options)
          GestureDetector(
            onTap: () => onToggle(o),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: selected.contains(o) ? t.ink : t.soft,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: selected.contains(o) ? t.ink : t.line),
              ),
              child: Text(
                labelOf?.call(o) ?? o,
                style: TextStyle(
                  fontSize: 12.8,
                  fontWeight: FontWeight.w500,
                  color: selected.contains(o) ? t.card : t.ink2,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Section header + spacing used inside the form sheets.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
            color: context.tokens.ink2,
          ),
        ),
      );
}
