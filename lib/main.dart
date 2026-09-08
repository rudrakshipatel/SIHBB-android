import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/landing.dart';
import 'services/store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initStore();
    await loadUserProducts();
  } catch (_) {
    // First run or storage unavailable — start with an empty catalogue.
  }
  runApp(const HastakalaApp());
}

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
