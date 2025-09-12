import 'package:flutter/material.dart';

class AppColors {
  // Brand palette
  // Deep Navy — #0e172a
  static const Color deepNavy = Color(0xFF0E172A);
  // Teal Blue — #0b7593
  static const Color tealBlue = Color(0xFF0B7593);
  // University Gold — #eab308
  static const Color universityGold = Color(0xFFEAB308);
  // Off-White — #fafafa
  static const Color offWhite = Color(0xFFFAFAFA);

  // Primary/secondary mapping for app usage
  // We use Gold for primary actions (buttons, highlights)
  static const Color primaryColor = universityGold;
  // Teal as secondary/info
  static const Color secondaryColor = tealBlue;
  // Accent mirrors primary for consistency
  static const Color accentColor = universityGold;

  // Neutrals and surfaces
  static const Color backgroundLight = offWhite;
  static const Color backgroundDark = deepNavy;
  static const Color surfaceLight = Colors.white;
  // Slightly lighter than deep navy for surfaces in dark mode
  static const Color surfaceDark = Color(0xFF142033);

  // Text colors
  static const Color textPrimary = deepNavy;
  static const Color textSecondary = Color(0xFF6B7280); // neutral grey for secondary text
  static const Color textLight = Colors.white;

  // State colors
  static const Color success = Color(0xFF10B981); // keep green for success
  static const Color error = Color(0xFFEF4444);
  static const Color warning = universityGold; // use brand gold for warnings/badges when needed
  static const Color info = tealBlue; // teal for info states

  // Borders/dividers
  static const Color borderColor = Color(0xFFE5E7EB);
  static const Color dividerColor = Color(0xFFF3F4F6);
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      surface: AppColors.surfaceLight,
      background: AppColors.backgroundLight,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepNavy,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryColor, // gold
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        elevation: 0,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: AppColors.surfaceLight,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceLight,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.borderColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.secondaryColor, width: 2), // teal focus
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceLight,
      selectedItemColor: AppColors.primaryColor, // gold highlights
      unselectedItemColor: AppColors.textSecondary,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
  
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundDark,
    
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      surface: AppColors.surfaceDark,
      background: AppColors.backgroundDark,
      error: AppColors.error,
      onPrimary: Colors.white,
      onSurface: AppColors.textLight,
    ),
    
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.deepNavy,
      foregroundColor: AppColors.textLight,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.textLight,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    
    cardTheme: CardThemeData(
      color: AppColors.surfaceDark,
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    ),
    
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surfaceDark,
      selectedItemColor: AppColors.primaryColor, // gold
      unselectedItemColor: Colors.white54,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
  );
}