import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/landing.dart';

void main() => runApp(const HastakalaApp());

class HastakalaApp extends StatelessWidget {
  const HastakalaApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hastakala',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const LandingScreen(),
    );
  }
}
