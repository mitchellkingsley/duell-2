import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/board.dart';
import '../core/geometry.dart';
import '../core/turn_link.dart';
import '../game/deep_links.dart';
import '../game/game_controller.dart';
import '../game/local_game_store.dart';
import '../game/settings.dart';
import 'board_view.dart';

const List<String> kPlayerNames = ['Blue', 'Red'];

/// The game board for both local pass-and-play and link-based play. Pass a
/// remote [controller] for link play; omit it for a local game (resumed from
/// the saved local game, or fresh).
class GameScreen extends StatefulWidget {
  const GameScreen({super.key, this.controller});

  /// A pre-built remote controller, or null for a local game.
  final GameController? controller;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late final GameController controller;

  @override
  void initState() {
    super.initState();
    if (widget.controller != null) {
      controller = widget.controller!;
    } else {
      final saved = LocalGameStore.instance.load();
      controller = (saved != null && !saved.isOver)
          ? GameController(initial: saved)
          : GameController();
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final remote = controller.isRemote;
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (!remote)
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
          final me = controller.myPlayer;
          return Stack(
            children: [
              Column(
                children: [
                  // North sits at the top of the board.
                  _TurnBanner(
                    player: 1,
                    active: active == 1 && !controller.isOver,
                    isMe: me == 1,
                  ),
                  _StatsStrip(state: controller.state, player: 1),
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
                  _StatsStrip(state: controller.state, player: 0),
                  _TurnBanner(
                    player: 0,
                    active: active == 0 && !controller.isOver,
                    isMe: me == 0,
                  ),
                  // Fixed-height so the board doesn't resize as the link button
                  // appears/disappears.
                  if (remote) _LinkBar(controller: controller),
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

/// A compact stats strip for one player, shown between their banner and the
/// board: remaining dice (the King marked) and how many they've captured.
class _StatsStrip extends StatelessWidget {
  const _StatsStrip({required this.state, required this.player});

  final GameState state;
  final int player;

  @override
  Widget build(BuildContext context) {
    final color = kPlayerColors[player];
    final mine = state.piecesOf(player).toList();
    final alive = mine.length;
    final kingAlive = mine.any((e) => e.value.isKing);
    final captures = kBoardSize - state.piecesOf(1 - player).length;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < kBoardSize; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: i < alive ? color : color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(3),
                ),
                child: (kingAlive && i == 0)
                    ? Icon(Settings.instance.kingIcon,
                        size: 10, color: Colors.white)
                    : null,
              ),
            ),
          const SizedBox(width: 12),
          Icon(Icons.close, size: 13, color: color),
          const SizedBox(width: 2),
          Text('$captures',
              style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// A glowing banner for one player's side. Pulses while [active]; marks the
/// local device's side with "(you)" in link play.
class _TurnBanner extends StatefulWidget {
  const _TurnBanner({
    required this.player,
    required this.active,
    this.isMe = false,
  });

  final int player;
  final bool active;
  final bool isMe;

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
        final name = kPlayerNames[widget.player] + (widget.isMe ? ' (you)' : '');
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          height: 32,
          decoration: BoxDecoration(
            color: active
                ? color.withValues(alpha: 0.18 + 0.10 * t)
                : const Color(0xFF000000),
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
                  active ? "$name's Turn" : name,
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

/// Fixed-height link controls for a remote game: copy the link to send after
/// your move, and apply the opponent's reply. Height is constant so the board
/// never resizes between states.
class _LinkBar extends StatelessWidget {
  const _LinkBar({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final token = controller.outboundToken;
    final over = controller.isOver;

    return Container(
      height: 64,
      color: const Color(0xFF000000),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (!over && token != null)
            FilledButton.icon(
              onPressed: () => _copy(context, token),
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copy link'),
            ),
          if (!over) const SizedBox(width: 8),
          if (!over)
            OutlinedButton.icon(
              onPressed: () => _applyDialog(context),
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Apply'),
            ),
        ],
      ),
    );
  }

  Future<void> _copy(BuildContext context, String token) async {
    final link = buildTurnLink(token, webOrigin: Uri.base.origin);
    await Clipboard.setData(ClipboardData(text: link));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Link copied')));
    }
  }

  Future<void> _applyDialog(BuildContext context) async {
    final field = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Apply opponent's move"),
        content: TextField(
          controller: field,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Paste link or code',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => Navigator.of(context).pop(true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Apply')),
        ],
      ),
    );
    if (result != true) return;

    final raw = field.text.trim();
    final payload =
        TurnPayload.decode(Uri.tryParse(raw)?.queryParameters['t'] ?? raw);
    String? msg;
    if (payload == null) {
      msg = 'Not a valid link.';
    } else if (payload.gameId != controller.gameId) {
      msg = 'That link is for a different game.';
    } else {
      msg = switch (controller.applyInbound(payload)) {
        InboundResult.applied => null,
        InboundResult.duplicate => 'Already applied.',
        InboundResult.illegal => 'That move isn’t legal here.',
        InboundResult.desync => 'Out of sync — a turn may be missing.',
        InboundResult.wrongGame => 'Different game.',
      };
    }
    if (msg != null) {
      messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}

class _WinOverlay extends StatelessWidget {
  const _WinOverlay({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final winner = controller.state.winner!;
    final me = controller.myPlayer;
    final title = me != null
        ? (winner == me ? 'You win!' : 'You lose.')
        : '${kPlayerNames[winner]} wins!';
    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.82),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 64),
              const SizedBox(height: 16),
              Text(title,
                  style: const TextStyle(color: Colors.white, fontSize: 28)),
              const SizedBox(height: 28),
              if (me == null)
                FilledButton(
                  onPressed: controller.newGame,
                  child: const Text('New game'),
                )
              else
                FilledButton(
                  onPressed: () => Navigator.of(context).popUntil(
                      (r) => r.isFirst || r.settings.name == '/'),
                  child: const Text('Done'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
