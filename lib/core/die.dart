import 'geometry.dart';

/// A die's orientation: the value on each of its six faces.
///
/// Opposite faces always sum to 7. The tumbling rules below define a single,
/// fixed chirality — the same one used to generate `resources/duell-moves.json`
/// (anchor orientation: top=1, north=4, east=5). Any orientation reachable by
/// [roll] shares that chirality, so the engine and the reference tables agree.
///
/// Immutable: [roll] returns a new [Die].
class Die {
  const Die({
    required this.top,
    required this.bottom,
    required this.north,
    required this.south,
    required this.east,
    required this.west,
  });

  final int top;
  final int bottom;
  final int north;
  final int south;
  final int east;
  final int west;

  /// The canonical anchor orientation (top=1, north=4). Matches the
  /// `startOrientation` for Top No. 1 in the reference tables.
  static const Die anchor = Die(
    top: 1,
    bottom: 6,
    north: 4,
    south: 3,
    east: 5,
    west: 2,
  );

  /// Tumble one square in [d], returning the resulting orientation.
  ///
  /// Mirrors the roll function used to generate the reference tables.
  Die roll(Direction d) => switch (d) {
        Direction.north => Die(
            top: south,
            bottom: north,
            north: top,
            south: bottom,
            east: east,
            west: west,
          ),
        Direction.south => Die(
            top: north,
            bottom: south,
            north: bottom,
            south: top,
            east: east,
            west: west,
          ),
        Direction.east => Die(
            top: west,
            bottom: east,
            north: north,
            south: south,
            east: top,
            west: bottom,
          ),
        Direction.west => Die(
            top: east,
            bottom: west,
            north: north,
            south: south,
            east: bottom,
            west: top,
          ),
      };

  /// All 24 valid orientations of this chirality, generated from [anchor].
  static final List<Die> allOrientations = _generateAll();

  static List<Die> _generateAll() {
    final seen = <Die>{};
    final queue = <Die>[anchor];
    while (queue.isNotEmpty) {
      final d = queue.removeLast();
      if (!seen.add(d)) continue;
      for (final dir in Direction.values) {
        queue.add(d.roll(dir));
      }
    }
    return seen.toList();
  }

  /// The unique orientation with the given [top] and [north] faces.
  /// Returns null if that combination is impossible (e.g. top and north
  /// being equal or opposite).
  static Die? withTopNorth(int top, int north) {
    for (final d in allOrientations) {
      if (d.top == top && d.north == north) return d;
    }
    return null;
  }

  /// The unique orientation with the given [top] and [south] faces.
  static Die? withTopSouth(int top, int south) {
    for (final d in allOrientations) {
      if (d.top == top && d.south == south) return d;
    }
    return null;
  }

  @override
  bool operator ==(Object other) =>
      other is Die &&
      other.top == top &&
      other.bottom == bottom &&
      other.north == north &&
      other.south == south &&
      other.east == east &&
      other.west == west;

  @override
  int get hashCode => Object.hash(top, bottom, north, south, east, west);

  @override
  String toString() =>
      'Die(top:$top n:$north e:$east s:$south w:$west b:$bottom)';
}
