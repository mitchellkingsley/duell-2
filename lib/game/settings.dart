import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A selectable King icon: a label and the Material icon to draw.
typedef KingIconChoice = ({String label, IconData icon});

/// The icons the player can choose for their King piece. Referenced as consts
/// so icon tree-shaking keeps their glyphs. Index into this list is persisted.
const List<KingIconChoice> kKingIcons = [
  (label: 'Trophy', icon: Icons.emoji_events),
  (label: 'Star', icon: Icons.star),
  (label: 'Shield', icon: Icons.shield),
  (label: 'Diamond', icon: Icons.diamond),
  (label: 'Flame', icon: Icons.local_fire_department),
  (label: 'Bolt', icon: Icons.bolt),
  (label: 'Heart', icon: Icons.favorite),
  (label: 'Crown', icon: Icons.workspace_premium),
  (label: 'Anchor', icon: Icons.anchor),
  (label: 'Rocket', icon: Icons.rocket_launch),
  (label: 'Paw', icon: Icons.pets),
  (label: 'Snowflake', icon: Icons.ac_unit),
];

/// App-wide settings, persisted with shared_preferences. Single instance.
class Settings extends ChangeNotifier {
  Settings._();
  static final Settings instance = Settings._();

  static const _kKingIconKey = 'kingIconIndex';

  SharedPreferences? _prefs;
  int _kingIconIndex = 0;

  int get kingIconIndex => _kingIconIndex;
  IconData get kingIcon => kKingIcons[_kingIconIndex].icon;

  /// Load persisted settings. Call once before `runApp`.
  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    final i = _prefs?.getInt(_kKingIconKey);
    if (i != null && i >= 0 && i < kKingIcons.length) {
      _kingIconIndex = i;
    }
  }

  void setKingIconIndex(int index) {
    if (index == _kingIconIndex || index < 0 || index >= kKingIcons.length) {
      return;
    }
    _kingIconIndex = index;
    _prefs?.setInt(_kKingIconKey, index);
    notifyListeners();
  }
}
