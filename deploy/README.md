# Deploying link-based play

Link-based (serverless) play works out of the box on **web** using the current
page origin (`…/?t=<token>`). To make turn links open the **Android app**
directly when tapped in a messaging app, you need a domain you own, verified as
an Android App Link.

## 1. Pick a domain and point the app at it

In [`lib/game/deep_links.dart`](../lib/game/deep_links.dart), set:

```dart
const String? kLinkDomain = 'https://play.yourdomain.com';
```

Match the same host (and the `/t` path prefix) in the HTTPS `intent-filter` in
[`android/app/src/main/AndroidManifest.xml`](../android/app/src/main/AndroidManifest.xml).
Shared links then look like `https://play.yourdomain.com/t?t=<token>`.

## 2. Host the Digital Asset Links file

Serve [`assetlinks.json`](assetlinks.json) at exactly:

```
https://play.yourdomain.com/.well-known/assetlinks.json
```

over HTTPS, as `application/json`, with no redirects. Replace
`REPLACE_WITH_YOUR_APP_SIGNING_CERT_SHA256` with your app signing certificate's
SHA-256 fingerprint:

```bash
# Debug keystore:
keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey \
  -storepass android -keypass android | grep SHA256
# Release / Play App Signing: copy the SHA-256 from Play Console → App signing.
```

Include every fingerprint that signs a build users install (debug, upload, and
the Play-managed signing key).

## 3. Host a fallback web page

Put the Flutter web build (or a lightweight install page) at the domain so that
opponents **without** the app still see something useful when they open a link —
the same `?t=`/`#t=` token handling already works there.

## 4. Verify

- `adb shell pm verify-app-links --re-verify com.duell.duell`
- `adb shell pm get-app-links com.duell.duell` (look for `verified`)

### Testing without a domain

Use the custom scheme (not linkified by messaging apps, but fine for local
testing):

```bash
adb shell am start -a android.intent.action.VIEW -d "duell://turn?t=<token>"
```
