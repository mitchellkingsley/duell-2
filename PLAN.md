# Duell — Top-Level Plan

A digital implementation of **Duell** (the 1976 dice strategy board game; rules transcribed in
[`resources/README.md`](resources/README.md), move tables in [`resources/duell-moves.json`](resources/duell-moves.json)).

This is the **top-level plan**. Each numbered component is intentionally kept at summary altitude
and is expected to spawn its own detailed design doc (`docs/<component>.md`) as work begins.

---

## 1. Product goals

A two-player, turn-based game of Duell, playable two ways:

- **Local (pass-and-play):** both players share one device, taking turns in the same app — no
  links, no waiting (see §5a).
- **Remote (async):** players are in different locations; there is **no live server** in v1. A turn
  is **submitted as a tappable link** over any messaging app. The opponent taps it, and the move is
  applied to their local app state.
- The board visibly animates each die **tumbling** into its new position (no teleporting).
- Candidate moves and their outcomes are **previewable** before committing.
- The whole game is **playable and testable in a browser**, and ships as an **Android** app from
  one codebase.

### Non-goals (v1)

- Real-time/live sync, matchmaking, lobbies, presence, or push notifications.
- Accounts, persistence beyond local device, or anti-cheat guarantees against a hostile opponent
  (the engine guarantees *legal* states, not *honest* ones — see §5).
- iOS (architecture should not preclude it; see §9).

---

## 2. Framework decision

**Flutter** (Dart), targeting **Web** (dev loop + play) and **Android** (primary ship).

Rationale (qualified in prior discussion):

- **Browser-testable:** `flutter run -d chrome` hot-reloads the full game from the same codebase
  that builds the APK. Fast loop for logic and UI.
- **Faux-3D animation** via `Transform` + `Matrix4` + `AnimationController` — works identically on
  web and Android, no 3D engine dependency (see §7).
- **Single codebase** for both targets.

**Known boundary:** the deep-link OS plumbing (Android App Links, intent filters, `assetlinks.json`)
is Android-native and **does not run in the browser**. The browser exercises everything *above*
transport — board, engine, move codec — via a `?t=` URL param that funnels into the same handler.
Device/emulator testing is still required for the actual link-tap flow.

> Expand in: `docs/framework-and-targets.md`

---

## 3. Architecture overview

Strict separation between a **pure-Dart core** (no Flutter imports, unit-testable with `dart test`)
and the **Flutter presentation + platform layers**.

```
┌─────────────────────────────────────────────────────────┐
│ Presentation (Flutter)                                   │
│   board widget · DieCube renderer · TumbleController     │
│   interaction (tap-select, hover-preview)                │
├─────────────────────────────────────────────────────────┤
│ Platform                                                 │
│   deep-link layer (app_links / web URL param)            │
│   local persistence (match state on device)              │
├─────────────────────────────────────────────────────────┤
│ Core  (pure Dart — no Flutter)                           │
│   GameState · Die orientation model · rules engine       │
│   reachableMoves() · applyMove() · validateMove()        │
│   move codec (base64url) · state hash                    │
└─────────────────────────────────────────────────────────┘
```

Design rule: **correctness lives in the core and is unit-tested; the animation/UI layer is
eyeball-verified.** The presentation layer reads core state and never re-implements rules.

> Expand in: `docs/architecture.md`

---

## 4. Core engine (pure Dart)

The authoritative, deterministic model of the game. No Flutter, no I/O.

Components:

- **Die orientation model** — the 6 face values (`top/bottom/north/south/east/west`); opposite
  faces sum to 7; a single consistent chirality (as validated when generating `duell-moves.json`).
- **`GameState`** — board (9×9), piece positions and orientations, whose turn, King-piece identity,
  turn sequence number.
- **Rules engine:**
  - `reachableMoves(piece) → [{square, resultTop, paths}]` — every legal destination for a die,
    with the resulting top face per path. Backed by the `duell-moves.json` logic.
  - `validateMove(move)` — is this a legal move from the current state? (distance = top face,
    one turn max, no jumping, no diagonals, exact-count capture, King moves one space).
  - `applyMove(move) → GameState` — produces the next state, including captures and win detection.
- **King piece** — the center die of each home row. It may move only one square per turn.
- **Win detection** — a player wins by capturing the opponent's King.

> Expand in: `docs/core-engine.md`

---

## 5a. Local (pass-and-play) mode

The simplest mode, and the one that needs **no transport layer at all** — both players use the same
device and hand it back and forth.

- Both moves apply directly through the core engine (`validateMove` → `applyMove`); no codec, no
  link, no sync checks (there is only one `GameState`).
- Shares **100%** of the core engine, board, interaction, and tumble animation with remote mode —
  the only difference is that the "submit turn" step applies locally instead of producing a link.
- **Turn hand-off UX:** between turns, show a neutral "pass the device to <player>" interstitial so
  the next player doesn't see a mid-animation board or the previous player's selection state.
