import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/setup.dart';
import '../core/turn_link.dart';
import '../game/deep_links.dart';
import '../game/game_controller.dart';
import '../game/match_store.dart';
import '../game/settings.dart';
import 'board_view.dart';
import 'game_screen.dart' show kPlayerNames;

/// Build the shareable link for a turn token.
String buildShareLink(String token) =>
    buildTurnLink(token, webOrigin: Uri.base.origin);

/// Create or continue a game from an inbound link token. Returns a ready
/// controller, or an error message to show the user.
({GameController? controller, String? error}) controllerFromInbound(
    String token) {
  // Accept a bare token or a full URL containing ?t=.
  var t = token.trim();
  final uri = Uri.tryParse(t);
  if (uri != null && uri.queryParameters['t'] != null) {
    t = uri.queryParameters['t']!;
  }

  final payload = TurnPayload.decode(t);
  if (payload == null) return (controller: null, error: 'Not a valid game link.');

  final saved = MatchStore.instance.load(payload.gameId);
  final GameController c;
  if (saved != null) {
    c = GameController.remote(
      gameId: saved.gameId,
      myPlayer: saved.myPlayer,
      state: saved.state,
      seq: saved.seq,
    );
  } else {
    if (payload.seq != 1) {
      return (controller: null, error: 'Can’t join this game mid-play.');
    }
    // Joining a new game: the creator is Blue (player 0), so the joiner is Red.
    c = GameController.remote(
      gameId: payload.gameId,
      myPlayer: 1,
      state: initialGameState(),
      seq: 0,
    );
  }

  final res = c.applyInbound(payload);
  switch (res) {
    case InboundResult.applied:
    case InboundResult.duplicate:
      return (controller: c, error: null);
    case InboundResult.wrongGame:
      return (controller: null, error: 'Link is for a different game.');
    case InboundResult.illegal:
      return (controller: null, error: 'That move isn’t legal in this game.');
    case InboundResult.desync:
      return (controller: null, error: 'The games are out of sync.');
  }
}

String _newGameId() {
  const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
  final r = Random();
  return List.generate(8, (_) => chars[r.nextInt(chars.length)]).join();
}

/// Entry screen for link-based play: start, resume, or paste a link.
class RemoteLobbyScreen extends StatefulWidget {
  const RemoteLobbyScreen({super.key});

  @override
  State<RemoteLobbyScreen> createState() => _RemoteLobbyScreenState();
}

class _RemoteLobbyScreenState extends State<RemoteLobbyScreen> {
  final _linkField = TextEditingController();

  @override
  void dispose() {
    _linkField.dispose();
    super.dispose();
  }

  void _startNew() {
    final c = GameController.remote(
      gameId: _newGameId(),
      myPlayer: 0,
      state: initialGameState(),
      seq: 0,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RemoteGameScreen(controller: c)),
    );
  }

  void _openSaved(SavedMatch m) {
    final c = GameController.remote(
      gameId: m.gameId,
      myPlayer: m.myPlayer,
      state: m.state,
      seq: m.seq,
    );
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RemoteGameScreen(controller: c)),
    );
  }

  void _applyLink() {
    final r = controllerFromInbound(_linkField.text);
    if (r.controller == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(r.error ?? 'Could not open link.')));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => RemoteGameScreen(controller: r.controller!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final saved = MatchStore.instance.all();
    return Scaffold(
      appBar: AppBar(title: const Text('Play by Link')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          FilledButton.icon(
            onPressed: _startNew,
            icon: const Icon(Icons.add),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('Start a new game'),
            ),
          ),
          const SizedBox(height: 24),
          const Text('Open a link from your opponent',
              style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          TextField(
            controller: _linkField,
            decoration: const InputDecoration(
              hintText: 'Paste link or code',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            onSubmitted: (_) => _applyLink(),
          ),
          const SizedBox(height: 8),
          OutlinedButton(onPressed: _applyLink, child: const Text('Open')),
          if (saved.isNotEmpty) ...[
            const SizedBox(height: 28),
            const Text('Your games',
                style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            for (final m in saved)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                      radius: 10, backgroundColor: kPlayerColors[m.myPlayer]),
                  title: Text('Game ${m.gameId}'),
                  subtitle: Text(
                      'You are ${kPlayerNames[m.myPlayer]} · turn ${m.seq}'),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      await MatchStore.instance.delete(m.gameId);
                      setState(() {});
                    },
                  ),
                  onTap: () => _openSaved(m),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

/// The board plus the link-sharing panel for a link-based game.
class RemoteGameScreen extends StatelessWidget {
  const RemoteGameScreen({super.key, required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Duell · Play by Link')),
      body: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final me = controller.myPlayer!;
          final over = controller.isOver;
          return Column(
            children: [
              Container(
                width: double.infinity,
                color: kPlayerColors[me].withValues(alpha: 0.15),
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                child: Text(
                  over
                      ? (controller.state.winner == me ? 'You win!' : 'You lose.')
                      : 'You are ${kPlayerNames[me]} · '
                          '${controller.isMyTurn ? "your move" : "waiting for opponent"}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: BoardView(
                        controller: controller,
                        kingIcon: Settings.instance.kingIcon,
                      ),
                    ),
                  ),
                ),
              ),
              _LinkPanel(controller: controller),
            ],
          );
        },
      ),
    );
  }
}

