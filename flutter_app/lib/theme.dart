import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// The ACUC app look (same values as the website app: acuc-global-tabbar, acuc-mobile-job-cards,
/// acuc-job-sheet, acuc-onboarding, acuc-app-login).
class AC {
  // ink & text
  static const ink = Color(0xFF14213D); // headings
  static const ink2 = Color(0xFF0B1A33); // strong text
  static const text = Color(0xFF1F2A44);
  static const sub = Color(0xFF5B6B86);
  static const muted = Color(0xFF6B7A90);
  static const faint = Color(0xFF8A94A6);
  // surfaces
  static const bg = Color(0xFFF5F7FB);
  static const bgBlue = Color(0xFFE9F0FB);
  static const card = Colors.white;
  static const line = Color(0xFFE3E8F0);
  static const pillLine = Color(0xFFD5DCE6);
  static const field = Color(0xFFF1F4F9);
  // brand
  static const brand = Color(0xFF1D4F93);
  static const brandDark = Color(0xFF173F77);
  static const blue = Color(0xFF1E63E9);
  static const blue2 = Color(0xFF3E86F7);
  static const blueSoft = Color(0xFFEAF1FF);
  static const go = Color(0xFF0A1CF0); // onboarding "Get started"
  static const green = Color(0xFF0F8A55);
  static const greenLine = Color(0xFF2FB57B);
  static const greenSoft = Color(0xFFE3F8EE);
  static const red = Color(0xFFD93636);
  static const redSoft = Color(0xFFFDECEC);
  static const badge = Color(0xFFE11D48);
  static const font = 'PlusJakartaSans';

  static const blueGradient = LinearGradient(begin: Alignment(-0.8, -1), end: Alignment(0.8, 1), colors: [blue, Color(0xFF2F7CF6)]);
  static const tabGradient = LinearGradient(begin: Alignment(-0.8, -1), end: Alignment(0.8, 1), colors: [blue, blue2]);
  static const coverGradient = LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF1D4F93), Color(0xFF3B7FD8), Color(0xFF2456A6)]);

  static List<BoxShadow> softShadow = [
    BoxShadow(color: const Color(0xFF0F172A).withValues(alpha: 0.04), blurRadius: 2, offset: const Offset(0, 1)),
  ];
}

/// Text styles used everywhere (Plus Jakarta Sans; light body like the website).
class T {
  static const h1 = TextStyle(fontFamily: AC.font, fontSize: 32, height: 1.12, fontWeight: FontWeight.w500, letterSpacing: -0.8, color: AC.ink2);
  static const title = TextStyle(fontFamily: AC.font, fontSize: 30, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: AC.ink2);
  static const name = TextStyle(fontFamily: AC.font, fontSize: 24, fontWeight: FontWeight.w500, letterSpacing: -0.3, color: AC.ink);
  static const cardTitle = TextStyle(fontFamily: AC.font, fontSize: 21, fontWeight: FontWeight.w400, color: AC.ink);
  static const body = TextStyle(fontFamily: AC.font, fontSize: 16, height: 1.5, fontWeight: FontWeight.w300, color: AC.text);
  static const bodyLight = TextStyle(fontFamily: AC.font, fontSize: 14.5, height: 1.4, fontWeight: FontWeight.w300, color: AC.sub);
  static const label = TextStyle(fontFamily: AC.font, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.6, color: AC.ink2);
}

ThemeData acucTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: AC.brand, primary: AC.brand, surface: Colors.white);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, fontFamily: AC.font, splashFactory: InkSparkle.splashFactory);
  return base.copyWith(
    scaffoldBackgroundColor: AC.bg,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: AC.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: TextStyle(fontFamily: AC.font, fontSize: 19, fontWeight: FontWeight.w700, color: AC.ink2),
    ),
    textTheme: base.textTheme.apply(bodyColor: AC.ink2, displayColor: AC.ink2),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AC.brand,
        foregroundColor: Colors.white,
        minimumSize: const Size(64, 50),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w600, fontSize: 17),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AC.ink2,
        minimumSize: const Size(64, 48),
        side: const BorderSide(color: AC.ink2, width: 1.2),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w500, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      hintStyle: const TextStyle(color: Color(0xFF8A8D91), fontWeight: FontWeight.w400, fontSize: 17),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDADDE1))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFFDADDE1))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: AC.brand, width: 1.5)),
    ),
    dividerTheme: const DividerThemeData(color: AC.line, thickness: 1, space: 1),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: AC.ink2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
      contentTextStyle: const TextStyle(fontFamily: AC.font, fontWeight: FontWeight.w600, fontSize: 14, color: Colors.white),
    ),
    pageTransitionsTheme: const PageTransitionsTheme(builders: {
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    }),
  );
}

