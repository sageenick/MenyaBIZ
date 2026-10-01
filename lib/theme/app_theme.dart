import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryGreen = Color(0xFF3B6D11);
  static const Color accentBlue = Color(0xFF185FA5);
  static const Color warningRed = Color(0xFFA32D2D);
  static const Color backgroundGray = Color(0xFFF2F2F0);

  static ThemeData lightTheme = ThemeData(
    scaffoldBackgroundColor: backgroundGray,
    primaryColor: primaryGreen,
    colorScheme: ColorScheme.light(
      primary: primaryGreen,
      secondary: accentBlue,
      error: warningRed,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: accentBlue,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: primaryGreen,
      unselectedItemColor: Colors.grey,
      backgroundColor: Colors.white,
    ),
  );
}