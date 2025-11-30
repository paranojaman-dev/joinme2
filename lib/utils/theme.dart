import 'package:flutter/material.dart';
import 'constants.dart';

class AppTheme {
  static final ThemeData darkTheme = ThemeData(
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundColor,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.surfaceColor,
      foregroundColor: AppColors.textColor,
      elevation: 0,
    ),
    textTheme: TextTheme(
      displayLarge: TextStyle(
        color: AppColors.textColor,
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
      bodyLarge: TextStyle(
        color: AppColors.textColor,
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: AppColors.textColor,
        fontSize: 14,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    // USUŃ cardTheme całkowicie - nie jest potrzebny
  );
}