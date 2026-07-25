import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Bottom-tab + drawer navigation. Ported from `src/constants/navigation.ts`
/// (redesign `NAV_ITEMS` / `MOBILE_NAV_ITEMS`), with Phosphor [IconData]
/// resolved directly for regular (inactive) and fill (active) weights.
class NavItem {
  final String key;
  final String label;
  final String shortLabel;
  final IconData icon;
  final IconData iconFill;
  final String path;

  const NavItem({
    required this.key,
    required this.label,
    required this.shortLabel,
    required this.icon,
    required this.iconFill,
    required this.path,
  });
}

/// Drawer (full sidebar) order.
const List<NavItem> kNavItems = [
  NavItem(
    key: 'dashboard',
    label: 'Dashboard',
    shortLabel: 'Home',
    icon: PhosphorIconsRegular.squaresFour,
    iconFill: PhosphorIconsFill.squaresFour,
    path: '/dashboard',
  ),
  NavItem(
    key: 'specialities',
    label: 'Specialities',
    shortLabel: 'Care',
    icon: PhosphorIconsRegular.stethoscope,
    iconFill: PhosphorIconsFill.stethoscope,
    path: '/specialities',
  ),
  NavItem(
    key: 'history',
    label: 'History',
    shortLabel: 'History',
    icon: PhosphorIconsRegular.folderOpen,
    iconFill: PhosphorIconsFill.folderOpen,
    path: '/history',
  ),
  NavItem(
    key: 'reports',
    label: 'Reports',
    shortLabel: 'Reports',
    icon: PhosphorIconsRegular.clipboardText,
    iconFill: PhosphorIconsFill.clipboardText,
    path: '/reports',
  ),
  NavItem(
    key: 'profile',
    label: 'Profile',
    shortLabel: 'Profile',
    icon: PhosphorIconsRegular.user,
    iconFill: PhosphorIconsFill.user,
    path: '/profile',
  ),
];

/// Mobile bottom-tab items that sit to the LEFT of the centre Nova button.
/// (Profile lives in the top bar; Nova is the raised centre action.)
const List<NavItem> kMobileNavLeft = [
  NavItem(
    key: 'dashboard',
    label: 'Dashboard',
    shortLabel: 'Home',
    icon: PhosphorIconsRegular.squaresFour,
    iconFill: PhosphorIconsFill.squaresFour,
    path: '/dashboard',
  ),
  NavItem(
    key: 'specialities',
    label: 'Specialities',
    shortLabel: 'Speciality',
    icon: PhosphorIconsRegular.stethoscope,
    iconFill: PhosphorIconsFill.stethoscope,
    path: '/specialities',
  ),
];

/// Mobile bottom-tab items to the RIGHT of the centre Nova button.
const List<NavItem> kMobileNavRight = [
  NavItem(
    key: 'history',
    label: 'History',
    shortLabel: 'History',
    icon: PhosphorIconsRegular.folderOpen,
    iconFill: PhosphorIconsFill.folderOpen,
    path: '/history',
  ),
  NavItem(
    key: 'reports',
    label: 'Reports',
    shortLabel: 'Reports',
    icon: PhosphorIconsRegular.clipboardText,
    iconFill: PhosphorIconsFill.clipboardText,
    path: '/reports',
  ),
];
