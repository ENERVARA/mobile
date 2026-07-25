import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/models/health_profile.dart';
import '../../../../state/health_profile_provider.dart';
import '../widgets/module_card.dart';
import '../widgets/sheet_scaffold.dart';

const _courseTypeOptions = <({String value, String label})>[
  (value: 'short_term', label: 'Short course'),
  (value: 'ongoing', label: 'Ongoing'),
];
const _doseUnits = ['mg', 'ml', 'mcg', 'iu', 'tablet', 'drops'];
const _frequencyPeriods = <({String value, String label})>[
  (value: 'per_day', label: 'per day'),
  (value: 'per_week', label: 'per week'),
  (value: 'per_month', label: 'per month'),
];
const _timeOfDay = ['morning', 'afternoon', 'evening', 'night'];
const _withFoodOptions = <({String value, String label})>[
  (value: 'with_food', label: 'With food'),
  (value: 'without_food', label: 'Without food'),
  (value: 'anytime', label: 'Anytime'),
];

String _titleCase(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Medications — ported from `MedicationsSection.tsx`.
class MedicationsSection extends ConsumerWidget {
  const MedicationsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final meds = ref.watch(healthProfileProvider).medications;

    return ModuleCard(
      icon: PhosphorIconsFill.pill,
      title: 'Medications',
      actionLabel: 'Add',
      onAction: () => showMedicationForm(context, ref),
      child: Column(
        children: [
          if (meds.isEmpty)
            const ModuleEmpty('No medications logged yet.')
          else
            for (final m in meds)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showMedicationForm(context, ref, editing: m),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: t.line),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(m.medicationName,
                                  style: TextStyle(
                                      fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (m.doseAmount != null)
                                    '${m.doseAmount}${m.doseUnit ?? ''}',
                                  if (m.frequencyCount != null)
                                    '${m.frequencyCount}× ${(_frequencyPeriods.firstWhere((f) => f.value == m.frequencyPeriod, orElse: () => _frequencyPeriods.first)).label}',
                                  if (m.timeOfDay.isNotEmpty)
                                    m.timeOfDay.map(_titleCase).join(', '),
                                ].join(' · '),
                                style: TextStyle(fontSize: 12.2, color: t.ink3),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await ref
                                  .read(healthProfileProvider.notifier)
                                  .removeMedication(m.id);
                              AppMessenger.success('Medication removed');
                            } catch (_) {/* toasted */}
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(4),
                            child: Icon(PhosphorIconsRegular.trash, size: 17, color: t.ink3),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ],
      ),
    );
  }
}

Future<void> showMedicationForm(BuildContext context, WidgetRef ref, {Medication? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _MedicationForm(editing: editing),
  );
}

class _MedicationForm extends ConsumerStatefulWidget {
  final Medication? editing;
  const _MedicationForm({this.editing});

  @override
  ConsumerState<_MedicationForm> createState() => _MedicationFormState();
}

class _MedicationFormState extends ConsumerState<_MedicationForm> {
  late final _name = TextEditingController(text: widget.editing?.medicationName ?? '');
  late final _dose =
      TextEditingController(text: widget.editing?.doseAmount?.toString() ?? '');
  late final _freq =
      TextEditingController(text: widget.editing?.frequencyCount?.toString() ?? '');
  late final _reason = TextEditingController(text: widget.editing?.reasonOrCondition ?? '');

  late String _courseType = widget.editing?.courseType ?? 'ongoing';
  late String _doseUnit = widget.editing?.doseUnit ?? 'mg';
  late String _freqPeriod = widget.editing?.frequencyPeriod ?? 'per_day';
  late String? _withFood = widget.editing?.withFood;
  late final Set<String> _times = {...?widget.editing?.timeOfDay};
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _freq.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppMessenger.error('Please enter the medication name');
      return;
    }
    setState(() => _saving = true);
    final patch = <String, dynamic>{
      'medicationName': _name.text.trim(),
      'courseType': _courseType,
      if (_dose.text.trim().isNotEmpty) 'doseAmount': num.tryParse(_dose.text.trim()),
      'doseUnit': _doseUnit,
      if (_freq.text.trim().isNotEmpty) 'frequencyCount': num.tryParse(_freq.text.trim()),
      'frequencyPeriod': _freqPeriod,
      'timeOfDay': _times.toList(),
      if (_withFood != null) 'withFood': _withFood,
      if (_reason.text.trim().isNotEmpty) 'reasonOrCondition': _reason.text.trim(),
    };
    try {
      final notifier = ref.read(healthProfileProvider.notifier);
      if (widget.editing != null) {
        await notifier.editMedication(widget.editing!.id, patch);
      } else {
        await notifier.addMedication(patch);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppMessenger.success(widget.editing != null ? 'Medication updated' : 'Medication added');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.editing != null ? 'Edit medication' : 'Add medication',
      saving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Medication'),
        TextField(controller: _name, decoration: const InputDecoration(hintText: 'e.g. Metformin')),
        const SizedBox(height: 18),
        const FieldLabel('Course'),
        Wrap(
          spacing: 8,
          children: [
            for (final o in _courseTypeOptions)
              ChoiceChip(
                label: Text(o.label),
                selected: _courseType == o.value,
                onSelected: (_) => setState(() => _courseType = o.value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Dose'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _dose,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'Amount'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _doseUnit,
                items: [for (final u in _doseUnits) DropdownMenuItem(value: u, child: Text(u))],
                onChanged: (v) => setState(() => _doseUnit = v ?? 'mg'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Frequency'),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _freq,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(hintText: 'How many times'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: _freqPeriod,
                items: [
                  for (final f in _frequencyPeriods)
                    DropdownMenuItem(value: f.value, child: Text(f.label)),
                ],
                onChanged: (v) => setState(() => _freqPeriod = v ?? 'per_day'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Time of day'),
        ChipMultiSelect(
          options: _timeOfDay,
          selected: _times,
          labelOf: _titleCase,
          onToggle: (v) => setState(() {
            _times.contains(v) ? _times.remove(v) : _times.add(v);
          }),
        ),
        const SizedBox(height: 18),
        const FieldLabel('With food'),
        Wrap(
          spacing: 8,
          children: [
            for (final o in _withFoodOptions)
              ChoiceChip(
                label: Text(o.label),
                selected: _withFood == o.value,
                onSelected: (_) => setState(() => _withFood = o.value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Reason / condition (optional)'),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(hintText: 'What is it for?'),
        ),
      ],
    );
  }
}
