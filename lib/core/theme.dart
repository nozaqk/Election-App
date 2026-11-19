import 'package:flutter/material.dart';

/// Design tokens ported from the web app's stylesheet.
class AppColors {
  static const Color green = Color(0xFF0B3D2E);
  static const Color green2 = Color(0xFF15674D);
  static const Color gold = Color(0xFFF2C94C);
  static const Color red = Color(0xFFA62D2D);
  static const Color amber = Color(0xFF8A5A00);

  // Light scheme
  static const Color bgLight = Color(0xFFF6F4EE);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color inkLight = Color(0xFF14221C);
  static const Color mutedLight = Color(0xFF5D6B64);
  static const Color lineLight = Color(0xFFDCD8CB);

  // Dark scheme
  static const Color bgDark = Color(0xFF0D1713);
  static const Color cardDark = Color(0xFF15231C);
  static const Color inkDark = Color(0xFFEEF3EF);
  static const Color mutedDark = Color(0xFF9DB0A6);
  static const Color lineDark = Color(0xFF284037);
  static const Color green2Dark = Color(0xFF2D9B76);

  // Bluetooth badge
  static const Color btOff = Color(0xFFD93636);
  static const Color btOn = Color(0xFFF2B705);
  static const Color btNode = Color(0xFF1FA855);
}

/// Background/foreground pair for a status pill.
class PillColors {
  final Color bg;
  final Color fg;
  const PillColors(this.bg, this.fg);
}

/// Pill colours per election status (light scheme; dark uses the same hues
/// at reduced opacity via [pillColorsFor]).
PillColors pillColorsFor(String status, {bool dark = false}) {
  switch (status) {
    case 'ACTIVE':
      return dark
          ? const PillColors(Color(0xFF123B2A), Color(0xFF7FE0B2))
          : const PillColors(Color(0xFFD8F3E4), Color(0xFF0A6B3D));
    case 'SCHEDULED':
      return dark
          ? const PillColors(Color(0xFF3D3413), Color(0xFFF2D98C))
          : const PillColors(Color(0xFFFDF0C7), Color(0xFF7A5600));
    case 'PAUSED':
    case 'DEACTIVATED':
      return dark
          ? const PillColors(Color(0xFF3D1B1B), Color(0xFFF2A3A3))
          : const PillColors(Color(0xFFF4DEDE), Color(0xFFA62D2D));
    case 'PUBLISHED':
      return dark
          ? const PillColors(Color(0xFF1B2A4A), Color(0xFFA9C6F5))
          : const PillColors(Color(0xFFDDE8FB), Color(0xFF1D4BA0));
    default:
      return dark
          ? const PillColors(Color(0xFF1E2E26), Color(0xFF9DB0A6))
          : const PillColors(Color(0xFFE7EFE9), Color(0xFF0B3D2E));
  }
}

/// Rounded-corner radius used across cards and inputs.
const double kRadius = 14;

/// Maximum content width (phones stretch edge-to-edge, tablets centred).
const double kMaxContentWidth = 640;

ThemeData buildLightTheme() => _buildTheme(Brightness.light);

ThemeData buildDarkTheme() => _buildTheme(Brightness.dark);

ThemeData _buildTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final bg = dark ? AppColors.bgDark : AppColors.bgLight;
  final card = dark ? AppColors.cardDark : AppColors.cardLight;
  final ink = dark ? AppColors.inkDark : AppColors.inkLight;
  final muted = dark ? AppColors.mutedDark : AppColors.mutedLight;
  final line = dark ? AppColors.lineDark : AppColors.lineLight;
  final accent = dark ? AppColors.green2Dark : AppColors.green2;

  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.green,
    brightness: brightness,
    primary: AppColors.green,
    secondary: accent,
    surface: card,
    onSurface: ink,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
    fontFamilyFallback: const ['Roboto', 'sans-serif'],
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.green,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardTheme(
      color: card,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
        side: BorderSide(color: line),
      ),
      margin: const EdgeInsets.symmetric(vertical: 6),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: card,
      selectedItemColor: AppColors.green,
      unselectedItemColor: muted,
      type: BottomNavigationBarType.fixed,
      showUnselectedLabels: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: line),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: BorderSide(color: line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadius),
        borderSide: const BorderSide(color: AppColors.green2, width: 1.6),
      ),
      labelStyle: TextStyle(color: muted),
      hintStyle: TextStyle(color: muted),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.green,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadius),
        ),
        side: const BorderSide(color: AppColors.green),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: AppColors.green2),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.green2,
    ),
    listTileTheme: ListTileThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadius),
      ),
    ),
  );
}
