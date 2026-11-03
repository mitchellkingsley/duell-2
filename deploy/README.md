# Deploying Duell to Cloudflare (decade.dev)

The app is configured to serve link-based play from **https://decade.dev**:

- `lib/game/deep_links.dart` → `kLinkDomain = 'https://decade.dev'`, so turn
  links are `https://decade.dev/t?t=<token>`.
- `android/app/src/main/AndroidManifest.xml` has the verified App Link
  intent-filter for host `decade.dev`, path prefix `/t`.

Two deployable files live in `web/` and are bundled automatically by
`flutter build web`:

- `web/_redirects` — Cloudflare Pages SPA fallback so `/t?t=…` routes load the
  app.
- `web/.well-known/assetlinks.json` — the Digital Asset Links file for Android
  App Link verification (fill in your fingerprint; see step 4).

## 1. Build the static site

```bash
flutter build web --release
```

Output is in `build/web/` (index.html, assets, `_redirects`, and
`.well-known/assetlinks.json`). The default base href is `/`, correct for the
apex domain.

## 2. Deploy to Cloudflare Pages

**CLI (Wrangler):**

```bash
# First deploy creates the Pages project named "duell":
npx wrangler pages deploy build/web --project-name duell
```

(Log in when prompted: `npx wrangler login`.)

**Or dashboard:** Cloudflare → Workers & Pages → Create → Pages → “Upload
assets” → drag in the `build/web` folder.

## 3. Point decade.dev at the Pages project

Since `decade.dev` is already in your Cloudflare account:

1. Open the Pages project → **Custom domains** → **Set up a custom domain**.
2. Enter `decade.dev` (and optionally `www.decade.dev`). Cloudflare adds the
   DNS record and provisions the TLS certificate automatically (required —
   `.dev` is HSTS-preloaded, so it must be HTTPS).

Verify:

- `https://decade.dev/` loads the game.
- `https://decade.dev/t?t=test` also loads it (SPA fallback working).
- `https://decade.dev/.well-known/assetlinks.json` returns the JSON as
  `application/json`.

That is all that's needed for **web link play** to work end-to-end: two people
open `https://decade.dev`, and turn links they share open the site with the
move applied.

## 4. (Android only) Finish App Link verification

Needed only when you ship the Android app and want tapped links to open it
directly instead of the browser.

1. Get your app signing cert SHA-256 and paste it into
   `web/.well-known/assetlinks.json` (replace the placeholder):

   ```bash
   # Debug keystore:
   keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
     -storepass android -keypass android | grep SHA256
   # Release / Play App Signing: Play Console → your app → App signing →
   # "App signing key certificate" SHA-256.
   ```

   Include every signing key users might have (debug, upload, and the
   Play-managed key). Re-run `flutter build web` and redeploy so the updated
   file is live.

2. Verify on a device:

   ```bash
   adb shell pm verify-app-links --re-verify com.duell.duell
   adb shell pm get-app-links com.duell.duell   # expect: verified
   ```

### Testing without the published app

Fire the custom scheme via adb:

```bash
adb shell am start -a android.intent.action.VIEW -d "duell://turn?t=<token>"
```

## Note on local development

Because `kLinkDomain` now points at `decade.dev`, links generated while running
locally (`flutter run -d chrome`) also point at `decade.dev` — so test
link-play on the deployed site. To test links against `localhost` again,
temporarily set `kLinkDomain = null` in `lib/game/deep_links.dart`.
