import 'package:flutter/foundation.dart';

import '../core/board.dart';
import '../core/die.dart';
import '../core/geometry.dart';
import '../core/move.dart';
import '../core/rules.dart';
import '../core/setup.dart';

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
  GameController() {
    newGame();
  }

  late GameState _state;
  GameState get state => _state;

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

  /// After a committed move, local mode pauses on a hand-off screen so the next
  /// player can take the device without seeing the previous player's state.
  bool _awaitingHandoff = false;
  bool get awaitingHandoff => _awaitingHandoff;

  /// The move just played, kept for the hand-off summary.
  Move? _lastMove;
  Move? get lastMove => _lastMove;

  /// The move currently tumbling across the board, or null when settled.
  TumbleAnim? _animating;
  TumbleAnim? get animating => _animating;
  bool get isAnimating => _animating != null;

  bool get isOver => _state.isOver;

  void newGame() {
    _state = initialGameState();
    _selected = null;
    _movesByDest = {};
    _previewDest = null;
    _awaitingHandoff = false;
    _lastMove = null;
    _animating = null;
    _choiceDest = null;
    _hoverOption = null;
    notifyListeners();
  }

  /// Legal moves landing on [dest] for the current selection (may be empty).
  List<Move> movesTo(Position dest) => _movesByDest[dest] ?? const [];

  bool isSelectable(Position p) {
    final piece = _state.pieceAt(p);
    return piece != null &&
        piece.owner == _state.currentPlayer &&
        !_state.isOver &&
        !_awaitingHandoff &&
        !isAnimating;
  }

  void select(Position p) {
    if (_awaitingHandoff || _state.isOver || isAnimating) return;
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
    if (_awaitingHandoff || _state.isOver || isAnimating) return;

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

  /// Apply [move] through the engine, then start the tumble animation. The
  /// hand-off (or win) screen is deferred until [onTumbleComplete] fires.
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
    notifyListeners();
  }

  /// Called by the board when the tumble animation finishes. Reveals the
  /// settled piece and shows the hand-off (unless the game just ended).
  void onTumbleComplete() {
    if (_animating == null) return;
    _animating = null;
    _awaitingHandoff = !_state.isOver;
    notifyListeners();
  }

  /// Dismiss the hand-off screen; the next player now sees the board.
  void continueAfterHandoff() {
    _awaitingHandoff = false;
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
