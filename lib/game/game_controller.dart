import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/die.dart';
import '../core/geometry.dart';
import '../core/move.dart';
import '../core/rules.dart';
import '../core/serialization.dart';
import '../core/setup.dart';
import '../core/turn_link.dart';
import 'local_game_store.dart';
import 'match_store.dart';

/// Outcome of applying an inbound turn link.
enum InboundResult {
  applied,
  duplicate, // already applied (seq <= ours) — harmless
  wrongGame, // link is for a different game
  illegal, // the move is not legal from our state
  desync, // out of sequence, or resulting hash disagrees
}

/// A move currently being animated (the die tumbling from origin to
/// destination). Captured at commit time so the overlay has the pre-move
/// orientation and the mover's identity, independent of whose turn it now is.
class TumbleAnim {
  const TumbleAnim({
    required this.move,
    required this.startDie,
    required this.owner,
    required this.isKing,
  });

  final Move move;
  final Die startDie;
  final int owner;
  final bool isKing;
}

/// Drives local (pass-and-play) games and exposes UI selection/preview state.
///
/// This is the only stateful glue between the pure-Dart engine and the widgets.
/// Remote mode (deep links) will later reuse the same engine calls here.
class GameController extends ChangeNotifier {
  /// A local (pass-and-play) game. Pass [initial] to resume a saved game;
  /// omit it to start fresh.
  GameController({GameState? initial}) {
    if (initial != null) {
      _state = initial;
    } else {
      newGame();
    }
  }

  /// A link-based (remote) game. [myPlayer] is the only side this device may
  /// move; moves commit, bump the sequence, and produce an outbound link.
  GameController.remote({
    required String gameId,
    required int myPlayer,
    required GameState state,
    required int seq,
  }) {
    _gameId = gameId;
    _myPlayer = myPlayer;
    _seq = seq;
    _state = state;
  }

  late GameState _state;
  GameState get state => _state;

  // --- Remote (link-based) mode ---
  int? _myPlayer;
  int? get myPlayer => _myPlayer;
  bool get isRemote => _myPlayer != null;

  String? _gameId;
  String? get gameId => _gameId;

  int _seq = 0;
  int get seq => _seq;

  /// The encoded turn token to share after this device's move (null until you
  /// move, or once the opponent's reply has been applied).
  String? _outboundToken;
  String? get outboundToken => _outboundToken;

  bool get isMyTurn =>
      !isRemote || (!_state.isOver && _state.currentPlayer == _myPlayer);

  Position? _selected;
  Position? get selected => _selected;

  /// Legal moves for the currently selected piece, keyed by destination.
  /// A destination may map to more than one move (different paths/outcomes).
  Map<Position, List<Move>> _movesByDest = {};
  Map<Position, List<Move>> get movesByDest => _movesByDest;

  /// The destination currently being previewed (hovered), if any.
  Position? _previewDest;
  Position? get previewDest => _previewDest;

  /// When a tapped destination can be reached by more than one route, the
  /// chooser opens on that square and the player picks which way to roll.
  Position? _choiceDest;
  Position? get choiceDest => _choiceDest;
  bool get isChoosing => _choiceDest != null;
  List<Move> get choiceOptions =>
      _choiceDest == null ? const [] : movesTo(_choiceDest!);

  /// The chooser option currently hovered, whose route is highlighted.
  Move? _hoverOption;
  Move? get hoveredOption => _hoverOption;
  List<Position> get highlightedRoute => _hoverOption?.routeCells() ?? const [];

  /// The move just played (most recent). Handy for a status line.
  Move? _lastMove;
  Move? get lastMove => _lastMove;

  /// The move currently tumbling across the board, or null when settled.
  TumbleAnim? _animating;
  TumbleAnim? get animating => _animating;
  bool get isAnimating => _animating != null;

  bool get isOver => _state.isOver;

  /// The player whose side should glow: the mover while a tumble is in flight
  /// (the turn has already advanced in state), otherwise the player to move.
  int get activePlayer => _animating?.owner ?? _state.currentPlayer;

  void newGame() {
    _state = initialGameState();
    _selected = null;
    _movesByDest = {};
    _previewDest = null;
    _lastMove = null;
    _animating = null;
    _choiceDest = null;
    _hoverOption = null;
    if (!isRemote) LocalGameStore.instance.clear();
    notifyListeners();
  }

  /// Legal moves landing on [dest] for the current selection (may be empty).
  List<Move> movesTo(Position dest) => _movesByDest[dest] ?? const [];

  bool isSelectable(Position p) {
    final piece = _state.pieceAt(p);
    return piece != null &&
        piece.owner == _state.currentPlayer &&
        !_state.isOver &&
        !isAnimating &&
        isMyTurn;
  }

