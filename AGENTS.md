# AGENTS.md

Guidance for AI agents (and humans) working in this repo. Read this before making changes.

## What this is

A Flutter implementation of the dice strategy game **Duell**, targeting web and Android from one
codebase. See [`README.md`](README.md) for the overview and [`PLAN.md`](PLAN.md) for the full design
and roadmap. Game rules and the move-outcome reference tables are in [`resources/`](resources/).

## Commands

```bash
flutter pub get                 # install deps
flutter analyze                 # must report "No issues found!"
flutter test                    # run the engine unit tests
flutter run -d chrome           # primary dev loop (hot reload in the browser)
flutter build web               # verify a release web build compiles
```

When driving the app in a headless browser, note that `flutter run -d web-server` does **not**
recompile on a plain page refresh — restart the run to pick up source changes.

## Architecture & conventions

- **Keep `lib/core/` pure Dart.** No `package:flutter` imports there. It is the source of truth for
  all game logic and is unit-tested with `flutter test`. The UI reads core state; it never
  re-implements rules.
- **`GameController` is the only engine↔UI glue.** State flows: widgets call controller methods →
  controller calls `Rules` → `notifyListeners()` → widgets rebuild via `AnimatedBuilder`.
- **`GameState` is immutable.** `Rules.applyMove` returns a new state; never mutate in place.
- Follow the existing style: small focused files, doc comments on public types explaining *why*,
  no dead code, no speculative abstractions.

## Invariants — do not break these

1. **Die chirality matches the reference tables.** `Die`'s tumbling defines one fixed chirality,
   anchored to `resources/duell-moves.json`. `test/die_reference_test.dart` validates every Top
   number square-by-square against that file. If you touch `die.dart`, this test must still pass.
2. **The animation must agree with the engine.** `Cube3D.stepRotation`'s rotation signs are chosen
   so that rolling the pre-step orientation 90° equals the post-step orientation from `Die.roll`.
   If you change one, re-verify the other, or the tumble will visually disagree with the result.
3. **The engine is the referee.** For any move applied from outside (future remote links), validate
   with `Rules.isLegal` before `applyMove`. Never trust a move's claimed destination or result.

## Game rules (current design)

- 9×9 board, 9 dice per side on the home row, all with **4 facing inward**.
- A die moves exactly its **top face** in squares, tumbling one square at a time, at most one 90°
  turn, no jumping, no diagonals; it captures by landing on an enemy with an exact count.
- The **King** is the center die; it moves exactly **one** square per turn.
- **Win by capturing the opponent's King.**
- Note: this diverges from the original 8×8 box-art rules transcribed in `resources/README.md` — the
  9×9 / King design in the code is intentional.

## Starting position

`lib/core/setup.dart` holds the starting layout as adjustable constants (`kHomeRowTops`, `kKingCol`).
The exact home-row top faces are a documented placeholder, not yet matched to the box art.
