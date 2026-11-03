import 'package:flutter/material.dart';

import '../game/settings.dart';
import 'board_view.dart' show kPlayerColors;
import 'game_screen.dart';
import 'remote_screen.dart';

/// Entry screen: choose a game mode, or open Options to configure the King icon.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Settings.instance,
        builder: (context, _) {
          return Stack(
            children: [
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  tooltip: 'Options',
                  icon: const Icon(Icons.settings),
                  onPressed: () => _showOptions(context),
                ),
              ),
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Duell',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 48, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'The strategy game of dice',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white60),
                        ),
                        const SizedBox(height: 40),
                        FilledButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const GameScreen()),
                          ),
                          icon: const Icon(Icons.people),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Pass & Play'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const RemoteLobbyScreen()),
                          ),
                          icon: const Icon(Icons.link),
                          label: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text('Play by Link'),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _KingSummary(onTap: () => _showOptions(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showOptions(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AnimatedBuilder(
          animation: Settings.instance,
          builder: (context, _) {
            final selected = Settings.instance.kingIconIndex;
            return AlertDialog(
              title: const Text('Options'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('King piece icon',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 320,
                    child: Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (var i = 0; i < kKingIcons.length; i++)
                          _IconTile(
                            icon: kKingIcons[i].icon,
                            label: kKingIcons[i].label,
                            selected: i == selected,
                            onTap: () =>
                                Settings.instance.setKingIconIndex(i),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Shows the currently selected King icon on the home screen.
class _KingSummary extends StatelessWidget {
  const _KingSummary({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('King piece:  ',
                style: TextStyle(color: Colors.white70)),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kPlayerColors[0],
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: Colors.amber.shade500, width: 2),
              ),
              child: Icon(Settings.instance.kingIcon,
                  size: 20, color: Colors.white),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.edit, size: 14, color: Colors.white54),
          ],
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = kPlayerColors[0];
    return Tooltip(
      message: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: selected ? color : color.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? Colors.amber.shade500 : Colors.transparent,
              width: 2.5,
            ),
          ),
          child: Icon(icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}
