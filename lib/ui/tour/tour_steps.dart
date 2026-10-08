import 'tour_geometry.dart';

class TourStep {
  final String id;
  final String title;
  final String body;

  /// The [TourKeys] id of the element to highlight. Omitted = a centred message
  /// with no highlight (the welcome step).
  final String? target;

  /// Frame a round element as a circle rather than a rounded rectangle.
  final bool circle;

  /// Sits in fixed app chrome (header, tab bar) — never scrolled into view.
  final bool fixed;

  /// The element lives in the navigation drawer, which must be open.
  final bool needsDrawer;

  /// The target's own corner radius, so the frame's curve matches it.
  final double ownRadius;

  const TourStep({
    required this.id,
    required this.title,
    required this.body,
    this.target,
    this.circle = false,
    this.fixed = false,
    this.needsDrawer = false,
    this.ownRadius = 0,
  });
}

/// Mobile bubbles always try below the target, then above.
const kTourMobilePrefer = [TourSide.bottom, TourSide.top];

/// The tour, in order. Copy is deliberately terse — someone should be able to
/// read each bubble in a couple of seconds. Ported from `features/tour/tourSteps.ts`
/// (mobile selectors).
const List<TourStep> kTourSteps = [
  TourStep(
    id: 'welcome',
    title: 'Welcome to Enervara',
    body: 'Take a quick tour of your dashboard. It takes under a minute, and you can skip any time.',
  ),
  TourStep(
    id: 'nova',
    title: 'Meet Nova',
    body: 'Your AI health assistant. Tap it any time to ask about symptoms, reports or medicines.',
    target: 'nova-orb-mobile',
    circle: true,
    fixed: true,
  ),
  TourStep(
    id: 'start-care',
    title: 'Start new care',
    body: 'Describe a health problem and Nova connects you to the right specialist assistant.',
    target: 'start-care',
    ownRadius: 18,
  ),
  TourStep(
    id: 'resume-care',
    title: 'Resume previous care',
    body: 'Pick up an active consultation right where you left off.',
    target: 'resume-care',
    ownRadius: 18,
  ),
  TourStep(
    id: 'health-timeline-card',
    title: 'Your health timeline',
    body: 'Your latest care at a glance. You can also add a lab report or prescription from here.',
    target: 'health-timeline',
    ownRadius: 18,
  ),
  TourStep(
    id: 'doctors',
    title: 'Doctors',
    body: 'Browse available doctors and book an appointment.',
    target: 'doctors',
    ownRadius: 18,
  ),
  TourStep(
    id: 'my-care',
    title: 'My Care',
    body: 'Track your ongoing care, appointments and what to do next.',
    target: 'm-nav-care',
    fixed: true,
    ownRadius: 10,
  ),
  TourStep(
    id: 'wellness',
    title: 'Wellness',
    body: "Log sleep, water, mood and stress so Nova's advice fits your life.",
    target: 'm-nav-wellness',
    fixed: true,
    ownRadius: 10,
  ),
  TourStep(
    id: 'health-timeline',
    title: 'Health Timeline',
    body: 'Your whole health history, in order, in one place.',
    target: 'm-nav-timeline',
    fixed: true,
    ownRadius: 10,
  ),
  TourStep(
    id: 'health-records',
    title: 'Health Records',
    body: 'All your lab reports, prescriptions and documents, searchable.',
    target: 'm-nav-records',
    fixed: true,
    ownRadius: 10,
  ),
  TourStep(
    id: 'profile',
    title: 'Your profile',
    body: 'Keep your details and health profile up to date for better advice.',
    target: 'nav-profile',
    fixed: true,
    needsDrawer: true,
  ),
];

/// Steps the patient counts through — the welcome message isn't one of them.
final int kTourCountedSteps = kTourSteps.length - 1;
