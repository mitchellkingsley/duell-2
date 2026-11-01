import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'game/deep_links.dart';
import 'game/match_store.dart';
import 'game/settings.dart';
import 'ui/home_screen.dart';
import 'ui/remote_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  await MatchStore.instance.init();

  // The token the app was opened with, if any.
  String? initialToken;
  if (kIsWeb) {
    initialToken = Uri.base.queryParameters['t'];
  } else {
    try {
      final uri = await AppLinks().getInitialLink();
      if (uri != null) initialToken = tokenFromUri(uri);
    } catch (_) {}
  }

  runApp(DuellApp(initialToken: initialToken));
}

class DuellApp extends StatefulWidget {
  const DuellApp({super.key, this.initialToken});

  final String? initialToken;

  @override
  State<DuellApp> createState() => _DuellAppState();
}

class _DuellAppState extends State<DuellApp> {
  final _navKey = GlobalKey<NavigatorState>();
  StreamSubscription<Uri>? _linkSub;

  @override
  void initState() {
    super.initState();
    // Warm deep links (app already running) on Android.
    if (!kIsWeb) {
      _linkSub = AppLinks().uriLinkStream.listen((uri) {
        final token = tokenFromUri(uri);
        if (token != null && token.isNotEmpty) {
          _navKey.currentState?.push(
            MaterialPageRoute(builder: (_) => InboundLauncher(token: token)),
          );
        }
      }, onError: (_) {});
    }
  }

  @override
  void dispose() {
    _linkSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF4A90D9),
      scaffoldBackgroundColor: const Color(0xFF15181D),
      useMaterial3: true,
      fontFamily: 'JetBrainsMono',
    );
    final token = widget.initialToken;
    return MaterialApp(
      title: 'Duell',
      debugShowCheckedModeBanner: false,
      navigatorKey: _navKey,
      themeMode: ThemeMode.dark,
      // JetBrains Mono is a variable font; nudge the default weight heavier.
      darkTheme: base.copyWith(textTheme: _heavier(base.textTheme)),
      home: (token != null && token.isNotEmpty)
          ? InboundLauncher(token: token)
          : const HomeScreen(),
    );
  }

  /// Bump the default font weight of every text style up a step (JetBrains
  /// Mono's variable weight axis renders the intermediate weight). Widgets
  /// that set their own weight still override this.
  static TextTheme _heavier(TextTheme t) {
    TextStyle? h(TextStyle? s) => s?.copyWith(fontWeight: FontWeight.w500);
    return TextTheme(
      displayLarge: h(t.displayLarge),
      displayMedium: h(t.displayMedium),
      displaySmall: h(t.displaySmall),
      headlineLarge: h(t.headlineLarge),
      headlineMedium: h(t.headlineMedium),
      headlineSmall: h(t.headlineSmall),
      titleLarge: h(t.titleLarge),
      titleMedium: h(t.titleMedium),
      titleSmall: h(t.titleSmall),
      bodyLarge: h(t.bodyLarge),
      bodyMedium: h(t.bodyMedium),
      bodySmall: h(t.bodySmall),
      labelLarge: h(t.labelLarge),
      labelMedium: h(t.labelMedium),
      labelSmall: h(t.labelSmall),
    );
  }
}