class _LinkPanel extends StatefulWidget {
  const _LinkPanel({required this.controller});
  final GameController controller;

  @override
  State<_LinkPanel> createState() => _LinkPanelState();
}

class _LinkPanelState extends State<_LinkPanel> {
  final _field = TextEditingController();

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _applyPasted() {
    final raw = _field.text.trim();
    final payload = TurnPayload.decode(
        Uri.tryParse(raw)?.queryParameters['t'] ?? raw);
    String? msg;
    if (payload == null) {
      msg = 'Not a valid link.';
    } else if (payload.gameId != widget.controller.gameId) {
      msg = 'That link is for a different game.';
    } else {
      msg = switch (widget.controller.applyInbound(payload)) {
        InboundResult.applied => null,
        InboundResult.duplicate => 'Already applied.',
        InboundResult.illegal => 'That move isn’t legal here.',
        InboundResult.desync => 'Out of sync — a turn may be missing.',
        InboundResult.wrongGame => 'Different game.',
      };
    }
    if (msg != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      _field.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    if (c.isOver) return const SizedBox.shrink();

    final token = c.outboundToken;
    final showShare = token != null && !c.isMyTurn;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      color: const Color(0xFF1B1F25),
      child: showShare
          ? _share(context, buildShareLink(token))
          : _waiting(context),
    );
  }

  Widget _share(BuildContext context, String link) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Send this link to your opponent:',
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        SelectableText(link, maxLines: 2, style: const TextStyle(fontSize: 12)),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: link));
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Link copied')));
            }
          },
          icon: const Icon(Icons.copy),
          label: const Text('Copy link'),
        ),
      ],
    );
  }

  Widget _waiting(BuildContext context) {
    if (widget.controller.isMyTurn) {
      return const Text('Your move — tap a die to play.',
          style: TextStyle(color: Colors.white70));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text("Opponent's turn — paste their reply link here:",
            style: TextStyle(fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        TextField(
          controller: _field,
          decoration: const InputDecoration(
            hintText: 'Paste link or code',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          onSubmitted: (_) => _applyPasted(),
        ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: _applyPasted, child: const Text('Apply move')),
      ],
    );
  }
}

/// Processes an inbound link at launch and shows the game, or an error page.
class InboundLauncher extends StatelessWidget {
  const InboundLauncher({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final r = controllerFromInbound(token);
    if (r.controller != null) {
      return RemoteGameScreen(controller: r.controller!);
    }
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off, size: 48),
            const SizedBox(height: 12),
            Text(r.error ?? 'Could not open link.'),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const RemoteLobbyScreen()),
              ),
              child: const Text('Play by Link'),
            ),
          ],
        ),
      ),
    );
  }
}
