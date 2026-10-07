import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static const mint = Color(0xFFDFF7EC);
  static const primarySoft = Color(0xFFDDEBFF);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);

  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: const Color(AppConstants.backgroundColor),
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(AppConstants.primaryColor),
        brightness: Brightness.light,
        surface: surface,
      ).copyWith(
        primary: const Color(AppConstants.primaryColor),
        onPrimary: Colors.white,
        secondary: const Color(AppConstants.accentColor),
        tertiary: const Color(AppConstants.successColor),
        surface: surface,
        onSurface: const Color(AppConstants.textDark),
        outline: border,
      ),
      visualDensity: VisualDensity.standard,
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(AppConstants.backgroundColor),
        foregroundColor: const Color(AppConstants.textDark),
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        toolbarHeight: 68,
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: Color(AppConstants.textDark),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: const Color(AppConstants.primaryColor),
        unselectedItemColor: const Color(AppConstants.textLight),
        elevation: 10,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 10),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          side: BorderSide(color: border),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(AppConstants.primaryColor),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: const Color(AppConstants.primaryColor),
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
          shadowColor: Colors.transparent,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 13,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: Color(AppConstants.primaryColor),
            width: 1.6,
          ),
        ),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.bold,
          color: Color(AppConstants.textDark),
        ),
        displayMedium: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.bold,
          color: Color(AppConstants.textDark),
        ),
        titleLarge: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Color(AppConstants.textDark),
        ),
        bodyLarge: TextStyle(fontSize: 16, color: Color(AppConstants.textDark)),
        bodyMedium: TextStyle(fontSize: 14, color: Color(AppConstants.textLight)),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(AppConstants.primaryColor),
      ),
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 20,
      ),
    );
  }
}
