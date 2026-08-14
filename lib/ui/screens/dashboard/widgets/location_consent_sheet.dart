import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/background/location_task.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/services/location_service.dart';
import '../../../widgets/app_button.dart';

/// One-time background-location disclosure, shown after login per Play
/// Store / App Store policy: background location access needs a clear,
/// prominent in-app explanation BEFORE the OS permission prompt, not just
/// the permission dialog's own text. `LocationService.hasDecidedConsent()`
/// gates this to exactly once ever, regardless of whether the user accepts
/// or dismisses it. Mirrors `showBasicOnboardingSheet`'s presentation, but
/// dismissible — a permission can never be made mandatory to close.
Future<void> showLocationConsentSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationConsentSheet(),
  );
}

class _LocationConsentSheet extends StatefulWidget {
  const _LocationConsentSheet();

  @override
  State<_LocationConsentSheet> createState() => _LocationConsentSheetState();
}

class _LocationConsentSheetState extends State<_LocationConsentSheet> {
  bool _submitting = false;

  Future<void> _enable() async {
    setState(() => _submitting = true);
    try {
      final granted = await LocationService.instance.grantConsentAndEnable();
      if (granted) {
        await LocationBackgroundTask.schedule();
        if (mounted) AppMessenger.success('Location check-ins enabled');
      } else if (mounted) {
        AppMessenger.error(
          'Location permission wasn\'t granted. You can enable it later from your device Settings.',
        );
      }
    } finally {
      if (mounted) Navigator.of(context).pop();
    }
  }

  Future<void> _notNow() async {
    await LocationService.instance.declineConsent();
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(
        22,
        24,
        22,
        24 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: const BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                PhosphorIconsFill.mapPinSimpleArea,
                size: 26,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Help Nova understand your health context',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 10),
          Text(
            'With your permission, Enervara checks your location once a day — '
            'even when the app is closed — to detect recent travel. This '
            'helps Nova give more accurate guidance for travel-related '
            'symptoms, and will soon power a "doctors near you" feature. '
            'You can turn this off anytime in Settings.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.6, height: 1.5, color: t.ink2),
          ),
          const SizedBox(height: 22),
          AppButton(
            label: 'Enable location check-ins',
            height: 48,
            loading: _submitting,
            onPressed: _enable,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Not now',
            variant: AppButtonVariant.ghost,
            height: 44,
            onPressed: _submitting ? null : _notNow,
          ),
        ],
      ),
    );
  }
}
