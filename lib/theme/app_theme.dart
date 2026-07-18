import 'package:flutter/material.dart';
import 'colors.dart';

/// Named font families (must match pubspec `fonts:` entries).
class KFonts {
  KFonts._();
  static const ui = 'IBMPlexSansArabic'; // interface + body
  static const display = 'ReemKufi'; // logo / wordmark
  static const root = 'Amiri'; // ب ح ر root display
  static const quran = 'AmiriQuran'; // Quranic verses
}

class KTheme {
  KTheme._();

  static ThemeData get light => _base(
        brightness: Brightness.light,
        seed: KColors.teal,
        scaffold: KColors.paper,
        onSurface: KColors.ink,
      );

  static ThemeData get dark => _base(
        brightness: Brightness.dark,
        seed: KColors.dTeal,
        scaffold: KColors.dBg,
        onSurface: KColors.dText,
      );

  static ThemeData _base({
    required Brightness brightness,
    required Color seed,
    required Color scaffold,
    required Color onSurface,
  }) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: brightness,
    ).copyWith(surface: scaffold, onSurface: onSurface);

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scaffold,
      fontFamily: KFonts.ui,
      splashFactory: InkSparkle.splashFactory,
      textTheme: _textTheme(onSurface),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: TextStyle(
          fontFamily: KFonts.ui,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: brightness == Brightness.light ? KColors.teal : KColors.dTeal,
        ),
      ),
    );
  }

  static TextTheme _textTheme(Color onSurface) => TextTheme(
        // body / UI — IBM Plex Sans Arabic
        bodyLarge: TextStyle(fontSize: 18, height: 1.95, color: onSurface),
        bodyMedium: TextStyle(fontSize: 16, height: 1.9, color: onSurface),
        labelLarge: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      );
}
