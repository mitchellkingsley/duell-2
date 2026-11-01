import 'dart:convert';

import 'geometry.dart';
import 'move.dart';

/// The data carried in a turn link (PLAN.md §5): which game, the turn sequence
/// number, the move (origin + path only — the destination and resulting die are
/// re-derived and validated by the receiver), and the resulting state hash.
///
/// Encodes to URL-safe base64 of a compact JSON object, suitable for a link
/// fragment. The move itself is tiny; sending the delta (not the board) keeps
/// links short and forces the receiver's engine to be the referee.
class TurnPayload {
  const TurnPayload({
    required this.gameId,
    required this.seq,
    required this.from,
    required this.path,
    required this.stateHash,
  });

  final String gameId;
  final int seq;
  final Position from;
  final List<MoveSegment> path;

  /// Expected board hash after applying this move (checked by the receiver).
  final String stateHash;

  Map<String, dynamic> toJson() => {
        'g': gameId,
        's': seq,
        'f': [from.col, from.row],
        'p': path.map((seg) => [seg.direction.code, seg.count]).toList(),
        'h': stateHash,
      };

  static TurnPayload fromJson(Map<String, dynamic> j) {
    final f = (j['f'] as List).cast<int>();
    final segs = (j['p'] as List)
        .map((e) => (e as List))
        .map((e) => MoveSegment(
            Direction.fromCode(e[0] as String), (e[1] as num).toInt()))
        .toList();
    return TurnPayload(
      gameId: j['g'] as String,
      seq: (j['s'] as num).toInt(),
      from: Position(f[0], f[1]),
      path: segs,
      stateHash: j['h'] as String,
    );
  }

  /// Encode to a URL-safe base64 token (no padding).
  String encode() {
    final bytes = utf8.encode(jsonEncode(toJson()));
    return base64Url.encode(bytes).replaceAll('=', '');
  }

  /// Decode a token produced by [encode]; returns null if malformed.
  static TurnPayload? decode(String token) {
    try {
      final padded = token.padRight((token.length + 3) & ~3, '=');
      final json = utf8.decode(base64Url.decode(padded));
      return fromJson((jsonDecode(json) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }
}
