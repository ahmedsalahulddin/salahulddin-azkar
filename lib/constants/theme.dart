import 'package:flutter/material.dart';

/// The Uthmanic face the bundled Quran text is set in. Anything rendering
/// ayah text — the Mushaf's fallback page, a search hit — has to ask for it by
/// name, so it lives with the other constants rather than in one screen.
const mushafFont = 'AmiriQuran';

class AppColors {
  // Primary - Metallic Gold
  static const gold = Color(0xFFB8860B);
  static const goldLight = Color(0xFFD4A843);
  static const goldDark = Color(0xFF8B6508);
  static const goldMuted = Color(0x26B8860B); // 15%
  static const goldBorder = Color(0x4DB8860B); // 30%

  // Background
  static const black = Color(0xFF0D0D0D);
  static const blackLight = Color(0xFF1A1A1A);
  static const blackCard = Color(0xFF141414);
  static const blackSurface = Color(0xFF1E1E1E);

  // Accent - Deep Navy (prayer card / hero surfaces)
  static const navy = Color(0xFF0F1A2E);
  static const navyLight = Color(0xFF16233D);

  // Accent - Emerald Green
  static const emerald = Color(0xFF2D5016);
  static const emeraldLight = Color(0xFF3D6B1E);
  static const emeraldMuted = Color(0x332D5016); // 20%

  // Text
  static const textPrimary = Color(0xFFF5F0E8);
  static const textSecondary = Color(0xFFB8A88A);
  static const textMuted = Color(0xFF7A6F5F);
  static const textGold = Color(0xFFD4A843);

  // Status
  static const white = Color(0xFFFFFFFF);
  static const error = Color(0xFFCF6679);
  static const success = Color(0xFF4CAF50);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.black,
    primaryColor: AppColors.gold,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.gold,
      secondary: AppColors.emerald,
      surface: AppColors.blackCard,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.black,
      foregroundColor: AppColors.gold,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        color: AppColors.gold,
        fontSize: 20,
        fontWeight: FontWeight.bold,
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.blackCard,
      selectedItemColor: AppColors.gold,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    // Every message the app answers a tap with is a SnackBar, and each one
    // sets its own dark background without setting a text colour. Material
    // then supplies onInverseSurface — which in a dark theme is itself
    // dark, so the message arrived as an empty black box: the reader saw
    // that something had been said and could not read a word of it. Named
    // here rather than at the forty-four call sites.
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: AppColors.blackCard,
      contentTextStyle: TextStyle(color: AppColors.textPrimary, fontSize: 14),
      actionTextColor: AppColors.gold,
      behavior: SnackBarBehavior.floating,
    ),
  );
}

enum FontSizeOption { small, medium, large }

class AppFontSizes {
  static double dhikr(FontSizeOption size) {
    switch (size) {
      case FontSizeOption.small:
        return 18;
      case FontSizeOption.medium:
        return 22;
      case FontSizeOption.large:
        return 28;
    }
  }

  static double source(FontSizeOption size) {
    switch (size) {
      case FontSizeOption.small:
        return 12;
      case FontSizeOption.medium:
        return 14;
      case FontSizeOption.large:
        return 16;
    }
  }
}
