import 'package:duell/core/board.dart';
import 'package:duell/core/die.dart';
import 'package:duell/core/geometry.dart';
import 'package:duell/core/move.dart';
import 'package:duell/core/rules.dart';
import 'package:duell/core/setup.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initial setup', () {
    final s = initialGameState();

    test('has 18 pieces, 9 per player on a 9x9 board', () {
      expect(kBoardSize, 9);
      expect(s.pieces.length, 18);
      expect(s.piecesOf(0).length, 9);
      expect(s.piecesOf(1).length, 9);
    });

    test('South dice have 4 facing inward (north), on the south home row', () {
      for (final e in s.piecesOf(0)) {
        expect(e.value.die.north, 4);
        expect(e.key.row, kSouthHomeRow); // row 8
      }
    });

    test('North dice have 4 facing inward (south), on row 0', () {
      for (final e in s.piecesOf(1)) {
        expect(e.value.die.south, 4);
        expect(e.key.row, 0);
      }
    });

    test('each player has exactly one King, at the center column', () {
      for (final player in [0, 1]) {
        final kings = s.piecesOf(player).where((e) => e.value.isKing).toList();
        expect(kings.length, 1);
        expect(kings.single.key.col, kKingCol); // column 4
      }
    });

    test('South moves first', () => expect(s.currentPlayer, 0));
  });

  group('move generation', () {
    test('a front die has legal opening moves of the right length', () {
      final s = initialGameState();
      final from = const Position(0, kSouthHomeRow);
      final moves = Rules.reachableMoves(s, from);
      expect(moves, isNotEmpty);
      final n = s.pieceAt(from)!.die.top;
      for (final m in moves) {
        final steps = m.path.fold<int>(0, (a, seg) => a + seg.count);
        expect(steps, n);
      }
    });

    test('cannot move an opponent piece on your turn', () {
      final s = initialGameState(); // South to move
      final moves = Rules.reachableMoves(s, const Position(0, 0)); // North piece
      expect(moves, isEmpty);
    });

    test('King moves exactly one square regardless of top face', () {
      final s = initialGameState();
      final kingEntry = s.piecesOf(0).firstWhere((e) => e.value.isKing);
      final moves = Rules.reachableMoves(s, kingEntry.key);
      for (final m in moves) {
        final steps = m.path.fold<int>(0, (a, seg) => a + seg.count);
        expect(steps, 1);
      }
    });

    test('cannot jump over another piece', () {
      final pieces = <Position, Piece>{
        const Position(3, 4):
            Piece(owner: 0, die: Die.withTopNorth(3, 2)!, isKing: false),
        const Position(3, 3): // one square north — a blocker
            Piece(owner: 0, die: Die.anchor, isKing: false),
      };
      final s = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 0);
      final moves = Rules.reachableMoves(s, const Position(3, 4));
      final northLanding = moves.where((m) => m.to.col == 3 && m.to.row < 4);
      expect(northLanding, isEmpty);
    });
  });

  group('capture and win', () {
    test('capturing lands on an enemy by exact count and removes it', () {
      const enemyPos = Position(3, 1);
      final pieces = <Position, Piece>{
        const Position(3, 4): // top=3 -> can reach row 1 straight north
            Piece(owner: 0, die: Die.withTopNorth(3, 2)!, isKing: false),
        enemyPos: Piece(owner: 1, die: Die.anchor, isKing: false),
      };
      final s = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 0);
      final capture = Rules.reachableMoves(s, const Position(3, 4))
          .firstWhere((m) => m.to == enemyPos);
      expect(capture.capturesOpponent, isTrue);

      final next = Rules.applyMove(s, capture);
      expect(next.pieceAt(enemyPos)!.owner, 0); // now ours
      expect(next.pieces.length, 1); // enemy removed
      expect(next.currentPlayer, 1); // turn passed
      expect(next.turnNumber, 1);
      expect(next.isOver, isFalse);
    });

    test('capturing the opponent King wins the game', () {
      const enemyKing = Position(3, 1);
      final pieces = <Position, Piece>{
        const Position(3, 4):
            Piece(owner: 0, die: Die.withTopNorth(3, 2)!, isKing: false),
        enemyKing: Piece(owner: 1, die: Die.anchor, isKing: true),
      };
      final s = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 0);
      final m = Rules.reachableMoves(s, const Position(3, 4))
          .firstWhere((m) => m.to == enemyKing);
      expect(m.capturesOpponent, isTrue);

      final next = Rules.applyMove(s, m);
      expect(next.winner, 0);
      expect(next.isOver, isTrue);
    });

    test('the King can itself capture the enemy King to win', () {
      const enemyKing = Position(4, 3);
      final pieces = <Position, Piece>{
        const Position(4, 4): // own King, one square south of enemy King
            Piece(owner: 0, die: Die.anchor, isKing: true),
        enemyKing: Piece(owner: 1, die: Die.anchor, isKing: true),
      };
      final s = GameState(pieces: pieces, currentPlayer: 0, turnNumber: 0);
      final m = Rules.reachableMoves(s, const Position(4, 4))
          .firstWhere((m) => m.to == enemyKing);
      final next = Rules.applyMove(s, m);
      expect(next.winner, 0);
    });
  });

  group('isLegal (remote-link validation)', () {
    test('accepts engine-produced moves and rejects tampered ones', () {
      final s = initialGameState();
      const from = Position(2, kSouthHomeRow);
      final move = Rules.reachableMoves(s, from).first;
      expect(Rules.isLegal(s, move), isTrue);

      final tampered = Move(
        from: move.from,
        to: const Position(0, 0),
        path: move.path,
        resultDie: move.resultDie,
        capturesOpponent: false,
      );
      expect(Rules.isLegal(s, tampered), isFalse);
    });
  });
}
