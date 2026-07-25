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

const _sinceBuckets = <({String value, String label})>[
  (value: 'lt_6_months', label: 'Less than 6 months'),
  (value: '6_months_1_year', label: '6 months – 1 year'),
  (value: '1_5_years', label: '1–5 years'),
  (value: '5_plus_years', label: '5+ years'),
  (value: 'exact_date', label: 'Enter exact date'),
];

const _yesNoSometimes = <({String value, String label})>[
  (value: 'yes', label: 'Yes'),
  (value: 'no', label: 'No'),
  (value: 'sometimes', label: 'Sometimes'),
];

String _prettyCategory(String raw) =>
    raw.split('_').map((w) => w.isEmpty ? w : w[0].toUpperCase() + w.substring(1)).join(' ');

/// Medical conditions — ported from `ConditionsSection.tsx`.
class ConditionsSection extends ConsumerWidget {
  const ConditionsSection({super.key});

  Future<void> _confirmNone(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('No known conditions'),
        content: const Text('This will be recorded in your medical history. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(healthProfileProvider.notifier).confirmNoConditions();
      AppMessenger.success('Recorded — no known conditions');
    } catch (_) {/* toasted */}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final state = ref.watch(healthProfileProvider);
    final conditions = state.conditions;
    final confirmedNone = state.noKnownConditionsConfirmedAt != null;

    return ModuleCard(
      icon: PhosphorIconsFill.heartbeat,
      title: 'Medical Conditions',
      actionLabel: 'Add',
      onAction: () => showConditionForm(context, ref),
      child: Column(
        children: [
          if (conditions.isEmpty && !confirmedNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
              child: Column(
                children: [
                  Text('No conditions logged yet.',
                      style: TextStyle(fontSize: 13.8, color: t.ink2)),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () => _confirmNone(context, ref),
                    child: const Text(
                      'I confirm I have no known conditions',
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
          else if (conditions.isEmpty && confirmedNone)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: t.soft, borderRadius: BorderRadius.circular(14)),
              child: Row(
                children: [
                  const Icon(PhosphorIconsFill.checkCircle, size: 17, color: AppColors.teal),
                  const SizedBox(width: 8),
                  Text('No known conditions — confirmed',
                      style: TextStyle(fontSize: 13.8, color: t.ink2)),
                ],
              ),
            )
          else
            for (final c in conditions)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: GestureDetector(
                  onTap: () => showConditionForm(context, ref, editing: c),
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
                              Text(c.displayName,
                                  style: TextStyle(
                                      fontSize: 14.4, fontWeight: FontWeight.w600, color: t.ink)),
                              const SizedBox(height: 2),
                              Text(
                                [
                                  if (c.sinceBucket != null)
                                    _sinceBuckets
                                        .firstWhere((s) => s.value == c.sinceBucket,
                                            orElse: () => _sinceBuckets.first)
                                        .label,
                                  if (c.onMedication) 'On medication',
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
                                  .removeCondition(c.id);
                              AppMessenger.success('Condition removed');
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

Future<void> showConditionForm(BuildContext context, WidgetRef ref, {Condition? editing}) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ConditionForm(editing: editing),
  );
}

class _ConditionForm extends ConsumerStatefulWidget {
  final Condition? editing;
  const _ConditionForm({this.editing});

  @override
  ConsumerState<_ConditionForm> createState() => _ConditionFormState();
}

class _ConditionFormState extends ConsumerState<_ConditionForm> {
  ConditionCatalogEntry? _picked;
  late String? _sinceBucket = widget.editing?.sinceBucket;
  late String _troubling = widget.editing?.currentlyTroubling ?? 'no';
  late bool _onMedication = widget.editing?.onMedication ?? false;
  bool _saving = false;
  String _search = '';

  bool get _isEdit => widget.editing != null;

  Future<void> _save() async {
    if (!_isEdit && _picked == null) {
      AppMessenger.error('Please choose a condition');
      return;
    }
    setState(() => _saving = true);
    final patch = <String, dynamic>{
      if (!_isEdit) 'conditionCode': _picked!.code,
      if (!_isEdit) 'displayName': _picked!.displayName,
      if (_sinceBucket != null) 'sinceBucket': _sinceBucket,
      'currentlyTroubling': _troubling,
      'onMedication': _onMedication,
    };
    try {
      final notifier = ref.read(healthProfileProvider.notifier);
      if (_isEdit) {
        await notifier.editCondition(widget.editing!.id, patch);
      } else {
        await notifier.addCondition(patch);
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppMessenger.success(_isEdit ? 'Condition updated' : 'Condition added');
    } catch (_) {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final catalog = ref.watch(healthProfileProvider).conditionsCatalog;

    // Step 1: pick from the catalog (add flow only). Step 2: details.
    final needsPick = !_isEdit && _picked == null;

    return FormSheet(
      title: _isEdit
          ? 'Edit ${widget.editing!.displayName}'
          : (needsPick ? 'Choose a condition' : 'About ${_picked!.displayName}'),
      saving: _saving,
      onSave: needsPick ? null : _save,
      saveLabel: needsPick ? 'Choose a condition first' : 'Save',
      children: [
        if (needsPick) ...[
          TextField(
            onChanged: (v) => setState(() => _search = v.toLowerCase()),
            decoration: const InputDecoration(hintText: 'Search conditions…'),
          ),
          const SizedBox(height: 14),
          for (final entry in catalog.entries) ...[
            Builder(builder: (_) {
              final matches = entry.value
                  .where((e) => e.displayName.toLowerCase().contains(_search))
                  .toList();
              if (matches.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _prettyCategory(entry.key),
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: t.ink3,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final e in matches)
                        GestureDetector(
                          onTap: () => setState(() => _picked = e),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                            decoration: BoxDecoration(
                              color: t.soft,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: t.line),
                            ),
                            child: Text(e.displayName,
                                style: TextStyle(fontSize: 12.8, color: t.ink)),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              );
            }),
          ],
          if (catalog.isEmpty)
            Text('Loading conditions…', style: TextStyle(fontSize: 13, color: t.ink3)),
        ] else ...[
          const FieldLabel('How long have you had this?'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final o in _sinceBuckets)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _sinceBucket == o.value,
                  onSelected: (_) => setState(() => _sinceBucket = o.value),
                ),
            ],
          ),
          const SizedBox(height: 18),
          const FieldLabel('Is it currently troubling you?'),
          Wrap(
            spacing: 8,
            children: [
              for (final o in _yesNoSometimes)
                ChoiceChip(
                  label: Text(o.label),
                  selected: _troubling == o.value,
                  onSelected: (_) => setState(() => _troubling = o.value),
                ),
            ],
          ),
          const SizedBox(height: 18),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: Text('On medication for this',
                style: TextStyle(fontSize: 14, color: t.ink)),
            value: _onMedication,
            activeThumbColor: AppColors.teal,
            onChanged: (v) => setState(() => _onMedication = v),
          ),
        ],
      ],
    );
  }
}
