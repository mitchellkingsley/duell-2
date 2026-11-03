import 'dart:math';

import 'package:flutter/material.dart';

import '../core/setup.dart';
import '../core/turn_link.dart';
import '../game/game_controller.dart';
import '../game/match_store.dart';
import 'board_view.dart';
import 'game_screen.dart';

/// Create or continue a game from an inbound link token. Returns a ready
/// controller, or an error message to show the user.
({GameController? controller, String? error}) controllerFromInbound(
    String token) {
  // Accept a bare token or a full URL containing ?t= / #t=.
  var t = token.trim();
  final uri = Uri.tryParse(t);
  if (uri != null) {
    final q = uri.queryParameters['t'];
    if (q != null && q.isNotEmpty) {
      t = q;
    } else if (uri.fragment.startsWith('t=')) {
      t = uri.fragment.substring(2);
    }
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

  switch (c.applyInbound(payload)) {
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

  void _open(GameController c) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GameScreen(controller: c)),
    );
  }

  void _startNew() {
    _open(GameController.remote(
      gameId: _newGameId(),
      myPlayer: 0,
      state: initialGameState(),
      seq: 0,
    ));
  }

  void _openSaved(SavedMatch m) {
    _open(GameController.remote(
      gameId: m.gameId,
      myPlayer: m.myPlayer,
      state: m.state,
      seq: m.seq,
    ));
  }

  void _applyLink() {
    final r = controllerFromInbound(_linkField.text);
    if (r.controller == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(r.error ?? 'Could not open link.')));
      return;
    }
    _open(r.controller!);
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

/// Processes an inbound link at launch and shows the game, or an error page.
class InboundLauncher extends StatelessWidget {
  const InboundLauncher({super.key, required this.token});

  final String token;

  @override
  Widget build(BuildContext context) {
    final r = controllerFromInbound(token);
    if (r.controller != null) {
      return GameScreen(controller: r.controller!);
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
