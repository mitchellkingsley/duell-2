import 'package:flutter/material.dart';

import 'game/match_store.dart';
import 'game/settings.dart';
import 'ui/home_screen.dart';
import 'ui/remote_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Settings.instance.load();
  await MatchStore.instance.init();
  runApp(const DuellApp());
}

class DuellApp extends StatelessWidget {
  const DuellApp({super.key});

  @override
  Widget build(BuildContext context) {
    // If the app was opened via a turn link (?t=...), go straight into it.
    final inboundToken = Uri.base.queryParameters['t'];
    final base = ThemeData(
      brightness: Brightness.dark,
      colorSchemeSeed: const Color(0xFF4A90D9),
      scaffoldBackgroundColor: const Color(0xFF15181D),
      useMaterial3: true,
      fontFamily: 'JetBrainsMono',
    );
    return MaterialApp(
      title: 'Duell',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      // JetBrains Mono is a variable font; nudge the default weight heavier.
      darkTheme: base.copyWith(textTheme: _heavier(base.textTheme)),
      home: (inboundToken != null && inboundToken.isNotEmpty)
          ? InboundLauncher(token: inboundToken)
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
