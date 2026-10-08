import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/context_ext.dart';
import '../../data/models/appointment.dart';
import 'tone_avatar.dart';

/// One bookable doctor. Ported from `ProviderCard.tsx`.
///
/// Shows only what the record actually holds — name, qualifications and
/// speciality. "Book" hands off to the existing booking flow with the doctor
/// preselected, rather than opening a second booking path of its own.
class ProviderCard extends StatelessWidget {
  final Clinician provider;

  /// `row` for the dashboard list, `card` for the directory grid.
  final bool card;
  const ProviderCard({super.key, required this.provider, this.card = false});

  String get _bookPath => '/care/book?doctor=${Uri.encodeComponent(provider.id)}';

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final dark = context.isDark;
    final name = ProviderNames.titled(provider.fullName);
    final degrees = provider.qualifications.join(', ');

    if (card) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: t.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: t.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                ToneAvatar(
                  initials: ProviderNames.initials(provider.fullName),
                  tone: ProviderNames.tone(provider.id),
                  size: 44,
                  fontSize: 13.6,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15.2,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                          color: t.ink,
                        ),
                      ),
                      if (provider.specialityName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            provider.specialityName!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink2),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            if (degrees.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 1),
                      child: Icon(PhosphorIconsRegular.graduationCap, size: 14, color: AppColors.teal),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        degrees,
                        style: TextStyle(fontSize: 12.8, height: 1.5, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
            if (provider.registrationNumber != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(PhosphorIconsRegular.identificationCard, size: 14, color: AppColors.teal),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Reg. ${provider.registrationNumber}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.5, color: t.ink3),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            Material(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context.push(_bookPath),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  child: Center(
                    child: Text(
                      'Book appointment',
                      style: TextStyle(
                        fontSize: 13.6,
                        fontWeight: FontWeight.w600,
                        height: 1.5,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final subtitle = [provider.specialityName, degrees]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.line),
      ),
      child: Row(
        children: [
          ToneAvatar(
            initials: ProviderNames.initials(provider.fullName),
            tone: ProviderNames.tone(provider.id),
            size: 40,
            fontSize: 13.12,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.08,
                    fontWeight: FontWeight.w600,
                    height: 1.25,
                    color: t.ink,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    subtitle.isEmpty ? 'Clinician' : subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, height: 1.5, color: t.ink3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Material(
            color: dark ? AppColors.teal.withValues(alpha: 0.15) : t.soft,
            borderRadius: BorderRadius.circular(10),
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => context.push(_bookPath),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: Text(
                  'Book',
                  style: TextStyle(
                    fontSize: 12.8,
                    fontWeight: FontWeight.w600,
                    height: 1.5,
                    color: dark ? AppColors.teal : AppColors.tealD,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