  void select(Position p) {
    if (_state.isOver || isAnimating) return;
    if (!isSelectable(p)) {
      _clearSelection();
      return;
    }
    _selected = p;
    final moves = Rules.reachableMoves(_state, p);
    final byDest = <Position, List<Move>>{};
    for (final m in moves) {
      byDest.putIfAbsent(m.to, () => []).add(m);
    }
    _movesByDest = byDest;
    _previewDest = null;
    notifyListeners();
  }

  void hover(Position? dest) {
    if (dest == _previewDest) return;
    _previewDest = (dest != null && _movesByDest.containsKey(dest)) ? dest : null;
    notifyListeners();
  }

  /// Handle a tap on [p]: select own piece, commit a move onto a highlighted
  /// destination, open the route chooser if that square has two routes, or
  /// clear the selection.
  void tap(Position p) {
    if (_state.isOver || isAnimating) return;

    // A tap anywhere while the chooser is open cancels it first.
    if (_choiceDest != null) {
      cancelChoice();
      return;
    }

    if (_selected != null && _movesByDest.containsKey(p)) {
      final options = _movesByDest[p]!;
      if (options.length == 1) {
        commit(options.first);
      } else {
        _choiceDest = p; // two routes — let the player pick which way to roll
        _hoverOption = null;
        notifyListeners();
      }
      return;
    }

    if (isSelectable(p)) {
      select(p);
    } else {
      _clearSelection();
    }
  }

  /// Commit a specific route chosen from the chooser.
  void chooseOption(Move move) => commit(move);

  /// Dismiss the chooser without moving.
  void cancelChoice() {
    _choiceDest = null;
    _hoverOption = null;
    notifyListeners();
  }

  /// Highlight the route of the chooser option under the pointer (web).
  void hoverOption(Move? move) {
    if (move == _hoverOption) return;
    _hoverOption = move;
    notifyListeners();
  }

  /// Apply [move] through the engine, then start the tumble animation. The turn
  /// passes immediately; the glowing banner (not a confirmation) shows whose it
  /// is once the tumble settles.
  void commit(Move move) {
    final piece = _state.pieceAt(move.from)!;
    final anim = TumbleAnim(
      move: move,
      startDie: piece.die,
      owner: piece.owner,
      isKing: piece.isKing,
    );
    _state = Rules.applyMove(_state, move);
    _lastMove = move;
    _clearSelection();
    _animating = anim;

    if (isRemote) {
      _seq += 1;
      _outboundToken = TurnPayload(
        gameId: _gameId!,
        seq: _seq,
        from: move.from,
        path: move.path,
        stateHash: stateHash(_state),
      ).encode();
      _persist();
    } else {
      _persistLocal();
    }

    notifyListeners();
  }

  /// Save (or, once finished, clear) the in-progress local game so it resumes
  /// after backing out of the board.
  void _persistLocal() {
    if (_state.isOver) {
      LocalGameStore.instance.clear();
    } else {
      LocalGameStore.instance.save(_state);
    }
  }

  /// Apply a turn received over a link. Returns the outcome; on success the
  /// opponent's move tumbles across the board and it becomes your turn.
  InboundResult applyInbound(TurnPayload p) {
    if (!isRemote || _gameId == null || p.gameId != _gameId) {
      return InboundResult.wrongGame;
    }
    if (p.seq <= _seq) return InboundResult.duplicate;
    if (p.seq != _seq + 1) return InboundResult.desync;

    final resolved = Rules.resolveMove(_state, p.from, p.path);
    if (resolved == null) return InboundResult.illegal;

    final piece = _state.pieceAt(p.from)!;
    final next = Rules.applyMove(_state, resolved);
    if (stateHash(next) != p.stateHash) return InboundResult.desync;

    _state = next;
    _seq = p.seq;
    _lastMove = resolved;
    _outboundToken = null;
    _clearSelection();
    _animating = TumbleAnim(
      move: resolved,
      startDie: piece.die,
      owner: piece.owner,
      isKing: piece.isKing,
    );
    _persist();
    notifyListeners();
    return InboundResult.applied;
  }

  void _persist() {
    if (!isRemote) return;
    // Fire-and-forget; the device's copy of the match survives app restarts.
    MatchStore.instance.save(SavedMatch(
      gameId: _gameId!,
      state: _state,
      seq: _seq,
      myPlayer: _myPlayer!,
      updatedAt: DateTime.now(),
    ));
  }

  /// Called by the board when the tumble animation finishes: reveal the settled
  /// piece. The turn has already advanced, so the other side's banner lights up.
  void onTumbleComplete() {
    if (_animating == null) return;
    _animating = null;
    notifyListeners();
  }

  void _clearSelection() {
    _selected = null;
    _movesByDest = {};
    _previewDest = null;
    _choiceDest = null;
    _hoverOption = null;
  }
}
