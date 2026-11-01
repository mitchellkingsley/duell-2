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
    notifyListeners();
  }

  /// Legal moves landing on [dest] for the current selection (may be empty).
  List<Move> movesTo(Position dest) => _movesByDest[dest] ?? const [];

  bool isSelectable(Position p) {
    final piece = _state.pieceAt(p);
    return piece != null &&
        piece.owner == _state.currentPlayer &&
        !_state.isOver &&
        !isAnimating;
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
    notifyListeners();
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
