import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';

class SegmentOption<T> {
  final T value;
  final String label;
  const SegmentOption(this.value, this.label);
}

/// Compact pill-row segmented control (Yes/No/Sometimes, etc.).
class SegmentedControl<T> extends StatelessWidget {
  final List<SegmentOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;
  final bool disabled;

  const SegmentedControl({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(999)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: options.map((opt) {
          final selected = value == opt.value;
          return Padding(
            padding: const EdgeInsets.only(right: 6),
            child: GestureDetector(
              onTap: disabled ? null : () => onChanged(opt.value),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected
                      ? [BoxShadow(color: AppColors.teal.withValues(alpha: 0.28), blurRadius: 10, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Text(
                  opt.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : t.ink2,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
