import 'die.dart';
import 'geometry.dart';

/// One straight leg of a move: tumble [count] squares in [direction].
class MoveSegment {
  const MoveSegment(this.direction, this.count);

  final Direction direction;
  final int count;

  @override
  String toString() => '${direction.code}$count';
}

/// A fully-resolved legal move for a single die.
///
/// A Duell move tumbles the die a number of squares equal to its current top
/// face, one square at a time, with at most one 90° turn (so [path] has one or
/// two segments). The same destination can sometimes be reached by two
/// different paths that leave the die showing *different* top faces — each is a
/// distinct [Move].
class Move {
  const Move({
    required this.from,
    required this.to,
    required this.path,
    required this.resultDie,
    required this.capturesOpponent,
  });

  final Position from;
  final Position to;
  final List<MoveSegment> path;

  /// The die's orientation after completing [path]. `resultDie.top` is the
  /// number that will show on top — the key strategic hint for the next turn.
  final Die resultDie;

  /// True if this move lands exactly on an opponent piece (a capture).
  final bool capturesOpponent;

  int get resultTop => resultDie.top;

  /// The first direction the die rolls — distinguishes the two routes that can
  /// reach the same square (used by the route chooser).
  Direction get firstDirection => path.first.direction;

  /// The squares the die passes through, in order, excluding [from] and
  /// including [to]. Useful for highlighting a route on the board.
  List<Position> routeCells() {
    final cells = <Position>[];
    var c = from;
    for (final seg in path) {
      for (var i = 0; i < seg.count; i++) {
        c = c.step(seg.direction);
        cells.add(c);
      }
    }
    return cells;
  }

  /// Path in `duell-moves.json` notation, e.g. `N2·E1`.
  String get notation => path.map((s) => s.toString()).join('·');

  @override
  String toString() => 'Move($from -> $to via $notation top=${resultDie.top}'
      '${capturesOpponent ? ' capture' : ''})';
}
