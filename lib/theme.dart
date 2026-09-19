import 'package:flutter/material.dart';

/// 宠安设计系统 —— 主题令牌化。
///
/// 每个主题是一组完整颜色令牌（_Tokens）；AppColors / AppText 的静态成员
/// 始终指向「当前令牌集」，切换主题时整体替换，页面代码无需感知。
/// 页面禁止硬编码颜色，统一引用 AppColors / AppText，保证切换主题后全局一致。
class _Tokens {
  final Color primary; // 主色（按钮、选中态）
  final Color primaryDark; // 主色深（强调文字/图标）
  final Color primarySoft; // 主色浅底（头像底、头部区块）
  final Color bg; // 页面背景
  final Color card; // 卡片背景
  final Color border; // 卡片描边（区分色块边界，提升对比度）
  final Color shadow; // 卡片投影
  final Color text; // 主文字
  final Color textSub; // 次要文字
  final Color textFaint; // 弱化文字
  final Color divider; // 分割线
  final Color overdue; // 逾期/危险
  final Color today; // 今日/警示
  final Color soon; // 即将到期
  final Color done; // 完成/健康

  const _Tokens({
    required this.primary,
    required this.primaryDark,
    required this.primarySoft,
    required this.bg,
    required this.card,
    required this.border,
    required this.shadow,
    required this.text,
    required this.textSub,
    required this.textFaint,
    required this.divider,
    required this.overdue,
    required this.today,
    required this.soon,
    required this.done,
  });
}

/// 主题定义
class AppThemeDef {
  final String id;
  final String name;
  final String emoji; // 主题选择器里的小图标
  final _Tokens tokens;
  const AppThemeDef(this.id, this.name, this.emoji, this.tokens);
}

/// 全部内置主题（≥5 个）
const kAppThemes = [
  AppThemeDef('light', '暖橙（默认）', '🐱', _Tokens(
    primary: Color(0xFFF5A623),
    primaryDark: Color(0xFFD98207),
    primarySoft: Color(0xFFFFF3E0),
    bg: Color(0xFFFFFBF5),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF0E2CC),
    shadow: Color(0x1A5C4B37),
    text: Color(0xFF5C4B37),
    textSub: Color(0xFF9A8B7A),
    textFaint: Color(0xFFC1B5A5),
    divider: Color(0xFFF2EADD),
    overdue: Color(0xFFE5484D),
    today: Color(0xFFF5A623),
    soon: Color(0xFF3E63DD),
    done: Color(0xFF30A46C),
  )),
  AppThemeDef('dark', '暗黑', '🌙', _Tokens(
    primary: Color(0xFFF5A623),
    primaryDark: Color(0xFFFFC14D),
    primarySoft: Color(0xFF2E2718),
    bg: Color(0xFF14161A),
    card: Color(0xFF1F2228),
    border: Color(0xFF31353D),
    shadow: Color(0x66000000),
    text: Color(0xFFE8E3DA),
    textSub: Color(0xFFA8A29A),
    textFaint: Color(0xFF6E6A63),
    divider: Color(0xFF2E323A),
    overdue: Color(0xFFFF6B6E),
    today: Color(0xFFF5A623),
    soon: Color(0xFF6E96F5),
    done: Color(0xFF3DD68C),
  )),
  AppThemeDef('macaron', '马卡龙', '🍬', _Tokens(
    primary: Color(0xFFE86FB1),
    primaryDark: Color(0xFFC2448A),
    primarySoft: Color(0xFFFDE7F2),
    bg: Color(0xFFFFF7FB),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF6D9E8),
    shadow: Color(0x1AC2448A),
    text: Color(0xFF6B4A5B),
    textSub: Color(0xFF9E8293),
    textFaint: Color(0xFFC9B3C1),
    divider: Color(0xFFF5E3ED),
    overdue: Color(0xFFE5484D),
    today: Color(0xFFE86FB1),
    soon: Color(0xFF7C6FE8),
    done: Color(0xFF5FBF94),
  )),
  AppThemeDef('piggy', '猪猪侠红', '🐷', _Tokens(
    primary: Color(0xFFD93840),
    primaryDark: Color(0xFFB02830),
    primarySoft: Color(0xFFFCE4E4),
    bg: Color(0xFFFFF9F8),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFF3D4D4),
    shadow: Color(0x1AB02830),
    text: Color(0xFF5C3A38),
    textSub: Color(0xFF9A7A78),
    textFaint: Color(0xFFC6A9A7),
    divider: Color(0xFFF5E1DF),
    overdue: Color(0xFFE5484D),
    today: Color(0xFFE8983D),
    soon: Color(0xFF3E63DD),
    done: Color(0xFF30A46C),
  )),
  AppThemeDef('mint', '薄荷绿', '🌿', _Tokens(
    primary: Color(0xFF2FB380),
    primaryDark: Color(0xFF1F8A62),
    primarySoft: Color(0xFFDFF5EB),
    bg: Color(0xFFF4FBF7),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFD3EAE0),
    shadow: Color(0x1A1F8A62),
    text: Color(0xFF375148),
    textSub: Color(0xFF7C9188),
    textFaint: Color(0xFFAEC2B9),
    divider: Color(0xFFE0EEE7),
    overdue: Color(0xFFE5484D),
    today: Color(0xFFE5A13D),
    soon: Color(0xFF3E63DD),
    done: Color(0xFF30A46C),
  )),
  AppThemeDef('ocean', '海洋蓝', '🐳', _Tokens(
    primary: Color(0xFF2F7FD4),
    primaryDark: Color(0xFF1F5FA8),
    primarySoft: Color(0xFFE1EFFB),
    bg: Color(0xFFF3F8FD),
    card: Color(0xFFFFFFFF),
    border: Color(0xFFD2E4F4),
    shadow: Color(0x1A1F5FA8),
    text: Color(0xFF35485C),
    textSub: Color(0xFF7A8CA0),
    textFaint: Color(0xFFAEC0D2),
    divider: Color(0xFFDEEAF5),
    overdue: Color(0xFFE5484D),
    today: Color(0xFFE5A13D),
    soon: Color(0xFF2F7FD4),
    done: Color(0xFF30A46C),
  )),
];

