import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/context_ext.dart';

/// Plays the brand intro at most once per app launch (so navigating
/// login ⇄ signup doesn't replay the ~4.6s sequence).
bool _introPlayed = false;

/// The animated auth scene — a faithful port of the web `auth-scene.css`
/// choreography: a bird flies in from the top-right, three dot-layers pop in to
/// assemble the mark, "Enervara" writes on, the whole brand glides up, and the
/// form card flies up beneath it. Ambient teal/lav orbs breathe behind it all.
///
/// [child] is the form content (login or signup) placed inside the card.
class AuthScene extends StatefulWidget {
  final Widget child;
  const AuthScene({super.key, required this.child});

  @override
  State<AuthScene> createState() => _AuthSceneState();
}

class _AuthSceneState extends State<AuthScene> with TickerProviderStateMixin {
  // Total intro length — matches the web (bird 0s … card fly-up ends ~4.6s).
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 4700),
  );
  late final AnimationController _breathe = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  )..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    if (_introPlayed) {
      _c.value = 1; // already seen this session → show the settled layout
    } else {
      _introPlayed = true;
      _c.forward();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    _breathe.dispose();
    super.dispose();
  }

  /// Local, curved 0→1 progress for a sub-segment of the timeline.
  double _seg(double v, double a, double b, Curve curve) {
    final t = ((v - a) / (b - a)).clamp(0.0, 1.0);
    return curve.transform(t);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final topPad = MediaQuery.viewPaddingOf(context).top;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: t.appBg,
      resizeToAvoidBottomInset: false,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;
          final introCenterY = h / 2;
          final restCenterY = topPad + 92;
          final cardTop = restCenterY + 88;

          return AnimatedBuilder(
            animation: Listenable.merge([_c, _breathe]),
            builder: (context, _) {
              final v = _c.value;

              // ── Brand move-up + scale ──
              final moveUp = _seg(v, 0.681, 0.936, Curves.easeInOutCubic);
              final brandCenterY = lerpDouble(introCenterY, restCenterY, moveUp);
              final brandScale = lerpDouble(1.0, 0.95, moveUp);

              // ── Card fly-up ──
              final cardT = _seg(v, 0.787, 0.979, Curves.easeOutCubic);
              final cardDy = lerpDouble(60, 0, cardT);
              final cardOpacity = cardT;

              return Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── Ambient orbs ──
                  _orb(
                    top: -140,
                    right: -120,
                    size: 420,
                    colors: [
                      AppColors.teal.withValues(alpha: 0.16),
                      AppColors.cyan.withValues(alpha: 0.06),
                    ],
                    breathe: _breathe.value,
                  ),
                  _orb(
                    bottom: -130,
                    left: -110,
                    size: 360,
                    colors: [
                      AppColors.lav.withValues(alpha: 0.14),
                      AppColors.lav.withValues(alpha: 0.05),
                    ],
                    breathe: 1 - _breathe.value,
                  ),

                  // ── Brand (logo layers + name) ──
                  Positioned(
                    top: brandCenterY - 46,
                    left: 0,
                    right: 0,
                    child: Center(
                      // Shift the whole brand lockup left so it optically
                      // centers (the bird's tail glyph biases it right).
                      // Change this one value to nudge it — negative = left.
                      child: Transform.translate(
                        offset: const Offset(-20, 0),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Transform.scale(
                              scale: brandScale,
                              child: _brand(v),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Form card ──
                  Positioned(
                    top: cardTop,
                    left: 0,
                    right: 0,
                    bottom: 0,
                    child: IgnorePointer(
                      ignoring: cardOpacity < 0.05,
                      child: Opacity(
                        opacity: cardOpacity.clamp(0.0, 1.0),
                        child: Transform.translate(
                          offset: Offset(0, cardDy),
                          child: SingleChildScrollView(
                            physics: const ClampingScrollPhysics(),
                            padding: EdgeInsets.fromLTRB(
                              20, 0, 20, 28 + bottomPad + bottomInset),
                            child: Container(
                              width: double.infinity,
                              constraints: BoxConstraints(maxWidth: math.min(420, w)),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: t.card,
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: t.line),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black
                                        .withValues(alpha: context.isDark ? 0.3 : 0.08),
                                    blurRadius: 32,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: widget.child,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  // ── Brand: the 95×70 logo slot (4 layered images) + "Enervara" ──
  Widget _brand(double v) {
    // Splash layers pop in with an overshoot; the bird flies in first.
    final birdT = _seg(v, 0.0, 0.245, Curves.easeOut);
    final birdOpacity = _seg(v, 0.0, 0.11, Curves.easeOut);

    final nameT = _seg(v, 0.383, 0.606, Curves.easeOutCubic);
    final nameOpacity = _seg(v, 0.383, 0.472, Curves.easeOut);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 95,
          height: 70,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              _splash(v, 'assets/images/L-2.png', 1.15 / 4.7, 1.65 / 4.7, const Alignment(0.1, 0.1)),
              _splash(v, 'assets/images/L-3.png', 1.25 / 4.7, 1.75 / 4.7, const Alignment(0.1, 0.3)),
              _splash(v, 'assets/images/L-1.png', 1.0 / 4.7, 1.6 / 4.7, const Alignment(0.5, 0.0)),
              // Bird — flies in from the top-right, settles slightly high.
              Positioned(
                left: 0,
                top: 0,
                child: Opacity(
                  opacity: birdOpacity.clamp(0.0, 1.0),
                  child: Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.identity()
                      ..translateByDouble(
                          lerpDouble(250, 0, birdT), lerpDouble(-100, -16, birdT), 0, 1)
                      ..scaleByDouble(
                          lerpDouble(3.5, 1.0, birdT), lerpDouble(3.5, 1.0, birdT), 1, 1),
                    child: Image.asset('assets/images/L-bird.png', width: 123.5, height: 91),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 20),
        // "Enervara" — a left-anchored scaleX write-on reveal.
        Opacity(
          opacity: nameOpacity.clamp(0.0, 1.0),
          child: Transform(
            alignment: Alignment.centerLeft,
            transform: Matrix4.diagonal3Values(lerpDouble(0.02, 1.0, nameT), 1.0, 1.0),
            child: Text(
              'Enervara',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w700,
                letterSpacing: -1.4,
                color: AppColors.tealD,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _splash(double v, String asset, double start, double end, Alignment origin) {
    final scaleT = _seg(v, start, end, Curves.easeOutBack);
    final easeT = _seg(v, start, end, Curves.easeOut);
    final opacity = _seg(v, start, start + (end - start) * 0.5, Curves.easeOut);
    return Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: opacity.clamp(0.0, 1.0),
        child: Transform(
          alignment: origin,
          transform: Matrix4.identity()
            ..translateByDouble(0.0, lerpDouble(0, -14, easeT), 0, 1)
            ..scaleByDouble(
                scaleT.clamp(0.0, 1.2), scaleT.clamp(0.0, 1.2), 1, 1)
            ..rotateZ(lerpDouble(-45 * math.pi / 180, 0, easeT)),
          child: Image.asset(asset, width: 123.5, height: 91),
        ),
      ),
    );
  }

  Widget _orb({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required double size,
    required List<Color> colors,
    required double breathe,
  }) {
    final scale = lerpDouble(1.0, 1.08, breathe);
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Transform.scale(
        scale: scale,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              colors: [...colors, Colors.transparent],
              stops: const [0.0, 0.55, 0.72],
            ),
          ),
        ),
      ),
    );
  }
}

double lerpDouble(num a, num b, double t) => a + (b - a) * t;