/// The website's line icons (24×24, stroke 1.9) so the app looks exactly the same.
class Ico {
  static const home = '<path d="M3 10.5 12 3l9 7.5"/><path d="M5.5 9.5V20h13V9.5"/><path d="M10 20v-5h4v5"/>';
  static const network = '<path d="M17 21v-2a4 4 0 0 0-4-4H7a4 4 0 0 0-4 4v2"/><circle cx="10" cy="7" r="4"/><path d="M21 21v-2a3.5 3.5 0 0 0-2.6-3.4"/><path d="M15.5 3.2a4 4 0 0 1 0 7.6"/>';
  static const jobs = '<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M8 7V5.5A2.5 2.5 0 0 1 10.5 3h3A2.5 2.5 0 0 1 16 5.5V7"/><path d="M3 12.5h18"/>';
  static const messages = '<path d="M21 15a2 2 0 0 1-2 2H8l-5 4V5a2 2 0 0 1 2-2h14a2 2 0 0 1 2 2z"/>';
  static const alerts = '<path d="M6 8.5a6 6 0 1 1 12 0c0 4.2 1.4 5.7 2 6.3a1 1 0 0 1-.7 1.7H4.7a1 1 0 0 1-.7-1.7c.6-.6 2-2.1 2-6.3Z"/><path d="M9.5 19.5a2.5 2.5 0 0 0 5 0"/>';
  static const search = '<circle cx="11" cy="11" r="7"/><path d="m20 20-3.5-3.5"/>';
  static const sparkle = '<path d="M12 3l1.8 4.7L18.5 9.5l-4.7 1.8L12 16l-1.8-4.7L5.5 9.5l4.7-1.8z"/><path d="M19 15l.8 2.2L22 18l-2.2.8L19 21l-.8-2.2L16 18l2.2-.8z"/>';
  static const login = '<path d="M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4"/><path d="M10 17l5-5-5-5"/><path d="M15 12H3"/>';
  static const pin = '<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><circle cx="12" cy="9.5" r="2.5"/>';
  static const bookmark = '<path d="M6 3h12a1 1 0 0 1 1 1v17l-7-4.5L5 21V4a1 1 0 0 1 1-1z"/>';
  static const share = '<circle cx="18" cy="5" r="3"/><circle cx="6" cy="12" r="3"/><circle cx="18" cy="19" r="3"/><path d="m8.6 13.5 6.8 4"/><path d="m15.4 6.5-6.8 4"/>';
  static const close = '<path d="M18 6 6 18"/><path d="m6 6 12 12"/>';
  static const back = '<path d="m15 18-6-6 6-6"/>';
  static const eye = '<path d="M2 12s3.6-7 10-7 10 7 10 7-3.6 7-10 7S2 12 2 12z"/><circle cx="12" cy="12" r="3"/>';
  static const user = '<circle cx="12" cy="8" r="4"/><path d="M4 21v-1a6 6 0 0 1 6-6h4a6 6 0 0 1 6 6v1"/>';
  static const gear = '<circle cx="12" cy="12" r="3"/><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 1 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 1 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 1 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.6 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 1 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 1 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.6a1.65 1.65 0 0 0 1-1.51V3a2 2 0 1 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 1 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 1 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z"/>';
  static const globe = '<circle cx="12" cy="12" r="9"/><path d="M3 12h18"/><path d="M12 3a14 14 0 0 1 0 18a14 14 0 0 1 0-18z"/>';
  static const mail = '<rect x="3" y="5" width="18" height="14" rx="2"/><path d="m3 7 9 6 9-6"/>';
  static const phone = '<path d="M22 16.9v3a2 2 0 0 1-2.2 2 19.8 19.8 0 0 1-8.6-3.1 19.5 19.5 0 0 1-6-6A19.8 19.8 0 0 1 2.1 4.2 2 2 0 0 1 4.1 2h3a2 2 0 0 1 2 1.7c.1.9.4 1.8.7 2.7a2 2 0 0 1-.5 2.1L8 9.8a16 16 0 0 0 6 6l1.3-1.3a2 2 0 0 1 2.1-.4c.9.3 1.8.6 2.7.7a2 2 0 0 1 1.7 2z"/>';
  static const shield = '<path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="m9 12 2 2 4-4"/>';
  static const building = '<rect x="4" y="3" width="16" height="18" rx="2"/><path d="M9 21v-4h6v4"/><path d="M8 7h.01M12 7h.01M16 7h.01M8 11h.01M12 11h.01M16 11h.01"/>';
  static const heart = '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1-1.1a5.5 5.5 0 0 0-7.8 7.8l1 1.1L12 21l7.8-7.5 1-1.1a5.5 5.5 0 0 0 0-7.8z"/>';
  static const users = '<path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.9"/><path d="M16 3.1a4 4 0 0 1 0 7.8"/>';
  static const pen = '<path d="M12 20h9"/><path d="M16.5 3.5a2.1 2.1 0 0 1 3 3L7 19l-4 1 1-4z"/>';
  static const flag = '<path d="M4 15s1-1 4-1 5 2 8 2 4-1 4-1V3s-1 1-4 1-5-2-8-2-4 1-4 1z"/><path d="M4 22v-7"/>';
  static const check2 = '<path d="M2 12l5 5L18 6"/><path d="M12 15l2 2L22 7"/>';
  static const dots = '<circle cx="5" cy="12" r="1.3"/><circle cx="12" cy="12" r="1.3"/><circle cx="19" cy="12" r="1.3"/>';
  static const chat = '<path d="M21 11.5a8.4 8.4 0 0 1-9 8.4 9 9 0 0 1-4-.9L3 20l1.1-4A8.4 8.4 0 0 1 3 11.5 8.5 8.5 0 0 1 12 3a8.5 8.5 0 0 1 9 8.5z"/>';
  static const doc = '<path d="M14 3H6a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"/><path d="M14 3v6h6"/><path d="M8 13h8M8 17h5"/>';
  static const camera = '<path d="M4 8h3l2-3h6l2 3h3a1 1 0 0 1 1 1v10a1 1 0 0 1-1 1H4a1 1 0 0 1-1-1V9a1 1 0 0 1 1-1z"/><circle cx="12" cy="13.5" r="3.5"/>';
  static const send = '<path d="M22 2 11 13"/><path d="M22 2 15 22l-4-9-9-4z"/>';
  static const external = '<path d="M15 3h6v6"/><path d="M10 14 21 3"/><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/>';
  static const lock = '<rect x="4" y="11" width="16" height="10" rx="2"/><path d="M8 11V7a4 4 0 0 1 8 0v4"/>';
  static const logout = '<path d="M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4"/><path d="m16 17 5-5-5-5"/><path d="M21 12H9"/>';
  static const trash = '<path d="M3 6h18"/><path d="M8 6V4h8v2"/><path d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6"/>';
  static const fingerprint = '<path d="M12 11v3a8 8 0 0 0 1.5 4.6"/><path d="M8.5 12.5V11a3.5 3.5 0 0 1 7 0v2"/><path d="M5 11a7 7 0 0 1 14 0v2.5"/><path d="M8.6 16.5a10 10 0 0 0 1.4 4"/><path d="M15.6 16a12 12 0 0 1-.6 4.5"/>';
  static const help = '<circle cx="12" cy="12" r="9"/><path d="M9.1 9a3 3 0 0 1 5.8 1c0 2-3 3-3 3"/><path d="M12 17h.01"/>';
  static const grid = '<rect x="3" y="3" width="7" height="7" rx="1.5"/><rect x="14" y="3" width="7" height="7" rx="1.5"/><rect x="3" y="14" width="7" height="7" rx="1.5"/><rect x="14" y="14" width="7" height="7" rx="1.5"/>';
  static const mic = '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5 11a7 7 0 0 0 14 0"/><path d="M12 18v3"/>';
  static const compass = '<circle cx="12" cy="12" r="9"/><path d="m16 8-2.5 5.5L8 16l2.5-5.5z"/>';
  static const chevron = '<path d="m9 6 6 6-6 6"/>';
  static const star = '<path d="m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1-4.4-4.3 6.1-.9z"/>';
}

class Svg extends StatelessWidget {
  final String paths;
  final double size;
  final Color color;
  final double stroke;
  final bool fill;
  const Svg(this.paths, {super.key, this.size = 24, this.color = AC.ink, this.stroke = 1.9, this.fill = false});
  @override
  Widget build(BuildContext context) {
    final hex = '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final s = fill
        ? '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$hex" stroke="$hex" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$paths</svg>'
        : '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="$hex" stroke-width="$stroke" stroke-linecap="round" stroke-linejoin="round">$paths</svg>';
    return SvgPicture.string(s, width: size, height: size);
  }
}
