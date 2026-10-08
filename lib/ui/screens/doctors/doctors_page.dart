import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/context_ext.dart';
import '../../../state/appointments_provider.dart';
import '../../widgets/common.dart';
import '../../widgets/provider_card.dart';
import '../../widgets/skeleton.dart';

/// The full doctor directory, reached from the dashboard's "See all" link.
/// Ported from `DoctorsPage.tsx`: real clinicians, from the same endpoint the
/// booking flow reads.
class DoctorsPage extends ConsumerWidget {
  const DoctorsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final doctors = ref.watch(cliniciansProvider);

    final subtitle = doctors.when(
      loading: () => 'Loading…',
      error: (_, __) => 'Directory unavailable',
      data: (list) => list.length == 1 ? '1 doctor available' : '${list.length} doctors available',
    );

    return ShellPage(
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 24),
          child: Row(
            children: [
              BackSquareButton(
                semanticLabel: 'Back to dashboard',
                onTap: () => context.canPop() ? context.pop() : context.go('/dashboard'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All doctors',
                      style: TextStyle(
                        fontSize: 27.2,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.816,
                        height: 1.5,
                        color: t.ink,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle,
                        style: TextStyle(fontSize: 14.08, height: 1.5, color: t.ink2),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        doctors.when(
          loading: () => Column(
            children: [
              for (var i = 0; i < 6; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                const PulseBlock(height: 184, radius: 14),
              ],
            ],
          ),
          error: (_, __) => const DashedEmpty(
            icon: PhosphorIconsRegular.warningCircle,
            title: "Couldn't load the directory",
            body: 'Something went wrong reaching the doctor directory. Refresh to try again.',
            radius: 14,
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 56),
            iconSize: 28.8,
            titleSize: 16,
            bodySize: 13.6,
            bodyMaxWidth: 336,
          ),
          data: (list) => list.isEmpty
              ? const DashedEmpty(
                  icon: PhosphorIconsRegular.stethoscope,
                  title: 'No doctors available yet',
                  body: "Once a clinician joins Enervara, they'll appear here and you can book with them.",
                  radius: 14,
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 56),
                  iconSize: 28.8,
                  titleSize: 16,
                  bodySize: 13.6,
                  bodyMaxWidth: 336,
                )
              : Column(
                  children: [
                    for (var i = 0; i < list.length; i++) ...[
                      if (i > 0) const SizedBox(height: 12),
                      ProviderCard(provider: list[i], card: true),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
