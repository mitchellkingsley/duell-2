import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/die.dart';
import '../core/geometry.dart';

/// A faux-3D die drawn in a single [CustomPainter]: the 8 cube vertices are
/// rotated by [tumble], projected orthographically, back-face culled, and each
/// visible face is filled as a polygon (pips or the King icon drawn onto it).
///
/// Drawing the cube as real polygons in one canvas — rather than six separate
/// transformed widget layers — keeps adjacent faces sharing exact vertices, so
/// the face rotating up to become the new top grows smoothly from the shared
/// edge instead of popping in at 90°.
///
/// [tumble]'s rotation signs (see [stepRotation]) are chosen so a 90° roll
/// brings the correct face to the top, matching the engine's [Die.roll].
class Cube3D extends StatelessWidget {
  const Cube3D({
    super.key,
    required this.die,
    required this.color,
    this.isKing = false,
    this.kingIcon,
    this.tumble,
  });

  final Die die;
  final Color color;
  final bool isKing;

  /// When this is the King, the icon shown on every face instead of pips (the
  /// King's number is meaningless since it always moves one square).
  final IconData? kingIcon;

  final Matrix4? tumble;

  /// World-space rotation for a single 90° tumble in [d] at [angle] radians
  /// (0..π/2). Signs are chosen so the resulting top face equals
  /// `die.roll(d).top` — i.e. the animation and the engine agree.
  static Matrix4 stepRotation(Direction d, double angle) {
    switch (d) {
      case Direction.north:
        return Matrix4.rotationX(angle);
      case Direction.south:
        return Matrix4.rotationX(-angle);
      case Direction.east:
        return Matrix4.rotationY(angle);
      case Direction.west:
        return Matrix4.rotationY(-angle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _CubePainter(
        die: die,
        color: color,
        isKing: isKing,
        kingIcon: kingIcon,
        tumble: tumble ?? Matrix4.identity(),
      ),
    );
  }
}

/// Pip positions on a face, in face UV space [0,1]².
const Map<int, List<Offset>> _pips = {
  1: [Offset(0.5, 0.5)],
  2: [Offset(0.3, 0.3), Offset(0.7, 0.7)],
  3: [Offset(0.3, 0.3), Offset(0.5, 0.5), Offset(0.7, 0.7)],
  4: [Offset(0.3, 0.3), Offset(0.7, 0.3), Offset(0.3, 0.7), Offset(0.7, 0.7)],
  5: [
    Offset(0.3, 0.3),
    Offset(0.7, 0.3),
    Offset(0.5, 0.5),
    Offset(0.3, 0.7),
    Offset(0.7, 0.7),
  ],
  6: [
    Offset(0.26, 0.25),
    Offset(0.26, 0.5),
    Offset(0.26, 0.75),
    Offset(0.74, 0.25),
    Offset(0.74, 0.5),
    Offset(0.74, 0.75),
  ],
};

class _CubePainter extends CustomPainter {
  _CubePainter({
    required this.die,
    required this.color,
    required this.isKing,
    required this.kingIcon,
    required this.tumble,
  });

  final Die die;
  final Color color;
  final bool isKing;
  final IconData? kingIcon;
  final Matrix4 tumble;

  // Local cube vertices, indexed 0..7 by (x, y, z) sign bits. x=east, y=south
  // (down on screen), z=toward the viewer.
  static const List<List<int>> _vSigns = [
    [-1, -1, -1], // 0
    [1, -1, -1], //  1
    [1, 1, -1], //   2
    [-1, 1, -1], //  3
    [-1, -1, 1], //  4
    [1, -1, 1], //   5
    [1, 1, 1], //    6
    [-1, 1, 1], //   7
  ];

