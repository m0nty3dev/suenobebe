import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTypography {
  static TextTheme get textTheme => GoogleFonts.interTextTheme(
        const TextTheme(
          displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5),
          displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
          headlineLarge: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
          headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
          headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
          titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
          bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
          bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
          labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: 0.1),
          labelSmall: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, letterSpacing: 0.5),
        ),
      );
}
