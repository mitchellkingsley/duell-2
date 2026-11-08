import 'board.dart';
import 'board_codec.dart';
import 'geometry.dart';
import 'move.dart';

/// The Duell rules engine. Pure functions over [GameState]; no Flutter, no I/O.
class Rules {
  const Rules._();

  /// Number of squares a [piece] moves this turn: its top face, except the King
  /// always moves exactly one square.
  static int stepsFor(Piece piece) => piece.isKing ? 1 : piece.die.top;

  /// Every legal move for the piece at [from].
  ///
  /// Returns an empty list if there is no piece there, it is not that player's
  /// turn, or the game is over. Squares reachable by two different paths yield
  /// two [Move]s (they may leave different top faces — the strategic hint).
  static List<Move> reachableMoves(GameState state, Position from) {
    if (state.isOver) return const [];
    final piece = state.pieceAt(from);
    if (piece == null || piece.owner != state.currentPlayer) return const [];

    final n = stepsFor(piece);
    final moves = <Move>[];

    // Straight paths (no turn).
    for (final d in Direction.values) {
      final m = _walk(state, from, piece, [MoveSegment(d, n)]);
      if (m != null) moves.add(m);
    }

    // One-turn paths: k1 in d1, then k2 in a perpendicular d2, k1 + k2 == n.
    for (final d1 in Direction.values) {
      for (final d2 in Direction.values) {
        if (d2 == d1 || d2 == d1.opposite) continue; // 90° turns only
        for (var k1 = 1; k1 < n; k1++) {
          final k2 = n - k1;
          final m = _walk(
            state,
            from,
            piece,
            [MoveSegment(d1, k1), MoveSegment(d2, k2)],
          );
          if (m != null) moves.add(m);
        }
      }
    }

    return moves;
  }

  /// Walk a path square by square, enforcing: stay on board, no jumping over or
  /// through any piece, and the final square must be empty or an enemy (capture
  /// by exact count). Returns the resolved [Move], or null if illegal.
  static Move? _walk(
    GameState state,
    Position from,
    Piece piece,
    List<MoveSegment> segments,
  ) {
    final totalSteps = segments.fold<int>(0, (a, s) => a + s.count);
    if (totalSteps == 0) return null;

    var die = piece.die;
    var pos = from;
    var stepIndex = 0;
    var captures = false;

    for (final seg in segments) {
      for (var i = 0; i < seg.count; i++) {
        pos = pos.step(seg.direction);
        if (!pos.onBoard) return null;
        die = die.roll(seg.direction);
        stepIndex++;

        final occupant = state.pieceAt(pos);
        if (occupant != null) {
          final isFinal = stepIndex == totalSteps;
          if (!isFinal) return null; // cannot jump over / pass through
          if (occupant.owner == piece.owner) return null; // no friendly landing
          captures = true;
        }
      }
    }

    return Move(
      from: from,
      to: pos,
      path: segments,
      resultDie: die,
      capturesOpponent: captures,
    );
  }

  /// Validate a candidate [move] against [state] (used for remote-mode links).
  ///
  /// Re-derives the move from its own path and confirms it exactly matches a
  /// legal move: correct owner/turn, correct distance, legal path, same
  /// destination and resulting orientation.
  static bool isLegal(GameState state, Move move) {
    if (state.isOver) return false;
    final piece = state.pieceAt(move.from);
    if (piece == null || piece.owner != state.currentPlayer) return false;

    final n = stepsFor(piece);
    final pathSteps = move.path.fold<int>(0, (a, s) => a + s.count);
    if (pathSteps != n) return false;
    if (move.path.isEmpty || move.path.length > 2) return false;
    if (move.path.length == 2) {
      final a = move.path[0].direction;
      final b = move.path[1].direction;
      if (b == a || b == a.opposite) return false; // must be a 90° turn
    }

    final resolved = _walk(state, move.from, piece, move.path);
    if (resolved == null) return false;
    return resolved.to == move.to && resolved.resultDie == move.resultDie;
  }

  /// Given [current] and a received [target] board, find the single legal move
  /// by the player to move that transforms [current] into [target], or null if
  /// no such move exists (illegal, out of sequence, or no change).
  ///
  /// Used for link play, where the whole board is transmitted: we diff to find
  /// the moved die (and a captured die), then confirm the transition is a real
  /// legal move whose tumble yields the stated orientation — so the receiver's
  /// engine stays the referee even though only the board was sent.
  static Move? resolveToTarget(
      GameState current, Map<Position, BoardCell> target) {
    if (current.isOver) return null;
    final mover = current.currentPlayer;

    final fromMover = <Position>[]; // mover squares that emptied/changed
    final fromOther = <Position>[]; // opponent squares removed (capture)
    final toMover = <Position>[]; // squares now holding the mover

    final squares = {...current.pieces.keys, ...target.keys};
    for (final pos in squares) {
      final pc = current.pieceAt(pos);
      final tc = target[pos];
      if (pc == null && tc == null) continue;
      if (pc != null && tc != null && _cellMatches(pc, tc)) continue;
      if (pc != null) (pc.owner == mover ? fromMover : fromOther).add(pos);
      if (tc != null) {
        if (tc.team != mover) return null; // only the mover may appear/change
        toMover.add(pos);
      }
    }

    if (fromMover.length != 1 || toMover.length != 1) return null;
    final from = fromMover.first;
    final to = toMover.first;
    if (fromOther.length > 1) return null;
    if (fromOther.length == 1 && fromOther.first != to) return null;

    final tc = target[to]!;
    final moved = current.pieceAt(from)!;
    final capturing = current.pieceAt(to)?.owner == 1 - mover;

    for (final m in reachableMoves(current, from)) {
      if (m.to != to) continue;
      if (m.capturesOpponent != capturing) continue;
      if (moved.isKing) {
        if (!tc.isKing) continue;
      } else {
        if (tc.isKing || tc.die != m.resultDie) continue;
      }
      return m;
    }
    return null;
  }

  static bool _cellMatches(Piece p, BoardCell c) =>
      p.owner == c.team &&
      p.isKing == c.isKing &&
      (c.isKing || p.die == c.die);

  /// Apply [move], returning the next [GameState]. Assumes [move] is legal
  /// (as produced by [reachableMoves] or checked with [isLegal]).
  ///
  /// Handles capture, the King-capture win, turn increment, and handing the
  /// turn to the other player.
  static GameState applyMove(GameState state, Move move) {
    final piece = state.pieceAt(move.from)!;
    final captured = state.pieceAt(move.to);

    final next = Map<Position, Piece>.of(state.pieces);
    next.remove(move.from);
    next[move.to] = piece.withDie(move.resultDie);

    int? winner;
    if (captured != null && captured.isKing) {
      winner = piece.owner; // captured the opponent's King — game over
    }

    return GameState(
      pieces: next,
      currentPlayer: winner != null ? state.currentPlayer : state.otherPlayer,
      turnNumber: state.turnNumber + 1,
      winner: winner,
    );
  }

  /// All legal moves for the player to move, grouped by origin square.
  static Map<Position, List<Move>> allMoves(GameState state) {
    final out = <Position, List<Move>>{};
    for (final entry in state.piecesOf(state.currentPlayer)) {
      final moves = reachableMoves(state, entry.key);
      if (moves.isNotEmpty) out[entry.key] = moves;
    }
    return out;
  }
}
