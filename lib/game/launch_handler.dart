import 'launch_handler_stub.dart'
    if (dart.library.js_interop) 'launch_handler_web.dart' as impl;

/// Register a consumer for Launch Handler events (installed-PWA re-launches on
/// the web). [onToken] receives the turn token from the launching URL. No-op
/// on platforms/browsers without the API.
void listenLaunches(void Function(String token) onToken) =>
    impl.listenLaunches(onToken);
