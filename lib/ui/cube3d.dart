import 'package:flutter/material.dart';

import '../core/die.dart';
import '../core/geometry.dart';

/// A faux-3D die rendered as a six-faced cube via `Transform`/`Matrix4`
/// (PLAN.md §7). No 3D engine — just perspective-projected flat faces, so it
/// runs identically on web and Android.
///
/// Pass [tumble] to rotate the whole cube in board space (used by the roll
/// animation); at rest it is identity and only the gentle view tilt applies.
/// Because the faces are placed according to the die's semantics, a physically
/// correct 90° [tumble] about the right axis brings the correct face to the top
/// — matching the engine's [Die.roll].
class Cube3D extends StatelessWidget {
  const Cube3D({
    super.key,
    required this.die,
    required this.color,
    this.isKing = false,
    this.tumble,
  });

  final Die die;
  final Color color;
  final bool isKing;
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
    return LayoutBuilder(
      builder: (context, c) {
        final box = c.biggest.shortestSide;
        final fs = box * 0.86; // face edge
        final h = fs / 2; // half-cube

        // Orthographic, straight top-down: no perspective, no view tilt. At rest
        // (tumble == identity) only the top face is visible; sides are edge-on.
        final parent = tumble ?? Matrix4.identity();

        const halfPi = 1.5707963267948966;

        // Each face: its outward-center in cube space, placement transform, pips.
        final specs = <_FaceSpec>[
          _FaceSpec(0.0, 0.0, -h,
              Matrix4.identity()..translateByDouble(0.0, 0.0, -h, 1.0),
              die.bottom),
          _FaceSpec(0.0, -h, 0.0,
              Matrix4.identity()
                ..translateByDouble(0.0, -h, 0.0, 1.0)
                ..rotateX(-halfPi),
              die.north),
          _FaceSpec(-h, 0.0, 0.0,
              Matrix4.identity()
                ..translateByDouble(-h, 0.0, 0.0, 1.0)
                ..rotateY(-halfPi),
              die.west),
          _FaceSpec(h, 0.0, 0.0,
              Matrix4.identity()
                ..translateByDouble(h, 0.0, 0.0, 1.0)
                ..rotateY(halfPi),
              die.east),
          _FaceSpec(0.0, h, 0.0,
              Matrix4.identity()
                ..translateByDouble(0.0, h, 0.0, 1.0)
                ..rotateX(halfPi),
              die.south),
          _FaceSpec(0.0, 0.0, h,
              Matrix4.identity()..translateByDouble(0.0, 0.0, h, 1.0),
              die.top,
              king: isKing),
        ];

        // Painter's algorithm without a z-buffer: draw back-to-front by the
        // face-center's depth after the tumble rotation.
        double depth(_FaceSpec f) => parent.entry(2, 0) * f.cx +
            parent.entry(2, 1) * f.cy +
            parent.entry(2, 2) * f.cz;
        specs.sort((a, b) => depth(a).compareTo(depth(b)));

        return Center(
          child: Transform(
            alignment: Alignment.center,
            transform: parent,
            child: Stack(
              alignment: Alignment.center,
              children: [
                for (final s in specs)
                  _face(fs, s.transform, s.value, king: s.king),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _face(double fs, Matrix4 m, int value, {bool king = false}) {
    return Transform(
      alignment: Alignment.center,
      transform: m,
      child: SizedBox(
        width: fs,
        height: fs,
        child: CustomPaint(
          painter: _CubeFacePainter(value: value, color: color, king: king),
        ),
      ),
    );
  }
}

/// One cube face: its outward-center in cube space (for depth sorting), its
/// placement transform, and the pip value it shows.
class _FaceSpec {
  _FaceSpec(this.cx, this.cy, this.cz, this.transform, this.value,
      {this.king = false});

  final double cx;
  final double cy;
  final double cz;
  final Matrix4 transform;
  final int value;
  final bool king;
}

class _CubeFacePainter extends CustomPainter {
  _CubeFacePainter({
    required this.value,
    required this.color,
    required this.king,
  });

  final int value;
  final Color color;
  final bool king;

  static const Map<int, List<Offset>> _pips = {
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
      Offset(0.3, 0.25),
      Offset(0.7, 0.25),
      Offset(0.3, 0.5),
      Offset(0.7, 0.5),
      Offset(0.3, 0.75),
      Offset(0.7, 0.75),
    ],
  };

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, s, s),
      Radius.circular(s * 0.12),
    );
    canvas.drawRRect(rect, Paint()..color = color);
    canvas.drawRRect(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = s * 0.04
        ..color = Colors.black.withValues(alpha: 0.5),
    );
    if (king) {
      canvas.drawRRect(
        rect.deflate(s * 0.08),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = s * 0.06
          ..color = Colors.amber.shade500,
      );
    }
    final pipPaint = Paint()..color = Colors.white;
    for (final p in _pips[value] ?? const <Offset>[]) {
      canvas.drawCircle(Offset(p.dx * s, p.dy * s), s * 0.09, pipPaint);
    }
  }

  @override
  bool shouldRepaint(_CubeFacePainter old) =>
      old.value != value || old.color != color || old.king != king;
}
