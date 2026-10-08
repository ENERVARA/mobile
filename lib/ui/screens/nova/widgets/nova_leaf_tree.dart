import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../data/constants/nova_leaves.dart';
import '../../../widgets/entrance.dart';

// Accumulated downward scroll (px) needed to reveal one more leaf. Tuned so a
// handful of exchanges fills a few leaves and a long conversation completes the
// crown — not tied to the scroll extent, which would keep moving the target as
// the thread grows.
const double _pxPerLeaf = 46;
final int _totalLeaves = kNovaLeaves.length;

/// The bare tree plus its individually-cropped leaf sprites, grown in as the
/// chat thread scrolls down — both from new messages auto-scrolling and from the
/// user scrolling manually, anything that moves the offset down — and retracted
/// scrolling back up. An accumulator of net downward scroll, so it never fights
/// the thread's own growing extent. Ported from `NovaLeafTree.tsx`.
///
/// Sits behind the message list inside the thread surface; both share the one
/// [controller], so there is a single source of scroll truth.
class NovaLeafTree extends StatefulWidget {
  final ScrollController controller;
  const NovaLeafTree({super.key, required this.controller});

  @override
  State<NovaLeafTree> createState() => _NovaLeafTreeState();
}

class _NovaLeafTreeState extends State<NovaLeafTree> {
  double _lastTop = 0;
  double _depthPx = 0;
  int _revealed = 0;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(covariant NovaLeafTree old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.controller.hasClients) return;
    final top = widget.controller.offset;
    _depthPx = math.min(_totalLeaves * _pxPerLeaf, math.max(0.0, _depthPx + (top - _lastTop)));
    _lastTop = top;
    final next = math.min(_totalLeaves, (_depthPx / _pxPerLeaf).floor());
    if (next != _revealed) setState(() => _revealed = next);
  }

  @override
  Widget build(BuildContext context) {
    // `.nova-tree-wrap`: inset 10px on every side, half opacity, no pointer events.
    return Positioned.fill(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: IgnorePointer(
          child: Opacity(
            opacity: 0.5,
            child: LayoutBuilder(
              builder: (context, c) {
                // Mirrors `background-size: contain` for a 1:1 image, anchored
                // bottom-center.
                final size = math.min(c.maxWidth, c.maxHeight);
                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: (c.maxWidth - size) / 2,
                      top: c.maxHeight - size,
                      width: size,
                      height: size,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: Image.asset(
                              'assets/images/nova/tree.png',
                              fit: BoxFit.fill,
                              filterQuality: FilterQuality.medium,
                            ),
                          ),
                          for (var i = 0; i < kNovaLeaves.length; i++)
                            Positioned(
                              left: kNovaLeaves[i].xPct / 100 * size,
                              top: kNovaLeaves[i].yPct / 100 * size,
                              width: kNovaLeaves[i].wPct / 100 * size,
                              height: kNovaLeaves[i].hPct / 100 * size,
                              child: _Leaf(
                                leaf: kNovaLeaves[i],
                                shown: i < _revealed,
                                // Later leaves lag slightly behind earlier ones so a
                                // burst of scroll doesn't pop every newly-revealed
                                // leaf in unison.
                                delay: Duration(milliseconds: math.min(i, _totalLeaves - 1 - i) * 6),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// One leaf sprite. Revealed leaves rise up into place from just below their
/// slot; hidden ones sink back down and fade — both directions share one slow,
/// smooth curve (1.15s spring) so scrolling either way reads as continuous growth.
class _Leaf extends StatefulWidget {
  final NovaLeaf leaf;
  final bool shown;
  final Duration delay;
  const _Leaf({required this.leaf, required this.shown, required this.delay});

  @override
  State<_Leaf> createState() => _LeafState();
}

class _LeafState extends State<_Leaf> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1150),
  );
  late final Animation<double> _x = CurvedAnimation(
    parent: _c,
    curve: kEaseSpring,
    // A CSS transition eases out in both directions; flip the curve so the
    // retraction also starts fast and settles slowly.
    reverseCurve: kEaseSpring.flipped,
  );
  Timer? _pending;

  @override
  void initState() {
    super.initState();
    if (widget.shown) _c.value = 1;
  }

  @override
  void didUpdateWidget(covariant _Leaf old) {
    super.didUpdateWidget(old);
    if (old.shown == widget.shown) return;
    _pending?.cancel();
    void go() {
      if (!mounted) return;
      widget.shown ? _c.forward() : _c.reverse();
    }

    if (widget.delay == Duration.zero) {
      go();
    } else {
      _pending = Timer(widget.delay, go);
    }
  }

  @override
  void dispose() {
    _pending?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _x,
      builder: (context, _) {
        final x = _x.value;
        if (x <= 0) return const SizedBox.shrink();
        return LayoutBuilder(
          builder: (context, c) => Opacity(
            opacity: x.clamp(0.0, 1.0),
            // `translateY(55%) scale(.85)` → rest, about the bottom-centre.
            child: Transform.translate(
              offset: Offset(0, (1 - x) * 0.55 * c.maxHeight),
              child: Transform.scale(
                scale: 0.85 + 0.15 * x,
                alignment: Alignment.bottomCenter,
                child: Image.asset(
                  widget.leaf.asset,
                  fit: BoxFit.fill,
                  filterQuality: FilterQuality.medium,
                  gaplessPlayback: true,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
