import 'package:flutter/widgets.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

/// Bottom-tab + drawer navigation. Ported from `src/constants/navigation.ts`
/// (`NAV_ITEMS` / `PROFILE_NAV_ITEM` / `MOBILE_NAV_ITEMS`), with Phosphor
/// [IconData] resolved directly for regular (inactive) and fill (active) weights.
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

/// Health destinations, in the order a patient reaches for them. Profile is
/// deliberately NOT here: it is an account destination, anchored separately at
/// the bottom of the drawer (see [kProfileNavItem]).
const List<NavItem> kNavItems = [
  NavItem(
    key: 'home',
    label: 'Home',
    shortLabel: 'Home',
    icon: PhosphorIconsRegular.house,
    iconFill: PhosphorIconsFill.house,
    path: '/dashboard',
  ),
  NavItem(
    key: 'care',
    label: 'My Care',
    shortLabel: 'Care',
    icon: PhosphorIconsRegular.calendarCheck,
    iconFill: PhosphorIconsFill.calendarCheck,
    path: '/care',
  ),
  NavItem(
    key: 'wellness',
    label: 'Wellness',
    shortLabel: 'Wellness',
    icon: PhosphorIconsRegular.leaf,
    iconFill: PhosphorIconsFill.leaf,
    path: '/wellness',
  ),
  NavItem(
    key: 'timeline',
    label: 'Health Timeline',
    shortLabel: 'Timeline',
    icon: PhosphorIconsRegular.clockCounterClockwise,
    iconFill: PhosphorIconsFill.clockCounterClockwise,
    path: '/health-timeline',
  ),
  NavItem(
    key: 'records',
    label: 'Health Records',
    shortLabel: 'Records',
    icon: PhosphorIconsRegular.folderOpen,
    iconFill: PhosphorIconsFill.folderOpen,
    path: '/health-records',
  ),
];

const NavItem kProfileNavItem = NavItem(
  key: 'profile',
  label: 'Profile',
  shortLabel: 'Profile',
  icon: PhosphorIconsRegular.user,
  iconFill: PhosphorIconsFill.user,
  path: '/profile',
);

/// Mobile bottom tabs: the health destinations only. Profile isn't repeated
/// here — the header's hamburger opens the drawer, which anchors Profile at
/// its bottom.
const List<NavItem> kMobileNavItems = kNavItems;
