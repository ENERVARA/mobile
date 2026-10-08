import 'dart:ui';

/// Parses SVG path data (the `d` attribute) into a Flutter [Path].
///
/// Supports every path command — M L H V C S Q T A Z in absolute and relative
/// form — including implicit command repetition and the compact arc-flag syntax
/// (`a1 1 0 011 1`). Used for icons that exist as raw SVG paths on the web
/// (react-icons) but have no Phosphor equivalent.
Path parseSvgPath(String d) {
  final path = Path();
  final r = _Reader(d);

  var x = 0.0, y = 0.0; // current point
  var startX = 0.0, startY = 0.0; // start of the current subpath
  var lastCubicX = 0.0, lastCubicY = 0.0; // last cubic control point (for S)
  var lastQuadX = 0.0, lastQuadY = 0.0; // last quadratic control point (for T)
  String? cmd;
  var prev = '';

  while (true) {
    r.skipSeparators();
    if (r.done) break;
    if (r.atCommand) {
      cmd = r.takeCommand();
    } else if (cmd == null || cmd == 'Z' || cmd == 'z') {
      break; // numbers without a command to apply them to
    }
    final c = cmd;
    final rel = c.toLowerCase() == c;

    switch (c.toLowerCase()) {
      case 'm':
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.moveTo(nx, ny);
        x = startX = nx;
        y = startY = ny;
        // Further coordinate pairs after a moveto are implicit linetos.
        cmd = rel ? 'l' : 'L';
      case 'l':
        x = r.number() + (rel ? x : 0);
        y = r.number() + (rel ? y : 0);
        path.lineTo(x, y);
      case 'h':
        x = r.number() + (rel ? x : 0);
        path.lineTo(x, y);
      case 'v':
        y = r.number() + (rel ? y : 0);
        path.lineTo(x, y);
      case 'c':
        final x1 = r.number() + (rel ? x : 0);
        final y1 = r.number() + (rel ? y : 0);
        final x2 = r.number() + (rel ? x : 0);
        final y2 = r.number() + (rel ? y : 0);
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lastCubicX = x2;
        lastCubicY = y2;
        x = nx;
        y = ny;
      case 's':
        final reflect = 'cs'.contains(prev.toLowerCase()) && prev.isNotEmpty;
        final x1 = reflect ? 2 * x - lastCubicX : x;
        final y1 = reflect ? 2 * y - lastCubicY : y;
        final x2 = r.number() + (rel ? x : 0);
        final y2 = r.number() + (rel ? y : 0);
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.cubicTo(x1, y1, x2, y2, nx, ny);
        lastCubicX = x2;
        lastCubicY = y2;
        x = nx;
        y = ny;
      case 'q':
        final x1 = r.number() + (rel ? x : 0);
        final y1 = r.number() + (rel ? y : 0);
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.quadraticBezierTo(x1, y1, nx, ny);
        lastQuadX = x1;
        lastQuadY = y1;
        x = nx;
        y = ny;
      case 't':
        final reflect = 'qt'.contains(prev.toLowerCase()) && prev.isNotEmpty;
        final x1 = reflect ? 2 * x - lastQuadX : x;
        final y1 = reflect ? 2 * y - lastQuadY : y;
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.quadraticBezierTo(x1, y1, nx, ny);
        lastQuadX = x1;
        lastQuadY = y1;
        x = nx;
        y = ny;
      case 'a':
        final rx = r.number();
        final ry = r.number();
        final rotation = r.number();
        final largeArc = r.flag();
        final sweep = r.flag();
        final nx = r.number() + (rel ? x : 0);
        final ny = r.number() + (rel ? y : 0);
        path.arcToPoint(
          Offset(nx, ny),
          radius: Radius.elliptical(rx.abs(), ry.abs()),
          rotation: rotation,
          largeArc: largeArc,
          clockwise: sweep,
        );
        x = nx;
        y = ny;
      case 'z':
        path.close();
        x = startX;
        y = startY;
      default:
        return path; // unknown command — keep what was parsed
    }
    prev = c;
  }
  return path;
}

class _Reader {
  final String s;
  int i = 0;
  _Reader(this.s);

  static final _number = RegExp(r'[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?');

  bool get done => i >= s.length;

  void skipSeparators() {
    while (i < s.length) {
      final c = s.codeUnitAt(i);
      // whitespace or comma
      if (c == 0x20 || c == 0x2C || c == 0x0A || c == 0x0D || c == 0x09) {
        i++;
      } else {
        break;
      }
    }
  }

  bool get atCommand {
    final c = s[i];
    return RegExp(r'[MmLlHhVvCcSsQqTtAaZz]').hasMatch(c);
  }

  String takeCommand() => s[i++];

  double number() {
    skipSeparators();
    final m = _number.matchAsPrefix(s, i);
    if (m == null) throw FormatException('Bad SVG path number at $i', s, i);
    i = m.end;
    return double.parse(m.group(0)!);
  }

  /// Arc flags are a single `0` or `1` and may be written without separators.
  bool flag() {
    skipSeparators();
    final c = s[i++];
    if (c != '0' && c != '1') throw FormatException('Bad SVG arc flag at ${i - 1}', s, i - 1);
    return c == '1';
  }
}
