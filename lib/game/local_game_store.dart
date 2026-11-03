import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/board.dart';
import '../core/serialization.dart';

/// Persists the single in-progress local (pass-and-play) game so backing out of
/// the board and returning resumes it instead of starting over.
class LocalGameStore {
  LocalGameStore._();
  static final LocalGameStore instance = LocalGameStore._();

  static const _key = 'local_game';
  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  GameState? load() {
    final raw = _prefs?.getString(_key);
    if (raw == null) return null;
    try {
      return gameStateFromJson((jsonDecode(raw) as Map).cast<String, dynamic>());
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GameState state) async {
    await _prefs?.setString(_key, jsonEncode(gameStateToJson(state)));
  }

  Future<void> clear() async {
    await _prefs?.remove(_key);
  }
}
