import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../state/appointments_provider.dart';
import '../../../tour/tour_keys.dart';
import '../../../widgets/common.dart';
import '../../../widgets/provider_card.dart';
import '../../../widgets/skeleton.dart';

/// How many fit on the dashboard before the list starts competing with the page.
const _previewCount = 4;

/// The doctors a patient can book, on the dashboard. Ported from
/// `NearbyDoctorsCard.tsx`: real clinicians from the database, each handed to the
/// booking flow. Names and qualifications are what a patient actually chooses on,
/// and those are real.
class NearbyDoctorsCard extends ConsumerWidget {
  const NearbyDoctorsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final doctors = ref.watch(cliniciansProvider);
    final list = doctors.valueOrNull ?? const [];

    return Container(
      key: TourKeys.of('doctors'),
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: t.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Doctors',
                        style: TextStyle(
                          fontSize: 17.28,
                          fontWeight: FontWeight.w600,
                          height: 1.5,
                          color: t.ink,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'Choose a doctor to book an appointment',
                          style: TextStyle(fontSize: 12.48, height: 1.5, color: t.ink3),
                        ),
                      ),
                    ],
                  ),
                ),
                if (list.length > _previewCount) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => context.push('/doctors'),
                    child: const Text(
                      'See all',
                      style: TextStyle(
                        fontSize: 13.28,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: AppColors.teal,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          doctors.when(
            loading: () => Column(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(height: 6),
                  const PulseBlock(height: 60, radius: 12),
                ],
              ],
            ),
            error: (_, __) => const DashedEmpty(
              icon: PhosphorIconsRegular.warningCircle,
              title: "Couldn't load doctors",
              body: 'Something went wrong reaching the directory. Refresh to try again.',
              radius: 12,
              bodyMaxWidth: 272,
            ),
            data: (providers) => providers.isEmpty
                ? const DashedEmpty(
                    icon: PhosphorIconsRegular.stethoscope,
                    title: 'No doctors available yet',
                    body: "Once a clinician joins, they'll appear here and you can book with them.",
                    radius: 12,
                    bodyMaxWidth: 272,
                  )
                : Column(
                    children: [
                      for (var i = 0; i < providers.take(_previewCount).length; i++) ...[
                        if (i > 0) const SizedBox(height: 6),
                        ProviderCard(provider: providers[i]),
                      ],
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
