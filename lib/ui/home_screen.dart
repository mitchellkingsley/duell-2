import 'package:flutter/material.dart';

import 'game_screen.dart';

/// Entry screen: choose a game mode. Local pass-and-play is live; remote
/// (link-based) mode is scaffolded for later (PLAN.md §5).
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
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
                  style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'The strategy game of dice',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.black54),
                ),
                const SizedBox(height: 40),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GameScreen()),
                  ),
                  icon: const Icon(Icons.people),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Local 2-Player (Pass & Play)'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: null, // remote mode: PLAN.md §5, not built yet
                  icon: const Icon(Icons.link),
                  label: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Text('Play by Link (coming soon)'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
