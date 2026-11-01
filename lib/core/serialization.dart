import 'board.dart';
import 'die.dart';
import 'geometry.dart';

/// JSON (de)serialization for game state, plus a deterministic state hash used
/// to detect desync between the two devices in link-based play (PLAN.md §5).
/// Pure Dart — no Flutter, no I/O.

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

/// A short, deterministic hash of the whole position. Two devices that have
/// applied the same move sequence produce the same hash; a mismatch means the
/// games have diverged.
String stateHash(GameState s) {
  final entries = s.pieces.entries.toList()
    ..sort((a, b) => a.key.row != b.key.row
        ? a.key.row - b.key.row
        : a.key.col - b.key.col);
  final buf = StringBuffer();
  for (final e in entries) {
    final d = e.value.die;
    // top + north fully determine orientation; include both for safety.
    buf.write('${e.key.col},${e.key.row}:${e.value.owner}:'
        '${e.value.isKing ? 1 : 0}:${d.top}.${d.north};');
  }
  buf.write('cp${s.currentPlayer}|t${s.turnNumber}|w${s.winner}');
  return _fnv1a32(buf.toString()).toRadixString(16);
}

int _fnv1a32(String s) {
  var h = 0x811c9dc5;
  for (final c in s.codeUnits) {
    h ^= c;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}
