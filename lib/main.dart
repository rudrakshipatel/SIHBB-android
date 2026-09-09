import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'screens/landing.dart';
import 'services/store.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initStore();
    await loadUserProducts();
    // Seed the shared catalogue with this device's own listings so they show
    // offline; the buyer screen refreshes from Supabase to pull in everyone's.
    remoteProducts.addAll(userProducts.reversed);
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