- Good first playable: it exercises the entire engine + UI + animation stack **before** any
  deep-link work exists, and remains the fastest way to smoke-test the game end-to-end.
- Mode selection (Local vs. Remote) is a front-door choice; a `GameMode` flag on the match decides
  whether committing a turn applies locally or emits a link.

> Expand in: `docs/local-mode.md`

## 5. Turn-transport & integrity (serverless remote mode)

A move is carried in a **link fragment**: `https://play.<domain>/t#<payload>`.

- **Payload = the move delta, not the board** (length limits; determinism makes full state
  unnecessary). Compact binary → base64url, placed after `#` so it never hits the server (offline,
  private).
- **Payload fields (minimum):** `gameId | seq | move | resultStateHash`.
- **Integrity checks on receive** — the receiving engine is the referee:
  1. `gameId` matches this match.
  2. `seq == expected next` → idempotent against double-tap / replay / stale links.
  3. `validateMove` passes → never apply an illegal move.
  4. After apply, local board hash `== resultStateHash` → else "games out of sync," refuse.
- **Trust boundary:** this prevents illegal *states*, not a determined cheater. Acceptable for v1;
  a future relay server (§9) would close the gap.

> Expand in: `docs/turn-transport.md`

---

## 6. Deep-link / platform layer

- **Android App Links** (HTTPS, verified) so taps in SMS/WhatsApp/Signal/etc. open the app
  directly; messaging apps linkify `http(s)` but often not custom schemes.
  - Host `/.well-known/assetlinks.json` (exact signing-cert SHA-256, incl. Play re-signing key).
  - Host an **install-fallback web page** for opponents without the app.
- **Custom scheme** (`duell://`) registered too, as a **dev/test fallback** (trivial to fire via
  `adb`); not relied on for real delivery.
- **`app_links`** package handles cold-start (launched by link) **and** warm (already running).
- **Web:** same payload handler reads a `?t=` query param — gives the codec browser coverage.

> Expand in: `docs/deep-links.md`

---

## 7. Board & die rendering

- **Board widget** — 9×9 grid via `CustomPaint` (crisp, scalable, cheap repaints) with an overlay
  layer for highlights and result labels.
- **`DieCube`** — renders a die from an orientation + a perspective `Matrix4`; paints the ≤3
  visible faces with pips. Pure presentation; knows nothing about rules.
- Faux-3D: `Transform` + `Matrix4` perspective, no 3D engine. Web + Android identical.

> Expand in: `docs/rendering.md`

---

## 8. Interaction & animation

- **Select-then-preview (all platforms):** tap a die → highlight every reachable square with its
  resulting top face. Primary interaction; works on touch.
- **Hover-preview (web/desktop bonus):** `MouseRegion` shows the same preview without committing;
  degrades to nothing on touch. Surface **both outcomes** on dual-path squares (the key strategic
  hint).
- **Tumble animation (`TumbleController`):** replays a validated move's path as a chain of 90°
  quarter-turns, one per square, snapping orientation to the engine's value after each step so pips
  stay correct and the final top face **equals `resultTop`**. Turning moves switch axis mid-chain.
  - Plays **on commit** — own move on confirm, opponent's move when a link is applied.
  - **Instant/skip mode** for fast-forward and tests.
  - Start **crisp** (mechanical 90° pivots); add easing/bounce polish later.

> Expand in: `docs/interaction-and-animation.md`

---

## 9. Future / expansion hooks

Design now so these don't require rewrites:

- **Relay/websocket server** — the same move-delta codec drops onto a server for live sync, push
  "your turn," and stronger anti-cheat. Deep-link and server paths can coexist.
- **iOS** — Universal Links are the App-Links analog; keep core pure-Dart and platform code thin.
- **Save/resume & multiple concurrent matches** — `gameId` already scopes this.
- **Replay/history** — the ordered move list is a full game transcript.

> Expand in: `docs/roadmap.md`

---

## 10. Suggested build order

1. **Core engine** + unit tests (`reachableMoves`, `validateMove`, `applyMove`, hash) against
   `duell-moves.json`. Runs headless in `dart test`.
2. **Static board + `DieCube`** rendering a `GameState` in the browser.
3. **Interaction** (tap-select, hover-preview) wired to `reachableMoves`.
4. **`TumbleController`** animation (crisp), verified in-browser.
5. **Local (pass-and-play) mode** — first fully playable game end-to-end, no transport needed.
   Validates the entire engine + UI + animation stack.
6. **Move codec** + integrity checks; test round-trips and replay/desync handling.
7. **Deep-link layer** — web `?t=` first, then Android custom scheme via `adb`, then verified
   HTTPS App Links last.
8. **Local persistence** + multi-match.
9. Polish: animation easing, install-fallback page, edge-case UX (sync errors, illegal links).

> Each step gets its own doc under `docs/` as it is picked up.
