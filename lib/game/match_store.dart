import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/board.dart';
import '../core/serialization.dart';

/// A saved link-based match on this device: the current board, the turn
/// sequence number applied so far, and which player this device is.
class SavedMatch {
  SavedMatch({
    required this.gameId,
    required this.state,
    required this.seq,
    required this.myPlayer,
    required this.updatedAt,
  });

  final String gameId;
  final GameState state;

  /// Highest turn sequence number applied (0 = only the initial position).
  final int seq;

  /// 0 (Blue/South) or 1 (Red/North) — which side this device plays.
  final int myPlayer;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
        'g': gameId,
        'st': gameStateToJson(state),
        'seq': seq,
        'me': myPlayer,
        'at': updatedAt.millisecondsSinceEpoch,
      };

  static SavedMatch fromJson(Map<String, dynamic> j) => SavedMatch(
        gameId: j['g'] as String,
        state: gameStateFromJson((j['st'] as Map).cast<String, dynamic>()),
        seq: (j['seq'] as num).toInt(),
        myPlayer: (j['me'] as num).toInt(),
        updatedAt:
            DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
      );
}

/// Persists link-based matches in shared_preferences, keyed by game id.
class MatchStore {
  MatchStore._();
  static final MatchStore instance = MatchStore._();

  static const _prefix = 'match:';
  SharedPreferences? _prefs;

  /// Call once at startup (after the binding is initialized).
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  SavedMatch? load(String gameId) {
    final raw = _prefs?.getString('$_prefix$gameId');
    if (raw == null) return null;
    try {
      return SavedMatch.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(SavedMatch m) async {
    await _prefs?.setString('$_prefix${m.gameId}', jsonEncode(m.toJson()));
  }

  Future<void> delete(String gameId) async {
    await _prefs?.remove('$_prefix$gameId');
  }

  /// All saved matches, most recently updated first.
  List<SavedMatch> all() {
    final keys =
        _prefs?.getKeys().where((k) => k.startsWith(_prefix)) ?? const [];
    final out = <SavedMatch>[];
    for (final k in keys) {
      final raw = _prefs?.getString(k);
      if (raw == null) continue;
      try {
        out.add(
            SavedMatch.fromJson((jsonDecode(raw) as Map).cast<String, dynamic>()));
      } catch (_) {}
    }
    out.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return out;
  }
}
