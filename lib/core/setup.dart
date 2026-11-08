import 'board.dart';
import 'die.dart';
import 'geometry.dart';

/// Initial board setup.
///
/// Each player places 9 dice along their home row with the number **4 facing
/// inward** (toward the opponent). The **center die is the King** — it may move
/// only one square per turn, and capturing the opponent's King wins the game.
///
/// With 4 on the inward face, a die's top can only be 1, 2, 5, or 6 (3 is
/// forced onto the outward face, and 4 is used).
///
/// Coordinates: column 0 = WEST, column 8 = EAST; row 0 = NORTH edge,
/// row 8 = SOUTH edge. Player 0 (South) occupies row 8, player 1 (North) row 0.

/// Top faces for a home row, columns 0..8 (west to east): 5, 1, 2, 6, King,
/// 6, 2, 1, 5. The center (col 4) is the King, whose top is a placeholder — it
/// renders as an icon and moves one square regardless of orientation. Every
/// entry must be in {1, 2, 5, 6} (the only tops possible with 4 inward).
const List<int> kHomeRowTops = [5, 1, 2, 6, 1, 6, 2, 1, 5];

/// The King's column: the center of the 9-wide home row.
const int kKingCol = 4;

/// South player's home row index (near edge); North's is row 0.
const int kSouthHomeRow = kBoardSize - 1; // 8

/// Build the standard starting position. South (player 0) moves first by
/// default; callers may override [firstPlayer].
GameState initialGameState({int firstPlayer = 0}) {
  final pieces = <Position, Piece>{};

  for (var col = 0; col < kBoardSize; col++) {
    final top = kHomeRowTops[col];

    // South player (row 8): inward is NORTH, so north face = 4.
    pieces[Position(col, kSouthHomeRow)] = Piece(
      owner: 0,
      die: Die.withTopNorth(top, 4)!,
      isKing: col == kKingCol,
    );

    // North player (row 0): inward is SOUTH, so south face = 4.
    pieces[Position(col, 0)] = Piece(
      owner: 1,
      die: Die.withTopSouth(top, 4)!,
      isKing: col == kKingCol,
    );
  }

  return GameState(
    pieces: pieces,
    currentPlayer: firstPlayer,
    turnNumber: 0,
  );
}
