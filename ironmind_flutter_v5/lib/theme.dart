import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class IronMindTheme {
  static const Color bg = Color(0xFF0A0A0B);
  static const Color surface = Color(0xFF111113);
  static const Color surface2 = Color(0xFF1A1A1E);
  static const Color surface3 = Color(0xFF222228);
  static const Color border = Color(0x12FFFFFF);
  static const Color border2 = Color(0x1FFFFFFF);
  static const Color accent = Color(0xFF47B4FF);
  static const Color accentDim = Color(0x1A47B4FF);
  static const Color textPrimary = Color(0xFFF0EDE8);
  static const Color text2 = Color(0xFF9B9890);
  static const Color text3 = Color(0xFF5C5A56);
  static const Color red = Color(0xFFFF4747);
  static const Color redDim = Color(0x1AFF4747);
  static const Color green = Color(0xFF47FF8A);
  static const Color greenDim = Color(0x1A47FF8A);
  static const Color blue = Color(0xFF47B4FF);
  static const Color blueDim = Color(0x1A47B4FF);
  static const Color orange = Color(0xFFFF9447);
  static const Color orangeDim = Color(0x1AFF9447);
  static const Color purple = Color(0xFFB47FFF);
  static const Color purpleDim = Color(0x1AB47FFF);

  static ThemeData get theme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: bg,
    colorScheme: const ColorScheme.dark(
      primary: accent, surface: surface, background: bg,
    ),
    textTheme: GoogleFonts.dmSansTextTheme(ThemeData.dark().textTheme),
    appBarTheme: AppBarTheme(
      backgroundColor: surface,
      foregroundColor: textPrimary,
      elevation: 0,
      titleTextStyle: GoogleFonts.bebasNeue(color: textPrimary, fontSize: 22, letterSpacing: 3),
      iconTheme: const IconThemeData(color: text2),
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: TabBarThemeData(
      dividerColor: border,
      indicatorColor: accent,
      labelColor: accent,
      unselectedLabelColor: text3,
      labelStyle: GoogleFonts.dmMono(fontSize: 10),
      unselectedLabelStyle: GoogleFonts.dmMono(fontSize: 10),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface2,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: border2)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: accent)),
      labelStyle: GoogleFonts.dmMono(color: text2, fontSize: 12),
      hintStyle: GoogleFonts.dmMono(color: text3, fontSize: 12),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: MaterialStateProperty.resolveWith((s) => s.contains(MaterialState.selected) ? accent : Colors.transparent),
      checkColor: MaterialStateProperty.all(bg),
      side: const BorderSide(color: border2),
    ),
    dividerColor: border,
    snackBarTheme: SnackBarThemeData(
      backgroundColor: surface2,
      contentTextStyle: GoogleFonts.dmSans(color: textPrimary, fontSize: 13),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
