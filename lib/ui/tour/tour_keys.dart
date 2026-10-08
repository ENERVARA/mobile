import 'package:flutter/widgets.dart';

/// Registry of the [GlobalKey]s the product tour spotlights. The web tags real
/// elements with `data-tour="…"` attributes; here a widget that should be
/// highlightable attaches `key: TourKeys.of('start-care')` and the tour looks the
/// same id up to measure it. A step whose target isn't on screen is skipped.
class TourKeys {
  TourKeys._();

  static final Map<String, GlobalKey> _keys = {};

  static GlobalKey of(String id) =>
      _keys.putIfAbsent(id, () => GlobalKey(debugLabel: 'tour:$id'));

  /// The on-screen bounds of the target, or null when it isn't currently
  /// mounted / laid out.
  static Rect? rectOf(String id) {
    final ctx = _keys[id]?.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  /// The target's own corner radius is not discoverable from the render tree,
  /// so callers pass one; this just exposes whether the target is mounted.
  static bool isMounted(String id) => _keys[id]?.currentContext != null;
}