class AppColors {
  const AppColors._();

  static _Tokens _t = kAppThemes.first.tokens;

  static void _apply(_Tokens t) => _t = t;

  static Color get primary => _t.primary;
  static Color get primaryDark => _t.primaryDark;
  static Color get primarySoft => _t.primarySoft;
  static Color get bg => _t.bg;
  static Color get card => _t.card;
  static Color get border => _t.border;
  static Color get shadow => _t.shadow;
  static Color get text => _t.text;
  static Color get textSub => _t.textSub;
  static Color get textFaint => _t.textFaint;
  static Color get divider => _t.divider;
  static Color get overdue => _t.overdue;
  static Color get today => _t.today;
  static Color get soon => _t.soon;
  static Color get done => _t.done;
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

/// 当前主题 id 的全局通知器（MaterialApp 监听它整体重建）
final ValueNotifier<String> appThemeId = ValueNotifier<String>('light');

/// 切换主题：更新令牌 + 通知监听方。返回是否为合法 id。
bool setAppTheme(String id) {
  for (final def in kAppThemes) {
    if (def.id == id) {
      AppColors._apply(def.tokens);
      appThemeId.value = id;
      return true;
    }
  }
  return false;
}

AppThemeDef themeById(String id) =>
    kAppThemes.firstWhere((def) => def.id == id, orElse: () => kAppThemes.first);

/// 深色主题判断（用于个别需要跟随明暗的逻辑，如状态栏）
bool get isDarkTheme => themeById(appThemeId.value).id == 'dark';

class AppText {
  const AppText._();

  static TextStyle get h1 => TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.text, height: 1.25);
  static TextStyle get h2 => TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text);
  static TextStyle get h3 => TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.text);
  static TextStyle get body => TextStyle(fontSize: 14, color: AppColors.text, height: 1.4);
  static TextStyle get sub => TextStyle(fontSize: 13, color: AppColors.textSub);
  static TextStyle get faint => TextStyle(fontSize: 12, color: AppColors.textFaint);
}

ThemeData buildAppTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: isDarkTheme ? Brightness.dark : Brightness.light,
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
    appBarTheme: AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: AppColors.bg,
      foregroundColor: AppColors.text,
      titleTextStyle: AppText.h2,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.card,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(AppRadius.lg)),
        side: BorderSide(color: AppColors.border),
      ),
    ),
    listTileTheme: ListTileThemeData(
      iconColor: AppColors.textSub,
      textColor: AppColors.text,
    ),
    dividerTheme: DividerThemeData(color: AppColors.divider, thickness: 1, space: 1),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(AppRadius.sm),
        borderSide: BorderSide(color: AppColors.primary, width: 1.6),
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
        side: BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: AppColors.textFaint,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.sm)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: AppColors.card,
      titleTextStyle: AppText.h2,
      contentTextStyle: AppText.body,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: AppColors.card,
      modalBackgroundColor: AppColors.card,
    ),
  );
}
