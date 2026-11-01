# Duell

A digital implementation of **Duell**, the strategy game of dice, built with Flutter for web and
Android from a single codebase.

Each player commands a row of dice. A die moves a number of squares equal to its top face, tumbling
one square at a time with at most one 90° turn — so the **route you take changes the number the die
ends up showing**, which is the heart of the strategy. The center die is the **King**; it moves one
square per turn, and **capturing the opponent's King wins the game**.

The full rules (transcribed from the original 1976 box art) and the complete move-outcome tables live
in [`resources/`](resources/). The design and roadmap live in [`PLAN.md`](PLAN.md).

## Status

- **Local 2-player (pass & play)** — ✅ playable now. One device, hand-off between turns, full
  rules, captures, King-capture win, faux-3D dice that tumble square-by-square, and a chooser for
  picking which way to roll when a square is reachable two ways.
- **Play by link (async remote)** — planned. Submit a turn as a tappable link over any messaging
  app; the opponent taps it to apply the move locally. See [`PLAN.md`](PLAN.md) §5–6.

## Running

Prerequisites: the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).

```bash
flutter pub get
flutter run -d chrome        # web, with hot reload — the primary dev loop
flutter run -d <android>     # an attached Android device or emulator
```

## Testing

```bash
flutter test       # unit tests for the engine
flutter analyze    # static analysis (expected: no issues)
```

The engine is pure Dart and fully unit-tested. Notably, the die-tumbling physics are validated
square-by-square against the reference tables in `resources/duell-moves.json`, so the code provably
agrees with the transcribed movement diagrams.

## Architecture

A strict split between a **pure-Dart core** (no Flutter imports, unit-testable) and the Flutter UI:

```
lib/
  core/        Pure game logic — the source of truth. No Flutter.
    geometry.dart   Board directions and positions (9x9).
    die.dart        Die orientation + tumbling physics (fixed chirality).
    move.dart       A resolved move: path, resulting die, capture flag.
    board.dart      Piece and immutable GameState.
    setup.dart      Starting position (9 dice/side, centered King).
    rules.dart      reachableMoves / isLegal / applyMove / win detection.
  game/
    game_controller.dart   The only engine↔UI glue (selection, commit, animation state).
  ui/
    board_view.dart        The board, destinations, route chooser.
    cube3d.dart            Faux-3D die (orthographic; top face at rest).
    tumbling_die.dart      Per-square roll animation on move commit.
    game_screen.dart       Turn banner, hand-off, win overlay.
    home_screen.dart       Mode selection.
```

Correctness lives in `core/` and is unit-tested; the UI/animation layer is verified by eye. See
[`AGENTS.md`](AGENTS.md) for conventions and invariants when working in this repo.
