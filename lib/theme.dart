import 'package:flutter/material.dart';

/// Hastakala brand palette — mirrors the web app.
class AppColors {
  static const green = Color(0xFF22402E);
  static const greenDark = Color(0xFF16281C);
  static const greenSoft = Color(0xFF2F7A54);
  static const terracotta = Color(0xFFB55A34);
  static const kala = Color(0xFFC0402A);
  static const gold = Color(0xFFD98A3D);
  static const cream = Color(0xFFFBF7EF);
  static const creamDeep = Color(0xFFF1E7D6);
  static const ink = Color(0xFF2B2B27);
  static const muted = Color(0xFF6B6B60);
  static const line = Color(0x14000000);
}

/// Elegant serif for the wordmark and section headings (Android renders a serif face).
const String kSerif = 'serif';

ThemeData buildTheme() {
  final base = ThemeData(useMaterial3: true, brightness: Brightness.light);
  return base.copyWith(
    scaffoldBackgroundColor: AppColors.cream,
    colorScheme: base.colorScheme.copyWith(
      primary: AppColors.green,
      secondary: AppColors.terracotta,
      surface: Colors.white,
      surfaceTint: Colors.transparent,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.line),
      ),
      margin: EdgeInsets.zero,
    ),
    textTheme: base.textTheme.apply(bodyColor: AppColors.ink, displayColor: AppColors.ink),
  );
}

/// Serif display text style helper.
TextStyle serif({double size = 22, FontWeight weight = FontWeight.w700, Color? color, double height = 1.05}) =>
    TextStyle(fontFamily: kSerif, fontSize: size, fontWeight: weight, color: color ?? AppColors.ink, height: height);
