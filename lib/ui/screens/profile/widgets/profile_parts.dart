import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';

/// Titled card used across the Profile page (`InfoCard` in the web app).
class InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final Widget child;
  const InfoCard({super.key, required this.icon, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, size: 16, color: AppColors.teal),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: t.ink),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

/// Labelled text field matching the web `Input`.
class LabeledField extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final String? hint;
  final bool enabled;
  final bool locked;
  final TextInputType? keyboardType;
  final String? initialValue;
  final VoidCallback? onTap;
  final bool readOnly;

  const LabeledField({
    super.key,
    required this.label,
    this.controller,
    this.hint,
    this.enabled = true,
    this.locked = false,
    this.keyboardType,
    this.initialValue,
    this.onTap,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink2),
        ),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          initialValue: initialValue,
          enabled: enabled,
          readOnly: readOnly,
          onTap: onTap,
          keyboardType: keyboardType,
          style: TextStyle(fontSize: 14, color: enabled ? t.ink : t.ink3),
          decoration: InputDecoration(
            hintText: hint,
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            prefixIcon: locked
                ? Icon(Icons.lock_outline, size: 14, color: t.ink3)
                : null,
            prefixIconConstraints: const BoxConstraints(minWidth: 34, minHeight: 0),
          ),
        ),
      ],
    );
  }
}

/// Labelled dropdown matching the web `Select`.
class LabeledSelect extends StatelessWidget {
  final String label;
  final String? value;
  final List<({String value, String label})> options;
  final String placeholder;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  const LabeledSelect({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.placeholder,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final safeValue = options.any((o) => o.value == value) ? value : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink2)),
        const SizedBox(height: 5),
        DropdownButtonFormField<String>(
          initialValue: safeValue,
          isExpanded: true,
          hint: Text(placeholder, style: TextStyle(fontSize: 13.5, color: t.ink3)),
          style: TextStyle(fontSize: 14, color: t.ink),
          dropdownColor: t.card,
          decoration: const InputDecoration(
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          ),
          items: [
            for (final o in options)
              DropdownMenuItem(value: o.value, child: Text(o.label, overflow: TextOverflow.ellipsis)),
          ],
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }
}

/// Small metric tile (Height / Weight) on the Health Metrics card.
class MetricTile extends StatelessWidget {
  final String label;
  final String unit;
  final String? value;
  const MetricTile({super.key, required this.label, required this.unit, this.value});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(12)),
      child: Column(
        children: [
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: value?.isNotEmpty == true ? value : '—',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: t.ink,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: t.ink3),
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(fontSize: 12, color: t.ink2)),
        ],
      ),
    );
  }
}
