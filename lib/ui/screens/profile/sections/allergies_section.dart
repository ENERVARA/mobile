import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/models/health_profile.dart';
import '../../../../state/health_profile_provider.dart';
import '../widgets/module_card.dart';
import '../widgets/sheet_scaffold.dart';

const _severityOptions = <({String value, String label})>[
  (value: 'mild', label: 'Mild'),
  (value: 'moderate', label: 'Moderate'),
  (value: 'severe', label: 'Severe'),
  (value: 'life_threatening', label: 'Life-threatening'),
];

const _reactionOptions = ['Rash', 'Swelling', 'Breathing difficulty', 'Digestive upset', 'Other'];

String _severityLabel(String v) =>
    _severityOptions.firstWhere((o) => o.value == v, orElse: () => _severityOptions.first).label;

Color _severityColor(String v) => switch (v) {
      'mild' => AppColors.teal,
      'moderate' => AppColors.amber,
      _ => AppColors.coral,
    };

/// Allergies — ported from `AllergiesSection.tsx`.
class AllergiesSection extends ConsumerWidget {
  const AllergiesSection({super.key});

  Future<void> _confirmNone(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No known allergies'),
        content: const Text('This will be recorded in your medical history. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(healthProfileProvider.notifier).confirmNoAllergies();
      AppMessenger.success('Recorded — no known allergies');
    } catch (_) {/* toasted */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(healthProfileProvider);
    final allergies = state.allergies;
    final confirmedNone = state.noKnownAllergiesConfirmedAt != null;

    return ModuleCard(
      icon: PhosphorIconsFill.warningCircle,
      iconColor: AppColors.coral,
      title: 'Allergies',
      actionLabel: 'Add allergy',
      onAction: () => showAllergyForm(context, ref),
      child: Column(
        children: [
          if (allergies.isEmpty && !confirmedNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Text('No allergies logged yet.',
                      style: TextStyle(fontSize: 13.8, color: t.ink2)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _confirmNone(context, ref),
                    child: const Text(
                      'I confirm I have no known allergies',
                      style: TextStyle(
                        fontSize: 13.1,
                        fontWeight: FontWeight.w600,
                        color: AppColors.tealD,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (allergies.isEmpty && confirmedNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.checkCircle, size: 17, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text('No known allergies — confirmed',
                      style: TextStyle(fontSize: 13.8, color: t.ink2)),
                ],
              ),
            )
          else
            for (final a in allergies)
              _AllergyRow(
                allergy: a,
                onTap: () => showAllergyForm(context, ref, editing: a),
                onRemove: () async {
                  try {
                    await ref.read(healthProfileProvider.notifier).removeAllergy(a.id);
                    AppMessenger.success('Allergy removed');
                  } catch (_) {/* toasted */}
                },
              ),
        ],
      ),
    );
  }
}

class _AllergyRow extends StatelessWidget {
  final Allergy allergy;
  final VoidCallback onTap;
  final VoidCallback onRemove;
  const _AllergyRow({required this.allergy, required this.onTap, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: t.line),
          ),
          child: Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: _severityColor(allergy.severity),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(allergy.allergenName,
                        style: TextStyle(fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink)),
                    const SizedBox(height: 2),
                    Text(
                      [
                        _severityLabel(allergy.severity),
                        if (allergy.reactionTypes.isNotEmpty) allergy.reactionTypes.join(', '),
                      ].join(' · '),
                      style: TextStyle(fontSize: 12.2, color: t.ink3),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onRemove,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Icon(PhosphorIconsRegular.trash, size: 17, color: t.ink3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Add / edit allergy sheet — ported from `AllergyFormModal.tsx`.
Future<void> showAllergyForm(BuildContext context, WidgetRef ref, {Allergy? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AllergyForm(editing: editing),
  );
}

class _AllergyForm extends ConsumerStatefulWidget {
  final Allergy? editing;
  const _AllergyForm({this.editing});

  @override
  ConsumerState<_AllergyForm> createState() => _AllergyFormState();
}

class _AllergyFormState extends ConsumerState<_AllergyForm> {
  late final TextEditingController _name =
      TextEditingController(text: widget.editing?.allergenName ?? '');
  late String _severity = widget.editing?.severity ?? 'mild';
  late final Set<String> _reactions = {...?widget.editing?.reactionTypes};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppMessenger.error('Please enter the allergen name');
      return;
    }
    setState(() => _saving = true);
    final patch = {
      'allergenName': _name.text.trim(),
      'severity': _severity,
      'reactionTypes': _reactions.toList(),
    };
    try {
      final notifier = ref.read(healthProfileProvider.notifier);
      if (widget.editing != null) {
        await notifier.editAllergy(widget.editing!.id, patch);
      } else {
        await notifier.addAllergy(patch);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppMessenger.success(widget.editing != null ? 'Allergy updated' : 'Allergy added');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.editing != null ? 'Edit allergy' : 'Add allergy',
      saving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Allergen'),
        TextField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'e.g. Penicillin, Peanuts'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Severity'),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final o in _severityOptions)
              ChoiceChip(
                label: Text(o.label),
                selected: _severity == o.value,
                onSelected: (_) => setState(() => _severity = o.value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Reaction types'),
        ChipMultiSelect(
          options: _reactionOptions,
          selected: _reactions,
          onToggle: (r) => setState(() {
            _reactions.contains(r) ? _reactions.remove(r) : _reactions.add(r);
          }),
        ),
      ],
    );
  }
}
