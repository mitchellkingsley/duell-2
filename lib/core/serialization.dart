import 'board.dart';
import 'die.dart';
import 'geometry.dart';

/// JSON (de)serialization for game state, used to persist matches on the
/// device. Pure Dart — no Flutter, no I/O.

Map<String, dynamic> dieToJson(Die d) => {
      't': d.top,
      'b': d.bottom,
      'n': d.north,
      's': d.south,
      'e': d.east,
      'w': d.west,
    };

Die dieFromJson(Map<String, dynamic> j) => Die(
      top: j['t'] as int,
      bottom: j['b'] as int,
      north: j['n'] as int,
      south: j['s'] as int,
      east: j['e'] as int,
      west: j['w'] as int,
    );

Map<String, dynamic> pieceToJson(Piece p) => {
      'o': p.owner,
      'k': p.isKing,
      'd': dieToJson(p.die),
    };

Piece pieceFromJson(Map<String, dynamic> j) => Piece(
      owner: j['o'] as int,
      isKing: j['k'] as bool,
      die: dieFromJson((j['d'] as Map).cast<String, dynamic>()),
    );

Map<String, dynamic> gameStateToJson(GameState s) => {
      'cp': s.currentPlayer,
      'tn': s.turnNumber,
      'w': s.winner,
      'p': {
        for (final e in s.pieces.entries)
          '${e.key.col},${e.key.row}': pieceToJson(e.value),
      },
    };

GameState gameStateFromJson(Map<String, dynamic> j) {
  final pieces = <Position, Piece>{};
  final raw = (j['p'] as Map).cast<String, dynamic>();
  for (final e in raw.entries) {
    final parts = e.key.split(',');
    pieces[Position(int.parse(parts[0]), int.parse(parts[1]))] =
        pieceFromJson((e.value as Map).cast<String, dynamic>());
  }
  return GameState(
    pieces: pieces,
    currentPlayer: j['cp'] as int,
    turnNumber: j['tn'] as int,
    winner: j['w'] as int?,
  );
}
