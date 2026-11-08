import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'share_outcome.dart';

/// Invoke the browser's Web Share API. On Android Chrome this opens the native
/// share sheet; on browsers without it, returns [ShareOutcome.unsupported] so
/// the caller can fall back to copying the link.
Future<ShareOutcome> shareLink(
    {required String text, required String url}) async {
  final navigator = web.window.navigator;
  if (!(navigator as JSObject).has('share')) return ShareOutcome.unsupported;
  try {
    await navigator.share(web.ShareData(text: text, url: url)).toDart;
  } catch (_) {
    // User dismissed the sheet, or the share failed — either way the sheet was
    // shown, so don't also copy.
  }
  return ShareOutcome.shown;
}
