import 'package:flutter/material.dart';

/// Colors and spacing from the spec's "Visual system" section.
class AppColors {
  static const primary = Color(0xFF3C5CF1);
  static const ink = Color(0xFF18243A);
  static const success = Color(0xFF18A882);
  static const background = Color(0xFFF7F9FD);
  static const border = Color(0xFFE1E6F0);

  /// Softer text for descriptions. Dark enough for 4.5:1 contrast on white.
  static const muted = Color(0xFF5B6B85);

  /// Light blue used behind illustrations and input fields.
  static const tint = Color(0xFFEEF1FE);
  static const error = Color(0xFFB3261E);
}

/// The spec uses an 8 px spacing scale.
class AppSpacing {
  static const xs = 8.0;
  static const sm = 16.0;
  static const md = 24.0;
  static const lg = 32.0;
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    primary: AppColors.primary,
    onSurface: AppColors.ink,
    error: AppColors.error,
  );

  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    textTheme: Typography.material2021().black.apply(
      bodyColor: AppColors.ink,
      displayColor: AppColors.ink,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.background,
      labelStyle: const TextStyle(color: AppColors.muted),
      border: border(AppColors.border),
      enabledBorder: border(AppColors.border),
      focusedBorder: border(AppColors.primary, 2),
      errorBorder: border(AppColors.error),
      focusedErrorBorder: border(AppColors.error, 2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        minimumSize: const Size(44, 44),
        foregroundColor: AppColors.primary,
      ),
    ),
  );
}
