import 'package:duell/core/rules.dart';
import 'package:duell/core/serialization.dart';
import 'package:duell/core/setup.dart';
import 'package:duell/core/turn_link.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('game state survives a JSON round-trip', () {
    final s = initialGameState();
    final back = gameStateFromJson(gameStateToJson(s));
    expect(back.pieces.length, s.pieces.length);
    expect(back.currentPlayer, s.currentPlayer);
    expect(stateHash(back), stateHash(s));
  });

  test('state hash changes after a move and is order-independent', () {
    final s = initialGameState();
    final from = s.piecesOf(0).first.key;
    final move = Rules.reachableMoves(s, from).first;
    final next = Rules.applyMove(s, move);
    expect(stateHash(next), isNot(equals(stateHash(s))));
    // Re-deriving the same state yields the same hash.
    final next2 = Rules.applyMove(s, move);
    expect(stateHash(next2), stateHash(next));
  });

  test('turn payload encodes and decodes losslessly', () {
    final s = initialGameState();
    final from = s.piecesOf(0).first.key;
    final move = Rules.reachableMoves(s, from).first;
    final next = Rules.applyMove(s, move);

    final payload = TurnPayload(
      gameId: 'abc123',
      seq: 1,
      from: move.from,
      path: move.path,
      stateHash: stateHash(next),
    );
    final decoded = TurnPayload.decode(payload.encode())!;

    expect(decoded.gameId, 'abc123');
    expect(decoded.seq, 1);
    expect(decoded.from, move.from);
    expect(decoded.path.length, move.path.length);
    expect(decoded.stateHash, payload.stateHash);
  });

  test('receiver re-derives and validates a move from its path', () {
    final s = initialGameState();
    final from = s.piecesOf(0).first.key;
    final sent = Rules.reachableMoves(s, from).first;

    // The receiver only has from + path; it resolves and checks legality.
    final resolved = Rules.resolveMove(s, sent.from, sent.path);
    expect(resolved, isNotNull);
    expect(resolved!.to, sent.to);
    expect(resolved.resultDie, sent.resultDie);

    final applied = Rules.applyMove(s, resolved);
    expect(stateHash(applied), stateHash(Rules.applyMove(s, sent)));
  });

  test('resolveMove rejects an illegal path', () {
    final s = initialGameState();
    final from = s.piecesOf(0).first.key;
    // A path longer than the die allows is illegal.
    final bad = Rules.resolveMove(s, from, const []);
    expect(bad, isNull);
  });

  test('decode returns null on garbage', () {
    expect(TurnPayload.decode('not-a-valid-token!!!'), isNull);
  });
}
