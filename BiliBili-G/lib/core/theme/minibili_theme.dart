import 'package:flutter/material.dart';

/// MiniBili 风格主题配色
///
/// 参考 MiniBili 简约设计语言：
/// - 主色 biliBlue (#0DA2E7)：干净通透的蓝
/// - 背景 biliBackground (#F5FBFF)：极浅蓝白
/// - 顶部 hero biliHero (#A7D8F0)：淡蓝渐变
/// - 卡片：半透明白 + 圆角 + 细边框
abstract final class MiniBiliColors {
  /// 主品牌蓝 #0DA2E7
  static const Color biliBlue = Color(0xFF0DA2E7);

  /// 页面背景 #F5FBFF
  static const Color biliBackground = Color(0xFFF5FBFF);

  /// 顶部 hero 背景 #A7D8F0
  static const Color biliHero = Color(0xFFA7D8F0);

  /// 卡片表面 — 纯白
  static const Color biliCard = Color(0xFFFFFFFF);

  /// 卡片边框 #E6E8EB
  static const Color biliBorder = Color(0xFFE6E8EB);

  /// 主文字 #0F172A
  static const Color biliText = Color(0xFF0F172A);

  /// 次要文字 #65758B
  static const Color biliSubtext = Color(0xFF65758B);

  /// 未选中标签文字 #475569
  static const Color biliTabText = Color(0xFF475569);

  /// 静音图标 #94A3B8
  static const Color biliMuted = Color(0xFF94A3B8);

  /// 静音表面 / 占位 #F1F5F9
  static const Color biliMutedSurface = Color(0xFFF1F5F9);
}

/// MiniBili 风格主题
///
/// 干净、通透、干脆的设计语言：
/// - Material 3 + 自定义 colorScheme
/// - 主色 biliBlue，背景 biliBackground
/// - 卡片圆角 16，细边框
/// - 全局去除 Material 水波纹，按钮/输入框/标签栏统一 MiniBili 风格
/// - 覆盖 FAB/SnackBar/Dialog/Chip/ListTile/PopupMenu 主题
abstract final class MiniBiliTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MiniBiliColors.biliBlue,
      brightness: Brightness.light,
      primary: MiniBiliColors.biliBlue,
      surface: MiniBiliColors.biliCard,
    );

    return ThemeData(
      useMaterial3: true,
      // 去除 Material 水波纹效果，更接近 iOS 风格
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: colorScheme.copyWith(
        primary: MiniBiliColors.biliBlue,
        onPrimary: Colors.white,
        surface: MiniBiliColors.biliCard,
        onSurface: MiniBiliColors.biliText,
        secondary: MiniBiliColors.biliSubtext,
      ),
      scaffoldBackgroundColor: MiniBiliColors.biliBackground,
      primaryColor: MiniBiliColors.biliBlue,
      appBarTheme: const AppBarTheme(
        backgroundColor: MiniBiliColors.biliBackground,
        foregroundColor: MiniBiliColors.biliText,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: MiniBiliColors.biliCard.withOpacity(0.92),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: MiniBiliColors.biliBorder,
            width: 0.5,
          ),
        ),
      ),
      // 按钮主题 — MiniBili 风格：蓝色填充、圆角、无阴影
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiniBiliColors.biliBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiniBiliColors.biliBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiniBiliColors.biliBlue,
          side: BorderSide(color: MiniBiliColors.biliBlue, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MiniBiliColors.biliBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // 输入框主题 — MiniBili 风格
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MiniBiliColors.biliMutedSurface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: MiniBiliColors.biliBlue, width: 1.5),
        ),
        hintStyle: TextStyle(color: MiniBiliColors.biliMuted),
      ),
      // TabBar 主题 — MiniBili 胶囊风格，全局生效
      tabBarTheme: TabBarThemeData(
        labelColor: MiniBiliColors.biliBlue,
        unselectedLabelColor: MiniBiliColors.biliTabText,
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        indicator: BoxDecoration(
          color: MiniBiliColors.biliCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MiniBiliColors.biliBorder,
            width: 0.5,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: Colors.white.withOpacity(0.85),
        selectedItemColor: MiniBiliColors.biliBlue,
        unselectedItemColor: MiniBiliColors.biliMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
        unselectedLabelStyle: const TextStyle(fontSize: 11),
      ),
      dividerTheme: const DividerThemeData(
        color: MiniBiliColors.biliBorder,
        thickness: 0.5,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: MiniBiliColors.biliCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: MiniBiliColors.biliCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: MiniBiliColors.biliBlue,
        linearTrackColor: MiniBiliColors.biliMutedSurface,
        circularTrackColor: MiniBiliColors.biliMutedSurface,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MiniBiliColors.biliBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MiniBiliColors.biliText,
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: MiniBiliColors.biliCard,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: MiniBiliColors.biliMutedSurface,
        selectedColor: MiniBiliColors.biliBlue.withOpacity(0.12),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: MiniBiliColors.biliText,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          color: MiniBiliColors.biliBlue,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: MiniBiliColors.biliSubtext,
        textColor: MiniBiliColors.biliText,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: MiniBiliColors.biliCard,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: MiniBiliColors.biliText,
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: MiniBiliColors.biliText,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          color: MiniBiliColors.biliText,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          color: MiniBiliColors.biliSubtext,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: MiniBiliColors.biliBlue,
      brightness: Brightness.dark,
      primary: MiniBiliColors.biliBlue,
    );

    return ThemeData(
      useMaterial3: true,
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      colorScheme: colorScheme.copyWith(
        primary: MiniBiliColors.biliBlue,
        onPrimary: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF0F172A),
      primaryColor: MiniBiliColors.biliBlue,
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0F172A),
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
      ),
      cardTheme: CardThemeData(
        color: const Color(0xFF1E293B).withOpacity(0.92),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MiniBiliColors.biliBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MiniBiliColors.biliBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: MiniBiliColors.biliBlue,
          side: BorderSide(color: MiniBiliColors.biliBlue, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MiniBiliColors.biliBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E293B),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              BorderSide(color: MiniBiliColors.biliBlue, width: 1.5),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: MiniBiliColors.biliBlue,
        unselectedLabelColor: Colors.white.withOpacity(0.6),
        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        indicator: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: Colors.white.withOpacity(0.08),
            width: 0.5,
          ),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        dividerColor: Colors.transparent,
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: const Color(0xFF1E293B).withOpacity(0.85),
        selectedItemColor: MiniBiliColors.biliBlue,
        unselectedItemColor: MiniBiliColors.biliMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      drawerTheme: DrawerThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: MiniBiliColors.biliBlue,
        linearTrackColor: Colors.white.withOpacity(0.1),
        circularTrackColor: Colors.white.withOpacity(0.1),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: MiniBiliColors.biliBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: const Color(0xFF1E293B),
        contentTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFF334155),
        selectedColor: MiniBiliColors.biliBlue.withOpacity(0.2),
        labelStyle: const TextStyle(
          fontSize: 13,
          color: Colors.white,
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 13,
          color: MiniBiliColors.biliBlue,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        iconColor: MiniBiliColors.biliMuted,
        textColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: const Color(0xFF1E293B),
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
