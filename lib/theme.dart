import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF07060F);
  static const surface = Color(0xFF14112A);
  static const cyan = Color(0xFF22D3EE);
  static const violet = Color(0xFF7C3AED);
  static const pink = Color(0xFFEC4899);
  static const green = Color(0xFF10B981);
  static const amber = Color(0xFFF59E0B);
  static const red = Color(0xFFEF4444);

  static const brandGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [cyan, violet, pink],
  );
}

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.violet,
    brightness: Brightness.dark,
  ).copyWith(surface: AppColors.surface, primary: const Color(0xFFA78BFA));

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}
