import 'package:flutter/material.dart';

class AppColors {
  // Brand & Accent
  static const Color primaryBlue = Color(0xFF455A75);
  static const Color accentBlue = Color(0xFF7E97B8);

  // Light theme
  static const Color scaffoldBg = Color(0xFFDDE3ED);
  static const Color cardBg = Colors.white;
  static const Color textDark = Color(0xFF2D3142);
  static const Color textLight = Color(0xFF9094A6);

  // Event/Task colors
  static const Color work = Color(0xFFFF8A00);
  static const Color classColor = Color(0xFFA155FF);
  static const Color deadline = Color(0xFFFF4B4B);
  static const Color task = Color(0xFF00C566);
  static const Color workshift = Color(0xFF00B8D9);
  static const Color todayChip = Color(0xFFE9EDF5);
  static const Color scheduleBlue = Color(0xFF3B82F6);

  // Dark theme
  static const Color scaffoldBgDark = Color(0xFF121212);
  static const Color cardBgDark = Color(0xFF1E1E1E);
  static const Color textDarkDark = Color(0xFFE0E0E0);
  static const Color textLightDark = Color(0xFFA0A0A0);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.scaffoldBg,
    cardColor: AppColors.cardBg,
    primaryColor: AppColors.primaryBlue,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryBlue,
      secondary: AppColors.accentBlue,
      surface: AppColors.cardBg,
      background: AppColors.scaffoldBg,
      onSurface: AppColors.textDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      outline: Color(0xFFE0E0E0), // Grey shade 300 equivalent
      outlineVariant: Color(0xFFEEEEEE),
    ),
    inputDecorationTheme: InputDecorationTheme(
      fillColor: Colors.grey[50],
      labelStyle: TextStyle(color: Colors.grey[600]),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textDark),
      bodyMedium: TextStyle(color: AppColors.textDark),
      bodySmall: TextStyle(color: AppColors.textLight),
      titleLarge:
          TextStyle(color: AppColors.textDark, fontWeight: FontWeight.bold),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.scaffoldBgDark,
    cardColor: AppColors.cardBgDark,
    primaryColor: AppColors.primaryBlue,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryBlue,
      secondary: AppColors.accentBlue,
      surface: AppColors.cardBgDark,
      background: AppColors.scaffoldBgDark,
      onSurface: AppColors.textDarkDark,
      onPrimary: Colors.white,
      onSecondary: Colors.white,
      outline: Color(0xFF616161), // Grey 700
      outlineVariant: Color(0xFF424242), // Grey 800
    ),
    inputDecorationTheme: const InputDecorationTheme(
      fillColor: Color(0xFF23272F),
      labelStyle: TextStyle(color: Color(0xFFBDBDBD)), // Grey 400
      border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(12))),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textDarkDark),
      bodyMedium: TextStyle(color: AppColors.textDarkDark),
      bodySmall: TextStyle(color: AppColors.textLightDark),
      titleLarge:
          TextStyle(color: AppColors.textDarkDark, fontWeight: FontWeight.bold),
    ),
  );
}