  // Each face: the 4 vertex indices (a quad loop) and its outward normal.
  // The value shown is resolved from [die] in paint().
  static const List<List<int>> _faceVerts = [
    [4, 5, 6, 7], // top    (+z)
    [1, 0, 3, 2], // bottom (-z)
    [0, 1, 5, 4], // north  (-y)
    [3, 7, 6, 2], // south  (+y)
    [1, 2, 6, 5], // east   (+x)
    [0, 4, 7, 3], // west   (-x)
  ];
  static const List<List<int>> _faceNormals = [
    [0, 0, 1],
    [0, 0, -1],
    [0, -1, 0],
    [0, 1, 0],
    [1, 0, 0],
    [-1, 0, 0],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final h = s * 0.5 * 0.9; // half-edge (0.9 = fill fraction)
    final center = Offset(size.width / 2, size.height / 2);

    double e(int r, int c) => tumble.entry(r, c);

    // Rotate + orthographically project each vertex.
    final pts = <Offset>[];
    final depths = <double>[];
    for (final sign in _vSigns) {
      final x = sign[0] * h, y = sign[1] * h, z = sign[2] * h;
      final rx = e(0, 0) * x + e(0, 1) * y + e(0, 2) * z;
      final ry = e(1, 0) * x + e(1, 1) * y + e(1, 2) * z;
      final rz = e(2, 0) * x + e(2, 1) * y + e(2, 2) * z;
      pts.add(center + Offset(rx, ry));
      depths.add(rz);
    }

    final faceValues = [
      die.top,
      die.bottom,
      die.north,
      die.south,
      die.east,
      die.west,
    ];

    // Visible (front-facing) faces, sorted far-to-near.
    final visible = <int>[];
    for (var f = 0; f < 6; f++) {
      final n = _faceNormals[f];
      final nz = e(2, 0) * n[0] + e(2, 1) * n[1] + e(2, 2) * n[2];
      if (nz > 1e-4) visible.add(f);
    }
    visible.sort((a, b) {
      double d(int f) =>
          _faceVerts[f].map((i) => depths[i]).reduce((x, y) => x + y);
      return d(a).compareTo(d(b));
    });

    final fill = Paint()
      ..color = color
      ..isAntiAlias = true;

    for (final f in visible) {
      final vi = _faceVerts[f];
      final c0 = pts[vi[0]], c1 = pts[vi[1]], c2 = pts[vi[2]], c3 = pts[vi[3]];

      final path = Path()
        ..moveTo(c0.dx, c0.dy)
        ..lineTo(c1.dx, c1.dy)
        ..lineTo(c2.dx, c2.dy)
        ..lineTo(c3.dx, c3.dy)
        ..close();
      canvas.drawPath(path, fill);

      // Bilinear map from face UV (c0=00, c1=10, c2=11, c3=01) to screen.
      Offset uv(double u, double v) {
        final top = Offset.lerp(c0, c1, u)!;
        final bot = Offset.lerp(c3, c2, u)!;
        return Offset.lerp(top, bot, v)!;
      }

      final wAvg = ((c1 - c0).distance + (c2 - c3).distance) / 2;
      final hAvg = ((c3 - c0).distance + (c2 - c1).distance) / 2;
      final faceMin = math.min(wAvg, hAvg);

      if (isKing) {
        _drawRing(canvas, uv);
        if (kingIcon != null) {
          _drawIcon(canvas, uv(0.5, 0.5), faceMin);
          continue;
        }
      }
      _drawPips(canvas, faceValues[f], uv, faceMin);
    }
  }

  void _drawPips(
      Canvas canvas, int value, Offset Function(double, double) uv, double faceMin) {
    final pip = Paint()..color = Colors.white;
    final r = faceMin * 0.081;
    for (final p in _pips[value] ?? const <Offset>[]) {
      canvas.drawCircle(uv(p.dx, p.dy), r, pip);
    }
  }

  void _drawRing(Canvas canvas, Offset Function(double, double) uv) {
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..color = Colors.amber.shade500;
    final path = Path()
      ..moveTo(uv(0.14, 0.14).dx, uv(0.14, 0.14).dy)
      ..lineTo(uv(0.86, 0.14).dx, uv(0.86, 0.14).dy)
      ..lineTo(uv(0.86, 0.86).dx, uv(0.86, 0.86).dy)
      ..lineTo(uv(0.14, 0.86).dx, uv(0.14, 0.86).dy)
      ..close();
    canvas.drawPath(path, ring);
  }

  void _drawIcon(Canvas canvas, Offset at, double faceMin) {
    final tp = TextPainter(
      textDirection: TextDirection.ltr,
      text: TextSpan(
        text: String.fromCharCode(kingIcon!.codePoint),
        style: TextStyle(
          fontSize: faceMin * 0.62,
          fontFamily: kingIcon!.fontFamily,
          package: kingIcon!.fontPackage,
          color: Colors.white,
        ),
      ),
    )..layout();
    tp.paint(canvas, at - Offset(tp.width / 2, tp.height / 2));
  }

  @override
  bool shouldRepaint(_CubePainter old) =>
      old.die != die ||
      old.color != color ||
      old.isKing != isKing ||
      old.kingIcon != kingIcon ||
      old.tumble != tumble;
}
