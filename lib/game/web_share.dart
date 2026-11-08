import 'share_outcome.dart';
import 'web_share_stub.dart' if (dart.library.js_interop) 'web_share_web.dart'
    as impl;

export 'share_outcome.dart';

/// Share [url] (with accompanying [text]) via the platform's native share sheet
/// where available (the Web Share API on the web). Returns
/// [ShareOutcome.unsupported] when there's no native share, so the caller can
/// fall back to copying the link.
Future<ShareOutcome> shareLink({required String text, required String url}) =>
    impl.shareLink(text: text, url: url);
