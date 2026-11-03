/// Deep-link helpers shared by the web (?t= URL param) and Android (App Link /
/// custom scheme) transports.
library;

/// The base used to build shareable turn links.
///
/// - Leave null for local web development: links use the current page origin
///   (e.g. http://localhost:8087/?t=…), which the app reads back from the URL.
/// - Set to the HTTPS domain you own and have verified for App Links
///   (e.g. 'https://play.duell.example') so taps on another person's Android
///   device open the app directly. Must match the host/pathPrefix in
///   AndroidManifest.xml and the domain hosting assetlinks.json.
// ignore: unnecessary_nullable_for_final_variable_declarations
const String? kLinkDomain = 'https://decade.dev'; // null => use the web origin

/// Extract a turn token from an inbound URI, accepting it either as the `t`
/// query parameter or after a `#t=` fragment.
String? tokenFromUri(Uri uri) {
  final q = uri.queryParameters['t'];
  if (q != null && q.isNotEmpty) return q;
  final frag = uri.fragment;
  if (frag.startsWith('t=') && frag.length > 2) return frag.substring(2);
  return null;
}

/// Build a shareable link carrying [token]. With [kLinkDomain] set, uses the
/// `/t?t=` path that the Android App Link verifies; otherwise falls back to the
/// running web app's origin with a root `?t=` (served by the Flutter web app).
String buildTurnLink(String token, {required String webOrigin}) {
  if (kLinkDomain != null) return '$kLinkDomain/t?t=$token';
  return '$webOrigin/?t=$token';
}
