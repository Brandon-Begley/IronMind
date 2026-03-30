library google_fonts;

import 'package:flutter/material.dart';

class GoogleFonts {
  static TextStyle bebasNeue({
    Color? color,
    double? fontSize,
    double? height,
    double? letterSpacing,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? backgroundColor,
    TextDecoration? decoration,
  }) {
    return _buildStyle(
      family: 'sans-serif',
      color: color,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      backgroundColor: backgroundColor,
      decoration: decoration,
    );
  }

  static TextStyle dmSans({
    Color? color,
    double? fontSize,
    double? height,
    double? letterSpacing,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? backgroundColor,
    TextDecoration? decoration,
  }) {
    return _buildStyle(
      family: 'sans-serif',
      color: color,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      backgroundColor: backgroundColor,
      decoration: decoration,
    );
  }

  static TextStyle dmMono({
    Color? color,
    double? fontSize,
    double? height,
    double? letterSpacing,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? backgroundColor,
    TextDecoration? decoration,
  }) {
    return _buildStyle(
      family: 'monospace',
      color: color,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      backgroundColor: backgroundColor,
      decoration: decoration,
    );
  }

  static TextStyle _buildStyle({
    required String family,
    Color? color,
    double? fontSize,
    double? height,
    double? letterSpacing,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    Color? backgroundColor,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      color: color,
      fontSize: fontSize,
      height: height,
      letterSpacing: letterSpacing,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      backgroundColor: backgroundColor,
      decoration: decoration,
      fontFamily: family,
    );
  }
}
