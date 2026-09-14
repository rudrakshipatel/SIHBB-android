import 'package:flutter/material.dart';
import 'theme.dart';
import 'data.dart';
import 'screens/landing.dart';
import 'services/store.dart';
import 'services/identity.dart';
import 'services/i18n.dart';
import 'services/fcm.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initStore();
    await loadIdentity();
    await appLocale.load();
    await loadUserProducts();
    // Seed the shared catalogue with this device's own listings so they show
    // offline; the buyer screen refreshes from Supabase to pull in everyone's.
    remoteProducts.addAll(userProducts.reversed);
  } catch (_) {
    // First run or storage unavailable — start with an empty catalogue.
  }
  initFcm(); // register for order push (non-blocking; self-guards)
  runApp(const HastakalaApp());
}

class HastakalaApp extends StatelessWidget {
  const HastakalaApp({super.key});
  @override
  Widget build(BuildContext context) {
    // Rebuild the entire app (fresh navigator) whenever the language changes so
    // every screen re-renders in the chosen language.
    return ListenableBuilder(
      listenable: appLocale,
      builder: (context, _) => MaterialApp(
        title: 'Hastakala',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        locale: Locale(appLocale.lang.code),
        home: const LandingScreen(),
      ),
    );
  }
}
