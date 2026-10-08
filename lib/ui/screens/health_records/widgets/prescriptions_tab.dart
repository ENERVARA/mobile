import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/prescription.dart';
import '../../../../state/prescriptions_provider.dart';
import '../../../widgets/common.dart';
import '../../../widgets/skeleton.dart';

const _statusFilters = <({String key, String label})>[
  (key: 'ALL', label: 'All'),
  (key: 'SAVED', label: 'Saved'),
  (key: 'READY_FOR_REVIEW', label: 'Needs review'),
  (key: 'FAILED', label: 'Failed'),
];

/// The Prescriptions list. Ported from `PrescriptionsTab.tsx`: search + sort
/// controls, status chips, and a card per prescription.
class PrescriptionsTab extends ConsumerStatefulWidget {
  final VoidCallback onScanNew;
  const PrescriptionsTab({super.key, required this.onScanNew});

  @override
  ConsumerState<PrescriptionsTab> createState() => _PrescriptionsTabState();
}

class _PrescriptionsTabState extends ConsumerState<PrescriptionsTab> {
  final _search = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _search.text = ref.read(prescriptionsProvider).query.search;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(prescriptionsProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    // Searching is a server round-trip, so wait for a pause in typing.
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      final s = ref.read(prescriptionsProvider);
      if (v != s.query.search) {
        ref.read(prescriptionsProvider.notifier).setQuery(s.query.copyWith(search: v));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final s = ref.watch(prescriptionsProvider);
    final query = s.query;
    final notifier = ref.read(prescriptionsProvider.notifier);
    final isFiltered = query.search.isNotEmpty || query.status != 'ALL';
    final showSkeleton = s.isLoading && !s.isLoaded;
    final isEmpty = s.isLoaded && s.items.isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 12,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Prescriptions',
                    style: TextStyle(
                      fontSize: 16.8,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                      color: t.ink,
                    ),
                  ),
                  Text(
                    'Add a prescription to see the medicines listed clearly.',
                    style: TextStyle(fontSize: 13.12, height: 1.5, color: t.ink2),
                  ),
                ],
              ),
              WebButton(
                label: 'Add to My Health',
                icon: PhosphorIconsFill.plusCircle,
                fontSize: 14.08,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                onTap: widget.onScanNew,
              ),
            ],
          ),
        ),

        // Controls
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 200,
                child: SearchField(
                  hint: 'Search by doctor, clinic or file…',
                  controller: _search,
                  onChanged: _onSearch,
                  radius: 11,
                  height: 36,
                  hPad: 12,
                  fontSize: 13.6,
                  clearable: true,
                ),
              ),
              IntrinsicWidth(
                child: WebSelect<String>(
                  value: query.sort,
                  height: 36,
                  radius: 11,
                  fontSize: 13.12,
                  options: [
                    for (final so in kPrescriptionSorts) (value: so, label: kPrescriptionSortLabels[so]!),
                  ],
                  onChanged: (v) => notifier.setQuery(query.copyWith(sort: v ?? 'DATE_DESC')),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final f in _statusFilters)
                RoundedChip(
                  label: f.label,
                  selected: query.status == f.key,
                  fontSize: 12.8,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  onTap: () => notifier.setQuery(query.copyWith(status: f.key)),
                ),
            ],
          ),
        ),

        if (showSkeleton)
          Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                const Skeleton(height: 104, radius: 16),
              ],
            ],
          ),
        if (isEmpty)
          DashedBox(
            radius: 16,
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 56),
            child: Column(
              children: [
                Icon(PhosphorIconsRegular.prescription, size: 38.4, color: t.ink3),
                const SizedBox(height: 12),
                Text(
                  isFiltered ? 'No prescriptions match' : 'No prescriptions yet',
                  style: TextStyle(fontSize: 15.68, fontWeight: FontWeight.w600, height: 1.5, color: t.ink),
                ),
                const SizedBox(height: 4),
                Text(
                  isFiltered
                      ? 'Try a different search or filter.'
                      : 'Add your first prescription to see the medicines listed clearly.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
                ),
                if (!isFiltered) ...[
                  const SizedBox(height: 20),
                  WebButton(
                    label: 'Add to My Health',
                    icon: PhosphorIconsFill.plusCircle,
                    onTap: widget.onScanNew,
                  ),
                ],
              ],
            ),
          ),
        if (s.items.isNotEmpty)
          Column(
            children: [
              for (var i = 0; i < s.items.length; i++) ...[
                if (i > 0) const SizedBox(height: 10),
                _PrescriptionRow(
                  item: s.items[i],
                  onOpen: () => context.push('/prescriptions/${s.items[i].id}'),
                ),
              ],
            ],
          ),
      ],
    );
  }
}

class _PrescriptionRow extends StatelessWidget {
  final PrescriptionListItem item;
  final VoidCallback onOpen;
  const _PrescriptionRow({required this.item, required this.onOpen});

  static const _purple = Color(0xFF6D5BD0);
  static const _purpleDark = Color(0xFFA99BF5);

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final needsReview = item.summary.needsReviewCount;

    // STATUS_COPY tones.
    late final String label;
    late final Color pillBg;
    late final Color pillFg;
    switch (item.status) {
      case 'READY_FOR_REVIEW':
        label = 'Needs review';
        pillBg = const Color(0x24D69E2E);
        pillFg = dark ? const Color(0xFFE0AC55) : const Color(0xFF8A6118);
        break;
      case 'SAVED':
        label = 'Saved';
        pillBg = AppColors.teal.withValues(alpha: 0.12);
        pillFg = dark ? AppColors.teal : AppColors.tealD;
        break;
      case 'FAILED':
        label = 'Failed';
        pillBg = const Color(0x1FF26440);
        pillFg = dark ? const Color(0xFFFF8968) : const Color(0xFFC1441F);
        break;
      default:
        label = 'Analysing';
        pillBg = t.soft;
        pillFg = t.ink3;
    }

    final created = Formatters.tryParse(item.createdAt);
    final prescribed = Formatters.tryParse(item.prescribedDate);
    final sub = [
      item.clinicName,
      prescribed != null ? Formatters.dateTime(prescribed) : null,
    ].where((x) => x != null && x.isNotEmpty).join(' · ');

    return Material(
      color: t.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onOpen,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: t.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x1F6D5BD0),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(PhosphorIconsFill.prescription, size: 17.6, color: dark ? _purpleDark : _purple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            item.prescriberName ?? item.originalFileName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15.36,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: t.ink,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: pillBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            label,
                            style: TextStyle(
                              fontSize: 10.88,
                              fontWeight: FontWeight.w600,
                              height: 1.5,
                              color: pillFg,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Text(
                      sub.isNotEmpty
                          ? sub
                          : 'Uploaded ${created != null ? Formatters.dateTime(created) : ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 4,
                        children: [
                          Text(
                            '${item.summary.medicationCount} ${item.summary.medicationCount == 1 ? 'medicine' : 'medicines'}',
                            style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink2),
                          ),
                          if (needsReview > 0)
                            Text(
                              '$needsReview to check',
                              style: TextStyle(
                                fontSize: 12.48,
                                fontWeight: FontWeight.w600,
                                height: 1.5,
                                color: dark ? const Color(0xFFFF8968) : const Color(0xFFC1441F),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 12),
                child: Icon(PhosphorIconsRegular.caretRight, size: 16, color: t.ink3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
