import 'package:flutter/material.dart';

import '../game/game_controller.dart';
import '../game/settings.dart';
import 'board_view.dart';

const List<String> kPlayerNames = ['Blue', 'Red'];

/// Local pass-and-play screen: the board between two turn banners. The active
/// player's banner glows — there is no confirmation step between turns.
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
          final active = controller.activePlayer;
          return Stack(
            children: [
              Column(
                children: [
                  // North sits at the top of the board.
                  _TurnBanner(player: 1, active: active == 1 && !controller.isOver),
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 640),
                          child: BoardView(
                            controller: controller,
                            kingIcon: Settings.instance.kingIcon,
                          ),
                        ),
                      ),
                    ),
                  ),
                  _TurnBanner(player: 0, active: active == 0 && !controller.isOver),
                ],
              ),
              if (controller.isOver) _WinOverlay(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

/// A glowing banner for one player's side. Pulses while [active].
class _TurnBanner extends StatefulWidget {
  const _TurnBanner({required this.player, required this.active});

  final int player;
  final bool active;

  @override
  State<_TurnBanner> createState() => _TurnBannerState();
}

class _TurnBannerState extends State<_TurnBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1300),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = kPlayerColors[widget.player];
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, _) {
        final t = Curves.easeInOut.transform(_pulse.value);
        final active = widget.active;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.18 + 0.10 * t)
                : const Color(0xFF1B1F25),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: color.withValues(alpha: 0.30 + 0.35 * t),
                      blurRadius: 14 + 10 * t,
                      spreadRadius: 1 + 1.5 * t,
                    ),
                  ]
                : const [],
          ),
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: active ? color : color.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  active
                      ? "${kPlayerNames[widget.player]}'s Turn"
                      : kPlayerNames[widget.player],
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: active
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.28),
                  ),
                ),
              ],
            ),
          ),
        );
      },
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
