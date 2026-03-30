import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IronMindColors {
  static const Color background = Color(0xFF0A0A0B);
  static const Color surface = Color(0xFF141416);
  static const Color surfaceElevated = Color(0xFF1C1C1F);
  static const Color border = Color(0xFF2A2A2F);
  static const Color accent = Color(0xFF47B4FF);
  static const Color accentDim = Color(0xFF1A3A52);
  static const Color success = Color(0xFF47FF8A);
  static const Color alert = Color(0xFFFF4747);
  static const Color warning = Color(0xFFFFB347);
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8A8A9A);
  static const Color textMuted = Color(0xFF4A4A5A);
}

// Compatibility palette for older screens/widgets that still reference
// the previous theme API.
class IronMindTheme {
  static const Color bg = IronMindColors.background;
  static const Color surface = IronMindColors.surface;
  static const Color surface2 = IronMindColors.surfaceElevated;
  static const Color surface3 = IronMindColors.border;
  static const Color border = IronMindColors.border;
  static const Color border2 = IronMindColors.border;
  static const Color accent = IronMindColors.accent;
  static const Color accentDim = IronMindColors.accentDim;
  static const Color textPrimary = IronMindColors.textPrimary;
  static const Color text2 = IronMindColors.textSecondary;
  static const Color text3 = IronMindColors.textMuted;
  static const Color green = IronMindColors.success;
  static const Color blue = IronMindColors.accent;
  static const Color orange = IronMindColors.warning;
  static const Color red = IronMindColors.alert;
  static const Color redDim = Color(0xFF4A1F23);
}

ThemeData buildIronMindTheme() {
  return ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: IronMindColors.background,
    colorScheme: const ColorScheme.dark(
      primary: IronMindColors.accent,
      surface: IronMindColors.surface,
      error: IronMindColors.alert,
    ),
    textTheme: TextTheme(
      displayLarge: GoogleFonts.bebasNeue(
        color: IronMindColors.textPrimary,
        fontSize: 48,
        letterSpacing: 2,
      ),
      displayMedium: GoogleFonts.bebasNeue(
        color: IronMindColors.textPrimary,
        fontSize: 32,
        letterSpacing: 1.5,
      ),
      displaySmall: GoogleFonts.bebasNeue(
        color: IronMindColors.textPrimary,
        fontSize: 24,
        letterSpacing: 1,
      ),
      bodyLarge: GoogleFonts.dmSans(
        color: IronMindColors.textPrimary,
        fontSize: 16,
      ),
      bodyMedium: GoogleFonts.dmSans(
        color: IronMindColors.textSecondary,
        fontSize: 14,
      ),
      bodySmall: GoogleFonts.dmMono(
        color: IronMindColors.textSecondary,
        fontSize: 12,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: IronMindColors.surfaceElevated,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: IronMindColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: IronMindColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: IronMindColors.accent, width: 1.5),
      ),
      labelStyle: GoogleFonts.dmSans(color: IronMindColors.textSecondary),
      hintStyle: GoogleFonts.dmSans(color: IronMindColors.textMuted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: IronMindColors.accent,
        foregroundColor: IronMindColors.background,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
        textStyle: GoogleFonts.bebasNeue(fontSize: 18, letterSpacing: 1.5),
      ),
    ),
  );
}
