import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../data/models/prescription.dart';

/// Pill for a medication's read status. Wording describes the SCAN, never the
/// medicine. Ported from `MedicationCard.tsx` / `medicationStatus.ts`.
class ReadStatusPill extends StatelessWidget {
  final String status;
  const ReadStatusPill({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final copy = kReadStatusCopy[status] ?? kReadStatusCopy['NEEDS_REVIEW']!;
    late final Color bg;
    late final Color fg;
    switch (copy.tone) {
      case 'amber':
        bg = const Color(0x24D69E2E);
        fg = dark ? const Color(0xFFE0AC55) : const Color(0xFF8A6118);
        break;
      case 'coral':
        bg = const Color(0x1FF26440);
        fg = dark ? const Color(0xFFFF8968) : const Color(0xFFC1441F);
        break;
      default:
        bg = t.soft;
        fg = t.ink3;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(
        copy.label,
        style: TextStyle(fontSize: 10.88, fontWeight: FontWeight.w600, height: 1.5, color: fg),
      ),
    );
  }
}

class MedicationCard extends StatelessWidget {
  final Medication medication;

  /// Read-only display (detail page) vs. editable review.
  final bool editable;
  final void Function(Medication Function(Medication))? onEdit;

  const MedicationCard({super.key, required this.medication, this.editable = false, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final m = medication;
    final parts = m.scheduleParts;
    final needsAttention = m.readStatus != 'CLEAR';
    final copy = kReadStatusCopy[m.readStatus] ?? kReadStatusCopy['NEEDS_REVIEW']!;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: needsAttention ? const Color(0x59F26440) : t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(10)),
                child: Icon(PhosphorIconsFill.pill, size: 16, color: t.ink2),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (editable)
                      _MiniInput(
                        initial: m.name,
                        fontSize: 15.2,
                        fontWeight: FontWeight.w600,
                        onChanged: (v) => onEdit?.call((x) => x.edit(name: v)),
                      )
                    else
                      Text(
                        m.name,
                        style: TextStyle(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                    if (m.genericName != null && m.genericName != m.name)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          m.genericName!,
                          style: TextStyle(fontSize: 12.16, height: 1.5, color: t.ink3),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              ReadStatusPill(status: m.readStatus),
            ],
          ),
          const SizedBox(height: 8),
          if (editable)
            LayoutBuilder(
              builder: (context, c) {
                final w = (c.maxWidth - 8) / 2;
                Widget field(String label, String hint, String? initial, void Function(String?) set) =>
                    SizedBox(
                      width: w,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10.88,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6528,
                              height: 1.5,
                              color: t.ink3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          _MiniInput(
                            initial: initial ?? '',
                            hint: hint,
                            fontSize: 13.12,
                            onChanged: (v) => set(v.isEmpty ? null : v),
                          ),
                        ],
                      ),
                    );
                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    field('Dosage', 'e.g. 1 tablet', m.dosage,
                        (v) => onEdit?.call((x) => x.edit(setDosage: true, dosage: v))),
                    field('How often', 'e.g. Twice daily', m.frequency,
                        (v) => onEdit?.call((x) => x.edit(setFrequency: true, frequency: v))),
                    field('When', 'e.g. After food', m.timing,
                        (v) => onEdit?.call((x) => x.edit(setTiming: true, timing: v))),
                    field('For how long', 'e.g. 5 days', m.durationText,
                        (v) => onEdit?.call((x) => x.edit(setDuration: true, durationText: v))),
                  ],
                );
              },
            )
          else if (parts.isNotEmpty)
            Text(
              parts.join(' · '),
              style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink2),
            ),
          if (m.instructions != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Icon(PhosphorIconsRegular.info, size: 14, color: t.ink3),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      m.instructions!,
                      style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink2),
                    ),
                  ),
                ],
              ),
            ),
          if (m.commonUse != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(10)),
              child: Text(
                m.commonUse!,
                style: TextStyle(fontSize: 12.16, height: 1.625, color: t.ink2),
              ),
            ),
          if (needsAttention)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                copy.hint,
                style: TextStyle(fontSize: 11.84, height: 1.375, color: t.ink3),
              ),
            ),
        ],
      ),
    );
  }
}

/// `rounded-[8px] border border-line bg-card px-2 py-1` text input used by the
/// editable medication card (focus → teal border).
class _MiniInput extends StatefulWidget {
  final String initial;
  final String? hint;
  final double fontSize;
  final FontWeight fontWeight;
  final ValueChanged<String> onChanged;
  const _MiniInput({
    required this.initial,
    required this.onChanged,
    this.hint,
    this.fontSize = 13,
    this.fontWeight = FontWeight.w400,
  });

  @override
  State<_MiniInput> createState() => _MiniInputState();
}

class _MiniInputState extends State<_MiniInput> {
  late final TextEditingController _c = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  bool _focused = false;

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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _focused ? AppColors.teal : t.line),
      ),
      child: TextField(
        controller: _c,
        focusNode: _focus,
        onChanged: widget.onChanged,
        style: TextStyle(fontSize: widget.fontSize, fontWeight: widget.fontWeight, color: t.ink),
        decoration: InputDecoration(
          isCollapsed: true,
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          filled: false,
          hintText: widget.hint,
          hintStyle: TextStyle(fontSize: widget.fontSize, color: t.ink3),
        ),
      ),
    );
  }
}
