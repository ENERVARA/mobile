import 'dart:math' as math;
import 'dart:ui' show Rect, Path, Radius, RRect, Size, PathFillType;

/// Pure geometry for the product tour. Ported from `features/tour/tourGeometry.ts`
/// — everything that can be computed from numbers lives here.

enum TourSide { top, bottom, left, right }

class TourPlacement {
  final double x;
  final double y;

  /// Which side of the target the bubble sits on; `null` = centred (no target).
  final TourSide? side;

  /// Offset of the bubble's tail along its edge, pointing at the target's centre.
  final double tail;
  const TourPlacement(this.x, this.y, this.side, this.tail);
}

double _round(double n) => (n * 100).roundToDouble() / 100;

Rect centerRect(double vw, double vh) => Rect.fromLTWH(vw / 2, vh / 2, 0, 0);

Rect padRect(Rect r, double pad) =>
    Rect.fromLTWH(r.left - pad, r.top - pad, r.width + pad * 2, r.height + pad * 2);

/// The largest centred square inside the rect — used to frame round things.
Rect squareRect(Rect r) {
  final side = math.min(r.width, r.height);
  return Rect.fromLTWH(r.left + (r.width - side) / 2, r.top + (r.height - side) / 2, side, side);
}

/// Intersects the rect with the viewport (inset by [margin]) so the frame never
/// leaves the screen.
Rect clampRect(Rect r, double vw, double vh, [double margin = 8]) {
  final x1 = math.max(r.left, margin);
  final y1 = math.max(r.top, margin);
  final x2 = math.min(r.right, vw - margin);
  final y2 = math.min(r.bottom, vh - margin);
  return Rect.fromLTWH(x1, y1, math.max(0, x2 - x1), math.max(0, y2 - y1));
}

bool rectsDiffer(Rect a, Rect b, [double epsilon = 0.5]) =>
    (a.left - b.left).abs() > epsilon ||
    (a.top - b.top).abs() > epsilon ||
    (a.width - b.width).abs() > epsilon ||
    (a.height - b.height).abs() > epsilon;

/// A path that keeps the whole viewport EXCEPT a rounded-rectangle hole
/// (even-odd fill). Used to clip a dimmed, blurred full-screen layer so the
/// highlighted area stays crisp and undimmed with correctly curved corners.
Path holePath(Size viewport, Rect r, double radius) {
  final rr = math.max(0.0, math.min(radius, math.min(r.width / 2, r.height / 2)));
  final path = Path()..fillType = PathFillType.evenOdd;
  path.addRect(Rect.fromLTWH(0, 0, viewport.width, viewport.height));
  path.addRRect(RRect.fromRectAndRadius(r, Radius.circular(rr)));
  return path;
}

/// Where the chat bubble goes. Tries the preferred sides in order and takes the
/// first with room for the whole bubble; if none fits, takes the side with the
/// most space and clamps into the viewport. No target → centred (welcome step).
TourPlacement placeBubble(
  Rect? target,
  Size size,
  Size vp,
  List<TourSide> prefer, {
  double gap = 18,
  double margin = 12,
}) {
  if (target == null) {
    return TourPlacement(
      _round((vp.width - size.width) / 2),
      _round((vp.height - size.height) / 2),
      null,
      0,
    );
  }

  final space = <TourSide, double>{
    TourSide.right: vp.width - margin - (target.right + gap),
    TourSide.left: target.left - gap - margin,
    TourSide.bottom: vp.height - margin - (target.bottom + gap),
    TourSide.top: target.top - gap - margin,
  };
  double need(TourSide s) => (s == TourSide.left || s == TourSide.right) ? size.width : size.height;
  const all = [TourSide.right, TourSide.left, TourSide.bottom, TourSide.top];

  TourSide? side;
  for (final s in prefer) {
    if (space[s]! >= need(s)) {
      side = s;
      break;
    }
  }
  side ??= ([...all]..sort((a, b) => space[b]!.compareTo(space[a]!))).first;

  double x;
  double y;
  switch (side) {
    case TourSide.right:
      x = target.right + gap;
      y = target.top + target.height / 2 - size.height / 2;
      break;
    case TourSide.left:
      x = target.left - gap - size.width;
      y = target.top + target.height / 2 - size.height / 2;
      break;
    case TourSide.bottom:
      y = target.bottom + gap;
      x = target.left + target.width / 2 - size.width / 2;
      break;
    case TourSide.top:
      y = target.top - gap - size.height;
      x = target.left + target.width / 2 - size.width / 2;
      break;
  }

  x = math.max(margin, math.min(x, vp.width - margin - size.width));
  y = math.max(margin, math.min(y, vp.height - margin - size.height));

  const edge = 18.0;
  double clampTail(double v, double length) => math.max(edge, math.min(v, length - edge));
  final tail = (side == TourSide.left || side == TourSide.right)
      ? clampTail(target.top + target.height / 2 - y, size.height)
      : clampTail(target.left + target.width / 2 - x, size.width);

  return TourPlacement(_round(x), _round(y), side, _round(tail));
}
