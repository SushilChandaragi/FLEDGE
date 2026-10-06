import 'package:flutter/material.dart';

/// CNEST design tokens. Mostly white / off-white surfaces with restrained blue accents.
class AppColors {
  static const primary = Color(0xFF2563EB);
  static const primaryDark = Color(0xFF1E3A8A);
  static const text = Color(0xFF0F172A);
  static const textSecondary = Color(0xFF64748B);
  static const tint = Color(0xFFEFF6FF);
  static const background = Color(0xFFF8FAFC);
  static const surface = Color(0xFFFFFFFF);
  static const border = Color(0xFFE2E8F0);
  static const success = Color(0xFF16A34A);
  static const successTint = Color(0xFFF0FDF4);
  static const warning = Color(0xFFD97706);
  static const warningTint = Color(0xFFFFFBEB);
  static const error = Color(0xFFDC2626);
  static const errorTint = Color(0xFFFEF2F2);
}

class AppText {
  static const _f = 'Inter';
  static const title = TextStyle(fontFamily: _f, fontSize: 26, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.2);
  static const section = TextStyle(fontFamily: _f, fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.3);
  static const body = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w400, color: AppColors.text, height: 1.4);
  static const bodyMedium = TextStyle(fontFamily: _f, fontSize: 15, fontWeight: FontWeight.w500, color: AppColors.text, height: 1.4);
  static const meta = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w400, color: AppColors.textSecondary, height: 1.4);
  static const metaMedium = TextStyle(fontFamily: _f, fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.textSecondary, height: 1.4);
  static const figure = TextStyle(fontFamily: _f, fontSize: 28, fontWeight: FontWeight.w600, color: AppColors.text, height: 1.1);
  static const srn = TextStyle(fontFamily: _f, fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.text, letterSpacing: 0.4);
}

class AppTheme {
  static const double radius = 10;

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    ).copyWith(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      error: AppColors.error,
      outline: AppColors.border,
    );

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const minSize = Size.fromHeight(52);

    OutlineInputBorder inputBorder(Color c, [double w = 1]) => OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      fontFamily: 'Inter',
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: AppText.section,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: minSize,
          shape: shape,
          side: const BorderSide(color: AppColors.border),
          foregroundColor: AppColors.text,
          backgroundColor: AppColors.surface,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 15, fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(fontFamily: 'Inter', fontSize: 14, fontWeight: FontWeight.w500),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        labelStyle: AppText.meta,
        hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 15),
        border: inputBorder(AppColors.border),
        enabledBorder: inputBorder(AppColors.border),
        focusedBorder: inputBorder(AppColors.primary, 1.5),
        errorBorder: inputBorder(AppColors.error),
        focusedErrorBorder: inputBorder(AppColors.error, 1.5),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.text,
        contentTextStyle: AppText.body.copyWith(color: Colors.white, fontSize: 14),
        shape: shape,
      ),
    );
  }
}
