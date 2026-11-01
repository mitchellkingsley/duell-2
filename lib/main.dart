import 'package:flutter/material.dart';

import 'ui/home_screen.dart';

void main() {
  runApp(const DuellApp());
}

class DuellApp extends StatelessWidget {
  const DuellApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Duell',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF2E6FB8),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
