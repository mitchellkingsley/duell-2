import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/die.dart';
import '../core/geometry.dart';
import '../game/game_controller.dart';
import 'cube3d.dart';

/// One unit step of a tumble: the direction rolled, the orientation *before*
/// the roll, and the origin/destination cells for that step.
class _SubStep {
  _SubStep(this.dir, this.preDie, this.fromCell, this.toCell);
  final Direction dir;
  final Die preDie;
  final Position fromCell;
  final Position toCell;
}

/// Animates a committed move as a die tumbling one 90° roll per square along
/// its path (PLAN.md §8). Overlays the board; calls [onDone] when settled.
///
/// Because [Cube3D.stepRotation]'s signs match [Die.roll], the cube rendered
/// with the pre-step orientation at 90° equals the post-step orientation at 0°,
/// so steps chain seamlessly and the final face matches the engine's result.
class TumblingDie extends StatefulWidget {
  const TumblingDie({
    super.key,
    required this.anim,
    required this.cellSize,
    required this.color,
    required this.onDone,
    this.perStepMs = 150,
  });

  final TumbleAnim anim;
  final double cellSize;
  final Color color;
  final VoidCallback onDone;
  final int perStepMs;

  @override
  State<TumblingDie> createState() => _TumblingDieState();
}

class _TumblingDieState extends State<TumblingDie>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final List<_SubStep> _steps;

  @override
  void initState() {
    super.initState();
    _steps = _expand();
    _c = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: _steps.length * widget.perStepMs),
    );
    _c.addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    });
    _c.forward();
  }

  List<_SubStep> _expand() {
    final out = <_SubStep>[];
    var die = widget.anim.startDie;
    var cell = widget.anim.move.from;
    for (final seg in widget.anim.move.path) {
      for (var i = 0; i < seg.count; i++) {
        final next = cell.step(seg.direction);
        out.add(_SubStep(seg.direction, die, cell, next));
        die = die.roll(seg.direction);
        cell = next;
      }
    }
    return out;
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = _steps.length;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * n;
        final idx = t.floor().clamp(0, n - 1);
        final local = (t - idx).clamp(0.0, 1.0);
        final step = _steps[idx];

        final angle = local * (math.pi / 2);
        final tumble = Cube3D.stepRotation(step.dir, angle);

        final cs = widget.cellSize;
        final left = _lerp(step.fromCell.col, step.toCell.col, local) * cs;
        final top = _lerp(step.fromCell.row, step.toCell.row, local) * cs;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              width: cs,
              height: cs,
              child: Padding(
                padding: const EdgeInsets.all(3),
                child: Cube3D(
                  die: step.preDie,
                  color: widget.color,
                  isKing: widget.anim.isKing,
                  tumble: tumble,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  double _lerp(int a, int b, double t) => a + (b - a) * t;
}
