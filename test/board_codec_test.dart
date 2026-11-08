import 'package:duell/core/board.dart';
import 'package:duell/core/board_codec.dart';
import 'package:duell/core/die.dart';
import 'package:duell/core/geometry.dart';
import 'package:duell/core/rules.dart';
import 'package:duell/core/setup.dart';
import 'package:flutter_test/flutter_test.dart';

/// Expected decoded cells for a state (King orientation dropped).
Map<Position, BoardCell> cellsOf(GameState s) => {
      for (final e in s.pieces.entries)
        e.key: BoardCell(
          team: e.value.owner,
          isKing: e.value.isKing,
          die: e.value.isKing ? null : e.value.die,
        ),
    };

void main() {
  test('every orientation and the King get distinct letters', () {
    final letters = <String>{};
    for (final o in Die.allOrientations) {
      final home = encodeBoard(GameState(
        pieces: {const Position(0, 0): Piece(owner: 0, die: o, isKing: false)},
        currentPlayer: 0,
        turnNumber: 0,
      ));
      letters.add(home.substring(2)); // skip row+col digits
    }
    expect(letters.length, 24); // a..x, all distinct
    expect(letters.every((l) => l.codeUnitAt(0) >= 97 && l.codeUnitAt(0) <= 120),
        isTrue);
  });

  test('initial board round-trips through encode/decode', () {
    final s = initialGameState();
    final decoded = decodeBoard(encodeBoard(s));
    expect(decoded, equals(cellsOf(s)));
    // 18 pieces, two of them Kings (orientation-agnostic).
    expect(decoded.length, 18);
    expect(decoded.values.where((c) => c.isKing).length, 2);
  });

  test('King encodes as z / Z with no orientation', () {
    final s = GameState(
      pieces: {
        const Position(4, 8): Piece(owner: 0, die: Die.anchor, isKing: true),
        const Position(3, 0): Piece(owner: 1, die: Die.anchor, isKing: true),
      },
      currentPlayer: 0,
      turnNumber: 0,
    );
    final enc = encodeBoard(s);
    expect(enc.contains('z'), isTrue);
    expect(enc.contains('Z'), isTrue);
    final decoded = decodeBoard(enc);
    expect(decoded[const Position(4, 8)]!.isKing, isTrue);
    expect(decoded[const Position(4, 8)]!.die, isNull);
    expect(decoded[const Position(4, 8)]!.team, 0);
    expect(decoded[const Position(3, 0)]!.team, 1);
  });

  test('decode rejects malformed boards', () {
    expect(() => decodeBoard('4'), throwsFormatException); // empty row
    expect(() => decodeBoard('99a'), throwsFormatException); // off board
    expect(() => decodeBoard('40a0a'), throwsFormatException); // dup square
    expect(() => decodeBoard('4y'), throwsFormatException); // bad letter 'y'
  });

  group('BoardLink', () {
    test('encodes id + board and decodes back', () {
      final link = BoardLink(id: 'aB3_', board: '48c2A');
      expect(link.encode(), 'aB3_48c2A');
      final back = BoardLink.decode('aB3_48c2A')!;
      expect(back.id, 'aB3_');
      expect(back.board, '48c2A');
    });

    test('decodes from a URL token', () {
      final back = BoardLink.decode('https://decade.dev/t?t=aB3_48c2A')!;
      expect(back.id, 'aB3_');
      expect(back.board, '48c2A');
    });

    test('newGameId is 4 url-safe chars', () {
      final id = newGameId();
      expect(id.length, 4);
      expect(RegExp(r'^[A-Za-z0-9\-_]{4}$').hasMatch(id), isTrue);
    });
  });

  test('adoptBoard reconstructs the position for a fresh join', () {
    final s = initialGameState();
    // Advance a couple of moves so it's a mid-game board.
    final m1 = Rules.reachableMoves(s, const Position(0, kSouthHomeRow)).first;
    final s1 = Rules.applyMove(s, m1);
    final adopted =
        adoptBoard(decodeBoard(encodeBoard(s1)), currentPlayer: 1);
    // Same pieces/positions/orientations, and it's the joiner's (Red) turn.
    expect(encodeBoard(adopted), encodeBoard(s1));
    expect(adopted.currentPlayer, 1);
    expect(adopted.winner, isNull);
  });

  group('resolveToTarget (board → move)', () {
    test('reconstructs an opening move from the board', () {
      final s0 = initialGameState();
      final from = const Position(0, kSouthHomeRow);
      final move = Rules.reachableMoves(s0, from).first;
      final s1 = Rules.applyMove(s0, move);

      final target = decodeBoard(encodeBoard(s1));
      final resolved = Rules.resolveToTarget(s0, target);
      expect(resolved, isNotNull);
      expect(resolved!.to, move.to);
      // Applying the resolved move reproduces the sent board exactly.
      expect(encodeBoard(Rules.applyMove(s0, resolved)), encodeBoard(s1));
    });

    test('returns null when nothing moved', () {
      final s0 = initialGameState();
      expect(Rules.resolveToTarget(s0, cellsOf(s0)), isNull);
    });

    test('reconstructs a capturing move', () {
      const enemy = Position(3, 1);
      final pieces = <Position, Piece>{
        const Position(3, 4):
            Piece(owner: 0, die: Die.withTopNorth(3, 2)!, isKing: false),
        enemy: Piece(owner: 1, die: Die.anchor, isKing: false),
      };
      final s = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 0);
      final capture = Rules.reachableMoves(s, const Position(3, 4))
          .firstWhere((m) => m.to == enemy);
      final after = Rules.applyMove(s, capture);

      final resolved = Rules.resolveToTarget(s, decodeBoard(encodeBoard(after)));
      expect(resolved, isNotNull);
      expect(resolved!.capturesOpponent, isTrue);
      expect(resolved.to, enemy);
    });

    test('rejects a board that fakes an illegal jump', () {
      final s0 = initialGameState();
      // Teleport a South die to the far side — not reachable in one legal move.
      final pieces = Map<Position, Piece>.of(s0.pieces);
      final movedPiece = pieces.remove(const Position(0, kSouthHomeRow))!;
      pieces[const Position(0, 3)] = movedPiece;
      final fake = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 1);

      expect(Rules.resolveToTarget(s0, decodeBoard(encodeBoard(fake))), isNull);
    });
  });
}
