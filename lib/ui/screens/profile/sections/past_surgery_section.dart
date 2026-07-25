import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/models/health_profile.dart';
import '../../../../state/health_profile_provider.dart';
import '../widgets/module_card.dart';
import '../widgets/sheet_scaffold.dart';

const _statusOptions = <({String value, String label})>[
  (value: 'fully_recovered', label: 'Fully Recovered'),
  (value: 'ongoing_follow_up', label: 'Ongoing Follow-up'),
];

/// Past surgeries — ported from `PastSurgerySection.tsx`.
class PastSurgerySection extends ConsumerWidget {
  const PastSurgerySection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final surgeries = ref.watch(healthProfileProvider).surgeries;

    return ModuleCard(
      icon: PhosphorIconsFill.firstAidKit,
      title: 'Past Surgery',
      actionLabel: 'Add',
      onAction: () => showSurgeryForm(context, ref),
      child: Column(
        children: [
          if (surgeries.isEmpty)
            const ModuleEmpty('No surgeries logged yet.')
          else
            for (final s in surgeries)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showSurgeryForm(context, ref, editing: s),
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
                              Text(s.surgeryName,
                                  style: TextStyle(
                                      fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  '${s.year}',
                                  _statusOptions
                                      .firstWhere((o) => o.value == s.currentStatus,
                                          orElse: () => _statusOptions.first)
                                      .label,
                                  if ((s.hospital ?? '').isNotEmpty) s.hospital!,
                                ].join(' · '),
                                style: TextStyle(fontSize: 12.2, color: t.ink3),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () async {
                            try {
                              await ref.read(healthProfileProvider.notifier).removeSurgery(s.id);
                              AppMessenger.success('Surgery removed');
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

Future<void> showSurgeryForm(BuildContext context, WidgetRef ref, {Surgery? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _SurgeryForm(editing: editing),
  );
}

class _SurgeryForm extends ConsumerStatefulWidget {
  final Surgery? editing;
  const _SurgeryForm({this.editing});

  @override
  ConsumerState<_SurgeryForm> createState() => _SurgeryFormState();
}

class _SurgeryFormState extends ConsumerState<_SurgeryForm> {
  late final _name = TextEditingController(text: widget.editing?.surgeryName ?? '');
  late final _year = TextEditingController(text: widget.editing?.year.toString() ?? '');
  late final _reason = TextEditingController(text: widget.editing?.reason ?? '');
  late final _hospital = TextEditingController(text: widget.editing?.hospital ?? '');
  late String _status = widget.editing?.currentStatus ?? 'fully_recovered';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _year.dispose();
    _reason.dispose();
    _hospital.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final year = int.tryParse(_year.text.trim());
    if (_name.text.trim().isEmpty) {
      AppMessenger.error('Please enter the surgery name');
      return;
    }
    if (year == null || year < 1900 || year > DateTime.now().year) {
      AppMessenger.error('Please enter a valid year');
      return;
    }
    setState(() => _saving = true);
    final patch = <String, dynamic>{
      'surgeryName': _name.text.trim(),
      'year': year,
      'currentStatus': _status,
      if (_reason.text.trim().isNotEmpty) 'reason': _reason.text.trim(),
      if (_hospital.text.trim().isNotEmpty) 'hospital': _hospital.text.trim(),
    };
    try {
      final notifier = ref.read(healthProfileProvider.notifier);
      if (widget.editing != null) {
        await notifier.editSurgery(widget.editing!.id, patch);
      } else {
        await notifier.addSurgery(patch);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppMessenger.success(widget.editing != null ? 'Surgery updated' : 'Surgery added');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormSheet(
      title: widget.editing != null ? 'Edit surgery' : 'Add surgery',
      saving: _saving,
      onSave: _save,
      children: [
        const FieldLabel('Surgery'),
        TextField(
          controller: _name,
          decoration: const InputDecoration(hintText: 'e.g. Appendectomy'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Year'),
        TextField(
          controller: _year,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 2019'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Current status'),
        Wrap(
          spacing: 8,
          children: [
            for (final o in _statusOptions)
              ChoiceChip(
                label: Text(o.label),
                selected: _status == o.value,
                onSelected: (_) => setState(() => _status = o.value),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const FieldLabel('Reason (optional)'),
        TextField(
          controller: _reason,
          decoration: const InputDecoration(hintText: 'Why was it done?'),
        ),
        const SizedBox(height: 18),
        const FieldLabel('Hospital (optional)'),
        TextField(
          controller: _hospital,
          decoration: const InputDecoration(hintText: 'Where was it done?'),
        ),
      ],
    );
  }
}
