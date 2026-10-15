import 'package:flutter/material.dart';

class AC {
  static const blue = Color(0xFF1D4F93);
  static const blueDark = Color(0xFF143A6E);
  static const ink = Color(0xFF0B1A33);
  static const sub = Color(0xFF5B6B86);
  static const line = Color(0xFFE3E8F0);
  static const bg = Color(0xFFF4F7FC);
  static const card = Colors.white;
  static const green = Color(0xFF0F7A4D);
  static const amber = Color(0xFFB26A00);
  static const red = Color(0xFFC62828);
  static const font = 'PlusJakartaSans';
}

ThemeData acucTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AC.blue, primary: AC.blue, surface: Colors.white);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AC.font);
  return base.copyWith(
    scaffoldBackgroundColor: AC.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AC.ink,
      elevation: 0,
      scrolledUnderElevation: 0.5,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: AC.font, fontSize: 20, fontWeight: FontWeight.w800, color: AC.ink),
    ),
    textTheme: base.textTheme.apply(bodyColor: AC.ink, displayColor: AC.ink),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AC.blue,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AC.blue,
        minimumSize: const Size(64, 50),
        side: const BorderSide(color: AC.line, width: 1.5),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.line)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.line, width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AC.blue, width: 1.5)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: AC.blue.withValues(alpha: 0.12),
      elevation: 0,
      height: 66,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => TextStyle(
            fontFamily: AC.font,
            fontSize: 12,
            fontWeight: s.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w600,
            color: s.contains(WidgetState.selected) ? AC.blue : AC.sub,
          )),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(color: s.contains(WidgetState.selected) ? AC.blue : AC.sub)),
    ),
    dividerTheme: const DividerThemeData(color: AC.line, thickness: 1, space: 1),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: AC.ink),
  );
}
