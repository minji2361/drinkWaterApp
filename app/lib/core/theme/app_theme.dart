import 'package:flutter/material.dart';

/// UI 시안(docs/design/UI_시안.pdf) 기준 색상.
class AppColors {
  const AppColors._();

  static const primary = Color(0xFF2E7D87);
  static const background = Color(0xFFEEF3F2);
  static const surface = Color(0xFFF9FBFA);
  static const surfaceTint = Color(0xFFE3ECEA);
  static const textPrimary = Color(0xFF263A3F);
  static const textSecondary = Color(0xFF5F7378);
  static const noticeBackground = Color(0xFFFFF0C8);
  static const noticeText = Color(0xFF6B4E00);
  static const error = Color(0xFFB3402F);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    surface: AppColors.surface,
    error: AppColors.error,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.background,
    textTheme: Typography.blackMountainView.apply(
      bodyColor: AppColors.textPrimary,
      displayColor: AppColors.textPrimary,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(64),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    ),
  );
}
