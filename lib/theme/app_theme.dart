import 'package:flutter/material.dart';

class AppColors {
  // Deep navy backgrounds
  static const Color background = Color(0xFF0B0E1B);
  static const Color surface = Color(0xFF131A2E);
  static const Color surfaceLight = Color(0xFF1B243F);
  static const Color cardBg = Color(0xFF161F38);
  static const Color cardBorder = Color(0x2E8B5CF6);

  // Vibrant neon accents
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryPurpleLight = Color(0xFFA78BFA);
  static const Color primaryBlue = Color(0xFF06B6D4);
  static const Color primaryBlueLight = Color(0xFF38BDF8);

  // Status and reward colors
  static const Color onlineGreen = Color(0xFF10B981);
  static const Color coinAmber = Color(0xFFF59E0B);
  static const Color trophyGold = Color(0xFFFFB703);
  static const Color dangerRose = Color(0xFFF43F5E);

  // Text colors
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);
  static const Color textMuted = Color(0xFF64748B);

  // Linear Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, primaryBlue],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1E2849), Color(0xFF141B31)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient accentGlowGradient = LinearGradient(
    colors: [Color(0x408B5CF6), Color(0x1006B6D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.background,
      primaryColor: AppColors.primaryPurple,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primaryPurple,
        onPrimary: Colors.white,
        secondary: AppColors.primaryBlue,
        onSecondary: Colors.white,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.dangerRose,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
        iconTheme: IconThemeData(color: AppColors.textPrimary),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryPurple,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primaryBlueLight,
          side: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primaryBlueLight,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 12,
        selectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          height: 1.5,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.surfaceLight,
        contentTextStyle: const TextStyle(color: AppColors.textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        behavior: SnackBarBehavior.floating,
      ),
      fontFamily: 'Roboto',
    );
  }
}
