import 'package:flutter/material.dart';

/// 宠安设计系统。
/// 所有页面统一引用此处的 token，禁止在页面内硬编码颜色/圆角/间距，
/// 以保证视觉一致性（此前各页面散落硬编码值是风格不统一的主因）。
class AppColors {
  const AppColors._();

  static const primary = Color(0xFFF5A623);
  static const primaryDark = Color(0xFFD98207);
  static const primarySoft = Color(0xFFFFF3E0);

  static const bg = Color(0xFFFFFBF5);
  static const card = Color(0xFFFFFFFF);

  static const text = Color(0xFF5C4B37);
  static const textSub = Color(0xFF9A8B7A);
  static const textFaint = Color(0xFFC1B5A5);
  static const divider = Color(0xFFF2EADD);

  // 状态色
  static const overdue = Color(0xFFE5484D);
  static const today = Color(0xFFF5A623);
  static const soon = Color(0xFF3E63DD);
  static const done = Color(0xFF30A46C);
}

class AppRadius {
  const AppRadius._();
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double pill = 999;
}

class AppSpace {
  const AppSpace._();
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 24;
}

class AppText {
  const AppText._();
  static const h1 = TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.25);
  static const h2 = TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);
  static const h3 = TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text);
  static const body = TextStyle(fontSize: 14, color: AppColors.text, height: 1.4);
  static const sub = TextStyle(fontSize: 13, color: AppColors.textSub);
  static const faint = TextStyle(fontSize: 12, color: AppColors.textFaint);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    surface: AppColors.card,
    onSurface: AppColors.text,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: AppColors.bg,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      titleTextStyle: AppText.h2,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      color: AppColors.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      iconColor: AppColors.textSub,
      textColor: AppColors.text,
    ),
    dividerTheme: const DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.text,
        minimumSize: const Size.fromHeight(48),
        side: const BorderSide(color: AppColors.divider),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: Colors.white,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textFaint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
  );
}
