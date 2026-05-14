import 'package:flutter/material.dart';

class AppColors {
  // Day (light)
  static const Color lightBackground = Color(0xFFFAF7F2);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightPrimary = Color(0xFF7DA3C7);
  static const Color lightSecondary = Color(0xFFE6B473);
  static const Color lightText = Color(0xFF2A2A2E);

  // Night (dark)
  static const Color darkBackground = Color(0xFF0E1117);
  static const Color darkSurface = Color(0xFF1A1F2A);
  static const Color darkPrimary = Color(0xFF8FB4D9);
  static const Color darkSecondary = Color(0xFFE6B473);
  static const Color darkText = Color(0xFFE8DFD0);

  // Event colors
  static const Color napColor = Color(0xFF8FB4D9);
  static const Color nightWakeColor = Color(0xFFE6B473);
  static const Color nursingColor = Color(0xFFB5D4A8);
  static const Color bottleColor = Color(0xFFA8C4D4);
  static const Color morningWakeColor = Color(0xFFF5C842);
  static const Color bedtimeColor = Color(0xFF9B8EC4);

  // Calendar day colors
  static const Color calendarGreen = Color(0xFF6BAA75);
  static const Color calendarOrange = Color(0xFFE6A84B);
  static const Color calendarRed = Color(0xFFD96B6B);
  static const Color calendarGrey = Color(0xFFBDBDBD);

  // Predictive / future events — oklch(0.72 0.07 186) soft teal
  static const Color predictionColor = Color(0xFF70BDB5);

  // Status
  static const Color errorColor = Color(0xFFD96B6B);
  static const Color successColor = Color(0xFF6BAA75);
  static const Color warningColor = Color(0xFFE6A84B);

  // Theme infrastructure — onPrimary/foreground contrast colors
  static const Color onPrimaryLight = Color(0xFFFFFFFF);
  static const Color lightInputBorder = Color(0xFFE0E0E0);
  static const Color lightCardBorder = Color(0xFFEEEBE6);
}
