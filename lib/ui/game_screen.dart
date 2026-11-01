import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import 'board_view.dart';

const List<String> kPlayerNames = ['South (Blue)', 'North (Red)'];

/// Local pass-and-play screen: the board, a turn/status banner, and a hand-off
/// overlay between turns.
class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final GameController controller = GameController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Duell · Local 2-Player'),
        actions: [
          IconButton(
            tooltip: 'New game',
            icon: const Icon(Icons.refresh),
            onPressed: controller.newGame,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          return Stack(
            children: [
              Column(
                children: [
                  _StatusBanner(controller: controller),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: BoardView(controller: controller),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              if (controller.awaitingHandoff)
                _HandoffOverlay(controller: controller),
              if (controller.isOver) _WinOverlay(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final player = controller.state.currentPlayer;
    return Container(
      width: double.infinity,
      color: kPlayerColors[player].withValues(alpha: 0.15),
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      child: Row(
        children: [
          CircleAvatar(radius: 10, backgroundColor: kPlayerColors[player]),
          const SizedBox(width: 10),
          Text(
            controller.isOver
                ? 'Game over'
                : '${kPlayerNames[player]} to move',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          Text('Turn ${controller.state.turnNumber}',
              style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _HandoffOverlay extends StatelessWidget {
  const _HandoffOverlay({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final next = controller.state.currentPlayer;
    final move = controller.lastMove;
    return Positioned.fill(
      child: GestureDetector(
        onTap: controller.continueAfterHandoff,
        child: Container(
          color: Colors.black.withValues(alpha: 0.82),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.swap_horiz, color: Colors.white, size: 48),
                const SizedBox(height: 16),
                Text(
                  'Pass the device to\n${kPlayerNames[next]}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontSize: 24),
                ),
                if (move != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Last move: ${move.notation}'
                    '${move.capturesOpponent ? ' · capture!' : ''}'
                    ' · top ${move.resultTop}',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
                const SizedBox(height: 28),
                FilledButton(
                  onPressed: controller.continueAfterHandoff,
                  child: const Text("I'm ready"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final winner = controller.state.winner!;
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(
                '${kPlayerNames[winner]} wins!',
                style: const TextStyle(color: Colors.white, fontSize: 28),
              ),
              const SizedBox(height: 28),
              FilledButton(
                onPressed: controller.newGame,
                child: const Text('New game'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
