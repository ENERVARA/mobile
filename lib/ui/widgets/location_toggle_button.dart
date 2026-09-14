import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../data/services/location_service.dart';
import '../screens/dashboard/widgets/location_access_sheet.dart';

/// Location action button that opens the current permission sheet.
/// The compact header version is still supported for other screens; the profile
/// page uses the larger action variant below.
class LocationToggleButton extends StatefulWidget {
  const LocationToggleButton({
    super.key,
    this.compact = true,
    this.showStatus = true,
    this.label,
  });

  final bool compact;
  final bool showStatus;
  final String? label;

  @override
  State<LocationToggleButton> createState() => _LocationToggleButtonState();
}

class _LocationToggleButtonState extends State<LocationToggleButton> {
  LocationAccessMode _mode = LocationAccessMode.off;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final mode = await LocationService.instance.currentMode();
    if (mounted) setState(() => _mode = mode);
  }

  Future<void> _open() async {
    await showLocationAccessSheet(context);
    await _refresh();
  }

  String _labelFor(LocationAccessMode mode) {
    switch (mode) {
      case LocationAccessMode.off:
        return 'Off';
      case LocationAccessMode.whileInUse:
        return 'While using app only';
      case LocationAccessMode.continuous:
        return 'Always';
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = widget.label ?? _labelFor(_mode);
    final isOff = _mode == LocationAccessMode.off;

    if (widget.compact) {
      return GestureDetector(
        onTap: _open,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: isOff
                ? AppColors.warning.withValues(alpha: 0.12)
                : AppColors.teal.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: isOff
                  ? AppColors.warning.withValues(alpha: 0.6)
                  : AppColors.teal.withValues(alpha: 0.5),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _mode == LocationAccessMode.off
                    ? PhosphorIconsRegular.prohibit
                    : _mode == LocationAccessMode.whileInUse
                        ? PhosphorIconsRegular.mapPin
                        : PhosphorIconsFill.mapPinSimpleArea,
                size: 15,
                color: isOff ? AppColors.coral : AppColors.teal,
              ),
              const SizedBox(width: 6),
              if (widget.showStatus)
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: isOff ? AppColors.coral : AppColors.teal,
                  ),
                ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: _open,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isOff
              ? AppColors.warning.withValues(alpha: 0.10)
              : AppColors.teal.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isOff
                ? AppColors.warning.withValues(alpha: 0.55)
                : AppColors.teal.withValues(alpha: 0.55),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _mode == LocationAccessMode.off
                  ? PhosphorIconsRegular.prohibit
                  : _mode == LocationAccessMode.whileInUse
                      ? PhosphorIconsRegular.mapPin
                      : PhosphorIconsFill.mapPinSimpleArea,
              size: 18,
              color: isOff ? AppColors.coral : AppColors.teal,
            ),
            const SizedBox(width: 8),
            Text(
              widget.label ?? 'Update location',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: isOff ? AppColors.coral : AppColors.teal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
