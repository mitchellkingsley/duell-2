import 'dart:math';

import 'board.dart';
import 'die.dart';
import 'geometry.dart';

/// Compact board-state encoding for link play.
///
/// A turn link carries the *whole board* (dice positions + orientations), not a
/// move delta. The receiver reconstructs the move by diffing against its own
/// board and confirming the transition is legal (see `Rules.resolveToTarget`).
///
/// Format: `<id><board>` where `id` is 4 URL-safe base64 characters and
/// `board` is row-prefixed groups:
///
///   board := (rowDigit (colDigit letter)+ )*
///
/// `letter` encodes team + orientation in one char:
///   - `a`..`x` : home team (player 0 / Blue), one of the 24 die orientations
///   - `A`..`X` : away team (player 1 / Red)
///   - `z` / `Z`: home / away **King** (orientation-agnostic placeholder)
///
/// Rows and columns are single digits (board is 9x9). The grammar parses
/// without a delimiter: a cell is always `digit`+`letter`, so a new row is
/// recognised by the extra leading digit before the next `digit letter` pair.

/// A decoded board cell: which team, whether it's the King, and (for a regular
/// die) its orientation. The King's orientation is not transmitted.
class BoardCell {
  const BoardCell({required this.team, required this.isKing, this.die});

  final int team; // 0 = home (Blue), 1 = away (Red)
  final bool isKing;
  final Die? die; // null for the King

  @override
  bool operator ==(Object other) =>
      other is BoardCell &&
      other.team == team &&
      other.isKing == isKing &&
      other.die == die;

  @override
  int get hashCode => Object.hash(team, isKing, die);
}

// Canonical ordering of the 24 orientations -> letters a..x (index 0..23).
// Both ends run the same code, so the mapping is consistent.
final List<Die> _orientations = Die.allOrientations;
final Map<Die, int> _orientationIndex = {
  for (var i = 0; i < _orientations.length; i++) _orientations[i]: i,
};

const int _ca = 97; // 'a'
const int _cz = 122; // 'z'
const int _cA = 65; // 'A'
const int _cZ = 90; // 'Z'
const int _c0 = 48; // '0'

String _letterFor(Piece p) {
  if (p.isKing) return p.owner == 0 ? 'z' : 'Z';
  final idx = _orientationIndex[p.die];
  if (idx == null || idx > 23) {
    throw StateError('die orientation not in canonical set');
  }
  final ch = String.fromCharCode(_ca + idx); // a..x
  return p.owner == 0 ? ch : ch.toUpperCase();
}

BoardCell _cellFor(String letter) {
  if (letter == 'z') return const BoardCell(team: 0, isKing: true);
  if (letter == 'Z') return const BoardCell(team: 1, isKing: true);
  final c = letter.codeUnitAt(0);
  if (c >= _ca && c <= _ca + 23) {
    return BoardCell(team: 0, isKing: false, die: _orientations[c - _ca]);
  }
  if (c >= _cA && c <= _cA + 23) {
    return BoardCell(team: 1, isKing: false, die: _orientations[c - _cA]);
  }
  throw const FormatException('invalid orientation letter');
}

/// Encode the full board as the board portion of a turn token.
String encodeBoard(GameState state) {
  final byRow = <int, List<MapEntry<Position, Piece>>>{};
  for (final e in state.pieces.entries) {
    byRow.putIfAbsent(e.key.row, () => []).add(e);
  }
  final rows = byRow.keys.toList()..sort();
  final sb = StringBuffer();
  for (final r in rows) {
    sb.writeCharCode(_c0 + r);
    final cells = byRow[r]!..sort((a, b) => a.key.col - b.key.col);
    for (final e in cells) {
      sb.writeCharCode(_c0 + e.key.col);
      sb.write(_letterFor(e.value));
    }
  }
  return sb.toString();
}

bool _isDigit(int c) => c >= _c0 && c <= _c0 + 9;
bool _isAlpha(int c) => (c >= _ca && c <= _cz) || (c >= _cA && c <= _cZ);

/// Decode the board portion into a map of occupied squares. Throws
/// [FormatException] on malformed input (bad chars, out-of-range, duplicates,
/// or a row with no cells).
Map<Position, BoardCell> decodeBoard(String board) {
  final out = <Position, BoardCell>{};
  var i = 0;
  while (i < board.length) {
    final rowC = board.codeUnitAt(i);
    if (!_isDigit(rowC)) throw const FormatException('expected row digit');
    final row = rowC - _c0;
    i++;
    var cellsInRow = 0;
    while (i + 1 < board.length &&
        _isDigit(board.codeUnitAt(i)) &&
        _isAlpha(board.codeUnitAt(i + 1))) {
      final col = board.codeUnitAt(i) - _c0;
      final letter = board[i + 1];
      i += 2;
      final pos = Position(col, row);
      if (!pos.onBoard) throw const FormatException('square off board');
      if (out.containsKey(pos)) throw const FormatException('duplicate square');
      out[pos] = _cellFor(letter);
      cellsInRow++;
    }
    if (cellsInRow == 0) throw const FormatException('empty row group');
  }
  return out;
}

/// A turn link: a 4-char game id plus the encoded board.
class BoardLink {
  const BoardLink({required this.id, required this.board});

  final String id;
  final String board;

  String encode() => '$id$board';

  /// Decode a bare token or a full URL carrying the token in `?t=` / `#t=`.
  static BoardLink? decode(String raw) {
    var t = raw.trim();
    final uri = Uri.tryParse(t);
    if (uri != null) {
      final q = uri.queryParameters['t'];
      if (q != null && q.isNotEmpty) {
        t = q;
      } else if (uri.fragment.startsWith('t=')) {
        t = uri.fragment.substring(2);
      }
    }
    if (t.length <= 4) return null;
    return BoardLink(id: t.substring(0, 4), board: t.substring(4));
  }
}

const _idAlphabet =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
final _rng = Random();

/// A new 4-character URL-safe base64 game id.
String newGameId() =>
    List.generate(4, (_) => _idAlphabet[_rng.nextInt(_idAlphabet.length)])
        .join();
