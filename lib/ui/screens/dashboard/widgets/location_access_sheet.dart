import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/context_ext.dart';
import '../../../../core/ui/app_messenger.dart';
import '../../../../data/services/location_service.dart';

/// The three-option location-access prompt — shown once automatically after
/// login (Play Store / App Store policy requires a clear, prominent in-app
/// explanation BEFORE the OS permission dialog, not just the dialog's own
/// text) AND reopened on demand from the header's location toggle button, so
/// the user can change their choice anytime. Mirrors
/// `showBasicOnboardingSheet`'s presentation, but always dismissible — a
/// permission prompt can never be made mandatory to close.
Future<void> showLocationAccessSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _LocationAccessSheet(),
  );
}

class _Option {
  final LocationAccessMode mode;
  final IconData icon;
  final String title;
  final String subtitle;
  const _Option({
    required this.mode,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}

const _options = <_Option>[
  _Option(
    mode: LocationAccessMode.continuous,
    icon: PhosphorIconsFill.mapPinSimpleArea,
    title: 'Continuous',
    subtitle: 'Runs in the background and updates your location when you '
        'move to a new place — even if the app is closed.',
  ),
  _Option(
    mode: LocationAccessMode.whileInUse,
    icon: PhosphorIconsFill.mapPin,
    title: 'Only when app is open',
    subtitle: 'Updates your location only while you have Enervara open.',
  ),
  _Option(
    mode: LocationAccessMode.off,
    icon: PhosphorIconsBold.prohibit,
    title: "Don't allow",
    subtitle: "Doesn't enable location at all. Nova won't be able to use "
        'travel-based context.',
  ),
];

class _LocationAccessSheet extends StatefulWidget {
  const _LocationAccessSheet();

  @override
  State<_LocationAccessSheet> createState() => _LocationAccessSheetState();
}

class _LocationAccessSheetState extends State<_LocationAccessSheet> {
  LocationAccessMode? _current;
  LocationAccessMode? _applying;

  @override
  void initState() {
    super.initState();
    LocationService.instance.currentMode().then((m) {
      if (mounted) setState(() => _current = m);
    });
  }

  Future<void> _choose(LocationAccessMode requested) async {
    setState(() => _applying = requested);
    final result = await LocationService.instance.setMode(requested);
    if (!mounted) return;

    final message = _messageFor(requested, result);
    if (message != null) {
      if (result.mode == LocationAccessMode.off && requested != LocationAccessMode.off) {
        AppMessenger.error(message);
      } else {
        AppMessenger.info(message);
      }
    } else if (result.mode != LocationAccessMode.off) {
      AppMessenger.success('Location access updated');
    }

    setState(() {
      _current = result.mode;
      _applying = null;
    });
    if (mounted) Navigator.of(context).pop();
  }

  /// Null means "landed exactly on what was asked, nothing more to say."
  String? _messageFor(LocationAccessMode requested, LocationSetModeResult result) {
    switch (result.issue) {
      case null:
        return null;
      case LocationSetModeIssue.servicesDisabled:
        return 'Turn on Location for this device in system Settings, then try again.';
      case LocationSetModeIssue.permissionDenied:
        return 'Location permission wasn\'t granted. You can enable it from your device Settings.';
      case LocationSetModeIssue.fixFailed:
        return 'Permission was granted, but a GPS fix couldn\'t be obtained — check your '
            'signal (or, on an emulator, set a mock location) and try again.';
      case LocationSetModeIssue.backgroundEscalationNeeded:
        return '"Only when app is open" is active — the OS needs "Allow all the time" set '
            'from your device\'s Settings (Enervara → Permissions → Location) to enable Continuous.';
    }
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
        18,
        24,
        18,
        20 + MediaQuery.viewPaddingOf(context).bottom,
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
          const SizedBox(height: 16),
          Text(
            'Help Nova understand your health context',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: t.ink),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Text(
              'With your permission, Enervara detects when you\'ve travelled '
              'to a new place, helping Nova give more accurate guidance for '
              'travel-related symptoms — and soon, to show doctors near you.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, height: 1.45, color: t.ink2),
            ),
          ),
          const SizedBox(height: 18),
          for (final o in _options) ...[
            _OptionTile(
              option: o,
              selected: _current == o.mode,
              loading: _applying == o.mode,
              enabled: _applying == null,
              onTap: () => _choose(o.mode),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final _Option option;
  final bool selected;
  final bool loading;
  final bool enabled;
  final VoidCallback onTap;

  const _OptionTile({
    required this.option,
    required this.selected,
    required this.loading,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: selected ? AppColors.teal.withValues(alpha: 0.08) : t.soft,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.teal : t.line,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? AppColors.teal : t.card,
                shape: BoxShape.circle,
                border: selected ? null : Border.all(color: t.line),
              ),
              child: Icon(
                option.icon,
                size: 18,
                color: selected ? Colors.white : t.ink2,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.title,
                    style: TextStyle(
                      fontSize: 14.2,
                      fontWeight: FontWeight.w700,
                      color: t.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    option.subtitle,
                    style: TextStyle(fontSize: 12, height: 1.4, color: t.ink2),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (selected)
              const Icon(PhosphorIconsFill.checkCircle, size: 20, color: AppColors.teal),
          ],
        ),
      ),
    );
  }
}
