import 'die.dart';
import 'geometry.dart';

/// A single die on the board, owned by player 0 (South) or 1 (North).
class Piece {
  const Piece({
    required this.owner,
    required this.die,
    required this.isKing,
  });

  /// 0 = South player (home row 8), 1 = North player (home row 0).
  final int owner;
  final Die die;

  /// The King die (the center piece). It may move only one square per turn, and
  /// capturing the opponent's King wins the game.
  final bool isKing;

  Piece withDie(Die d) => Piece(owner: owner, die: d, isKing: isKing);

  @override
  String toString() =>
      'Piece(p$owner top=${die.top}${isKing ? ' KING' : ''})';
}

/// An immutable snapshot of the whole game.
///
/// [applyMove] (in `rules.dart`) produces the next state; this class never
/// mutates. Positions with no piece are simply absent from [pieces].
class GameState {
  GameState({
    required Map<Position, Piece> pieces,
    required this.currentPlayer,
    required this.turnNumber,
    this.winner,
  }) : pieces = Map.unmodifiable(pieces);

  final Map<Position, Piece> pieces;

  /// Whose turn it is: 0 (South) or 1 (North).
  final int currentPlayer;

  /// Monotonic turn counter, starting at 0. Used as the sequence number for
  /// remote-mode turn links (see PLAN.md §5); local mode just increments it.
  final int turnNumber;

  /// null while the game is in progress, else the winning player's id.
  final int? winner;

  bool get isOver => winner != null;

  Piece? pieceAt(Position p) => pieces[p];

  int get otherPlayer => 1 - currentPlayer;

  /// All (position, piece) pairs owned by [player].
  Iterable<MapEntry<Position, Piece>> piecesOf(int player) =>
      pieces.entries.where((e) => e.value.owner == player);

  GameState copyWith({
    Map<Position, Piece>? pieces,
    int? currentPlayer,
    int? turnNumber,
    int? winner,
    bool clearWinner = false,
  }) {
    return GameState(
      pieces: pieces ?? this.pieces,
      currentPlayer: currentPlayer ?? this.currentPlayer,
      turnNumber: turnNumber ?? this.turnNumber,
      winner: clearWinner ? null : (winner ?? this.winner),
    );
  }
}
