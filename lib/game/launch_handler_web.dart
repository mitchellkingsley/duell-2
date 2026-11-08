import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'deep_links.dart';

/// Web Launch Handler API: when the installed PWA is launched again (e.g. a turn
/// link tapped while it's already open), with `launch_handler: focus-existing`
/// in the manifest the running instance is focused and the new URL arrives here
/// instead of a fresh window. We extract the turn token and hand it to [onToken].
///
/// No-op where the API is unsupported (non-installed browsers, non-Chromium).
void listenLaunches(void Function(String token) onToken) {
  final win = web.window as JSObject;
  if (!win.has('launchQueue')) return;
  final queue = win.getProperty('launchQueue'.toJS) as JSObject?;
  if (queue == null) return;

  void consumer(JSObject params) {
    final target = params.getProperty('targetURL'.toJS);
    if (target == null || !target.isA<JSString>()) return;
    final uri = Uri.tryParse((target as JSString).toDart);
    if (uri == null) return;
    final token = tokenFromUri(uri);
    if (token != null && token.isNotEmpty) onToken(token);
  }

  queue.callMethod('setConsumer'.toJS, consumer.toJS);
}
