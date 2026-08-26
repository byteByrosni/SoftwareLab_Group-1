import 'package:flutter/material.dart';

class C {
  static const green900 = Color(0xFF0F4A2A);
  static const green800 = Color(0xFF12633A);
  static const green700 = Color(0xFF15803D);
  static const green600 = Color(0xFF16A34A);
  static const green500 = Color(0xFF22C55E);
  static const green100 = Color(0xFFDCFCE7);
  static const green50 = Color(0xFFEFFCF2);
  static const amber = Color(0xFFF59E0B);
  static const amber100 = Color(0xFFFEF3C7);
  static const amber700 = Color(0xFFB45309);
  static const sky = Color(0xFF0EA5E9);
  static const sky100 = Color(0xFFE0F2FE);
  static const ink900 = Color(0xFF0F1E17);
  static const ink700 = Color(0xFF3B4A43);
  static const ink500 = Color(0xFF6B7A72);
  static const ink300 = Color(0xFFAAB4AE);
  static const bg = Color(0xFFF4FAF4);
  static const card = Color(0xFFFFFFFF);
  static const danger = Color(0xFFDC2626);
  static const line = Color(0xFFE7EFE8);

  static const gradGreen = LinearGradient(colors: [green700, green500], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradSun = LinearGradient(colors: [Color(0xFFFBBF24), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight);
  static const gradSky = LinearGradient(colors: [Color(0xFF38BDF8), Color(0xFF0284C7)], begin: Alignment.topLeft, end: Alignment.bottomRight);
}

const kFont = 'HindSiliguri';

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: kFont,
    fontFamilyFallback: const ['Roboto', 'Noto Sans Bengali', 'sans-serif'],
    scaffoldBackgroundColor: C.bg,
    colorScheme: ColorScheme.fromSeed(seedColor: C.green600, primary: C.green600, surface: C.card).copyWith(
      onSurface: C.ink900,
    ),
    splashFactory: InkRipple.splashFactory,
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink900, displayColor: C.ink900),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFFF1F6F1),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.green600, width: 1.6)),
      hintStyle: const TextStyle(color: C.ink300),
    ),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

// text style helpers
TextStyle tsH1() => const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: C.ink900, letterSpacing: -0.3);
TextStyle tsH2() => const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: C.ink900);
TextStyle tsBody() => const TextStyle(fontSize: 14, color: C.ink700, height: 1.5);
TextStyle tsSub() => const TextStyle(fontSize: 13.5, color: C.ink500, height: 1.5);
TextStyle tsMuted() => const TextStyle(fontSize: 12.5, color: C.ink500);
