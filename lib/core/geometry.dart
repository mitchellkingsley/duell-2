/// Board geometry: directions and positions.
///
/// The board is a 9x9 grid. We use (col, row) with row 0 at the NORTH edge
/// (top of the board / far side) and row 8 at the SOUTH edge (near side).
/// Column 0 is the WEST edge, column 8 the EAST edge.
///
/// These are ABSOLUTE board directions — they do not depend on which player
/// owns a die. Die movement physics (see [Die]) are defined in these terms,
/// matching the `resources/duell-moves.json` reference tables (die physics are
/// independent of board size).
library;

const int kBoardSize = 9;

/// A board direction. `dCol`/`dRow` give the one-square offset.
enum Direction {
  north(0, -1, 'N'),
  south(0, 1, 'S'),
  east(1, 0, 'E'),
  west(-1, 0, 'W');

  const Direction(this.dCol, this.dRow, this.code);

  final int dCol;
  final int dRow;

  /// Single-letter code used in move notation (e.g. `N`, `E`) and in the
  /// `duell-moves.json` path orders.
  final String code;

  Direction get opposite => switch (this) {
        Direction.north => Direction.south,
        Direction.south => Direction.north,
        Direction.east => Direction.west,
        Direction.west => Direction.east,
      };

  static Direction fromCode(String c) =>
      Direction.values.firstWhere((d) => d.code == c);
}

/// An immutable board square.
class Position {
  const Position(this.col, this.row);

  final int col;
  final int row;

  bool get onBoard =>
      col >= 0 && col < kBoardSize && row >= 0 && row < kBoardSize;

  Position step(Direction d) => Position(col + d.dCol, row + d.dRow);

  Position translate(int dCol, int dRow) => Position(col + dCol, row + dRow);

  @override
  bool operator ==(Object other) =>
      other is Position && other.col == col && other.row == row;

  @override
  int get hashCode => col * 31 + row;

  @override
  String toString() => '($col,$row)';
}
