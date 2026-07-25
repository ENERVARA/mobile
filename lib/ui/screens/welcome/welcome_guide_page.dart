import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';
import '../../../state/auth_provider.dart';
import '../../../state/first_run_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/logo.dart';
import 'welcome_illustrations.dart';

class _Slide {
  final List<Color> tint;
  final String title;
  final String body;
  const _Slide({
    required this.tint,
    required this.title,
    required this.body,
  });
}

const _slides = <_Slide>[
  _Slide(
    tint: [AppColors.teal, AppColors.cyan],
    title: 'Welcome to Enervara',
    body:
        'Hospital-grade care, right from your phone — no waiting rooms. Here\'s a quick look at how it works.',
  ),
  _Slide(
    tint: [AppColors.teal, AppColors.cyan],
    title: 'Meet Nova, your AI companion',
    body:
        'Describe how you feel in plain words. Nova answers your health questions and guides you to the right speciality.',
  ),
  _Slide(
    tint: [AppColors.cyan, AppColors.teal],
    title: 'Care across specialities',
    body:
        'Explore General Medicine, Cardiology, Dermatology, ENT and more — and chat with Nova about any of them.',
  ),
  _Slide(
    tint: [AppColors.lav, Color(0xFFB79BFF)],
    title: 'Your health, remembered',
    body:
        'Add your details, allergies, medications and conditions so every answer is personalised just for you.',
  ),
  _Slide(
    tint: [AppColors.coral, AppColors.amber],
    title: 'Records & quick help',
    body:
        'Upload medical reports to keep them at hand, and reach emergency services in a single tap when it matters.',
  ),
];

/// First-run feature tour shown to brand-new users right after login (before
/// the mandatory profile onboarding). Marking it seen lets the router advance
/// to `/onboarding`.
class WelcomeGuidePage extends ConsumerStatefulWidget {
  const WelcomeGuidePage({super.key});

  @override
  ConsumerState<WelcomeGuidePage> createState() => _WelcomeGuidePageState();
}

class _WelcomeGuidePageState extends ConsumerState<WelcomeGuidePage> {
  final _controller = PageController();
  int _index = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _isLast => _index == _slides.length - 1;

  void _finish() {
    ref.read(firstRunProvider.notifier).markWelcomeSeen();
    if (!mounted) return;
    // The tour now runs before login, so send unauthenticated users there;
    // the router redirect takes over from here (onboarding/setup as needed).
    final authed = ref.read(authProvider).isAuthenticated;
    context.go(authed ? '/dashboard' : '/login');
  }

  void _next() {
    if (_isLast) {
      _finish();
    } else {
      _controller.nextPage(
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;

    return Scaffold(
      backgroundColor: t.appBg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Top bar: brand + Skip ──
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 12, 4),
              child: Row(
                children: [
                  const Logo(size: 26),
                  const SizedBox(width: 8),
                  Text('Enervara',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.tealD)),
                  const Spacer(),
                  if (!_isLast)
                    TextButton(
                      onPressed: _finish,
                      child: Text('Skip',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600, color: t.ink3)),
                    ),
                ],
              ),
            ),

            // ── Slides ──
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _index = i),
                itemBuilder: (context, i) =>
                    _SlideView(index: i, slide: _slides[i], active: i == _index),
              ),
            ),

            // ── Dots ──
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < _slides.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _index ? 22 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: i == _index ? AppColors.teal : t.line,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 20),

            // ── CTA ──
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: AppButton(
                label: _isLast ? 'Get Started' : 'Next',
                variant: _isLast ? AppButtonVariant.gradient : AppButtonVariant.primary,
                height: 50,
                icon: _isLast ? PhosphorIconsBold.arrowRight : null,
                onPressed: _next,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideView extends StatefulWidget {
  final int index;
  final _Slide slide;
  final bool active;
  const _SlideView({required this.index, required this.slide, required this.active});

  @override
  State<_SlideView> createState() => _SlideViewState();
}

class _SlideViewState extends State<_SlideView> with SingleTickerProviderStateMixin {
  // Drives the title/body fade-up; the illustration owns its own controllers.
  late final AnimationController _text =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

  @override
  void initState() {
    super.initState();
    if (widget.active) _text.forward();
  }

  @override
  void didUpdateWidget(covariant _SlideView old) {
    super.didUpdateWidget(old);
    if (widget.active && !old.active) {
      _text.forward(from: 0);
    } else if (!widget.active && old.active) {
      _text.value = 0;
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  double _seg(double t, double a, double b) {
    if (b <= a) return t >= b ? 1.0 : 0.0;
    return Curves.easeOutCubic.transform(((t - a) / (b - a)).clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SlideIllustration(
            index: widget.index,
            tint: widget.slide.tint,
            active: widget.active,
          ),
          const SizedBox(height: 40),
          AnimatedBuilder(
            animation: _text,
            builder: (context, _) {
              final titleT = _seg(_text.value, 0.1, 0.6);
              final bodyT = _seg(_text.value, 0.3, 0.85);
              return Column(
                children: [
                  Opacity(
                    opacity: titleT,
                    child: Transform.translate(
                      offset: Offset(0, (1 - titleT) * 12),
                      child: Text(
                        widget.slide.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                          color: t.ink,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Opacity(
                    opacity: bodyT,
                    child: Transform.translate(
                      offset: Offset(0, (1 - bodyT) * 12),
                      child: Text(
                        widget.slide.body,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 15, height: 1.55, color: t.ink2),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
