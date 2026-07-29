import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';

/// 应用主题配置（Neumorphism 水墨风）
///
/// 基于 [NeumorphicTokens] 构建亮/暗主题方案。
///
/// 设计特点：
/// - 表面色与背景同色，靠双向阴影定义体积（Neumorphism 核心）
/// - 强调色采用水墨黑系（inkPrimary）
/// - 保留跨平台中文字体回退链
/// - 圆角统一为令牌定义的档位
///
/// 字体配置：
/// - Windows：Microsoft YaHei（微软雅黑）
/// - macOS / iOS：PingFang SC（苹方-简）
/// - Android：Noto Sans CJK SC（思源黑体）
/// - Linux：Noto Sans CJK SC
///
/// 使用示例：
/// ```dart
/// MaterialApp(
///   theme: AppTheme.lightTheme,
///   darkTheme: AppTheme.darkTheme,
///   themeMode: ThemeMode.system,
/// )
/// ```
class AppTheme {
  AppTheme._();

  /// Windows 平台默认中文字体
  static const String _windowsFont = 'Microsoft YaHei';

  /// macOS / iOS 平台默认中文字体
  static const String _appleFont = 'PingFang SC';

  /// Android 平台默认中文字体
  static const String _androidFont = 'Noto Sans CJK SC';

  /// Linux 平台默认中文字体
  static const String _linuxFont = 'Noto Sans CJK SC';

  /// 根据运行平台返回最合适的中文字体
  static String get _platformFont {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return _windowsFont;
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return _appleFont;
      case TargetPlatform.android:
        return _androidFont;
      case TargetPlatform.linux:
        return _linuxFont;
      case TargetPlatform.fuchsia:
        return _appleFont;
    }
  }

  /// 构建字体回退列表
  static List<String> get _fontFallbacks {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return [_windowsFont, _appleFont, _linuxFont];
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return [_appleFont, _windowsFont, _androidFont];
      case TargetPlatform.android:
        return [_androidFont, _appleFont, _windowsFont];
      case TargetPlatform.linux:
        return [_linuxFont, _appleFont, _windowsFont];
      case TargetPlatform.fuchsia:
        return [_appleFont, _windowsFont];
    }
  }

  /// 创建包含所有字体的 TextStyle
  static TextStyle _fontStyle() => TextStyle(
        fontFamily: _fontFallbacks.first,
        fontFamilyFallback: _fontFallbacks.skip(1).toList(),
      );

  /// 构建 ColorScheme（基于 NeumorphicTokens）
  static ColorScheme _colorScheme(NeumorphicTokens tokens) {
    return ColorScheme(
      brightness: tokens.brightness,
      primary: tokens.inkPrimary,
      onPrimary: tokens.brightness == Brightness.dark
          ? tokens.surface
          : const Color(0xFFF5F5F5),
      secondary: tokens.inkSecondary,
      onSecondary: tokens.brightness == Brightness.dark
          ? tokens.surface
          : const Color(0xFFF5F5F5),
      error: tokens.error,
      onError: tokens.brightness == Brightness.dark
          ? tokens.surface
          : const Color(0xFFF5F5F5),
      surface: tokens.surface,
      onSurface: tokens.textPrimary,
      // Material 3 新增的分量表面色
      surfaceContainerHighest: tokens.surfaceAlt,
      onSurfaceVariant: tokens.textSecondary,
      outline: tokens.textHint,
      outlineVariant: tokens.surfaceAlt,
      shadow: tokens.darkShadow,
      scrim: tokens.inkPrimary,
    );
  }

  /// 亮色主题
  static ThemeData get lightTheme => _buildTheme(NeumorphicTokens.light);

  /// 暗色主题
  static ThemeData get darkTheme => _buildTheme(NeumorphicTokens.dark);

  static ThemeData _buildTheme(NeumorphicTokens tokens) {
    final fontStyle = _fontStyle();
    final colorScheme = _colorScheme(tokens);

    return ThemeData(
      useMaterial3: true,
      brightness: tokens.brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: tokens.surface,
      canvasColor: tokens.surface,
      fontFamily: _platformFont,
      fontFamilyFallback: _fontFallbacks.skip(1).toList(),
      textTheme: _buildTextTheme(fontStyle, tokens),
      appBarTheme: AppBarTheme(
        backgroundColor: tokens.surface,
        foregroundColor: tokens.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: fontStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
      ),
      cardTheme: CardThemeData(
        color: tokens.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusLarge),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: tokens.surfaceAlt,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: tokens.surfaceAlt,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: fontStyle.copyWith(color: tokens.textHint),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: tokens.inkPrimary,
        contentTextStyle: fontStyle.copyWith(
          color: tokens.brightness == Brightness.dark
              ? tokens.surface
              : const Color(0xFFF5F5F5),
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(tokens.radiusXLarge),
          ),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: tokens.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        titleTextStyle: fontStyle.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: tokens.textPrimary,
        ),
        contentTextStyle: fontStyle.copyWith(
          fontSize: 14,
          color: tokens.textSecondary,
        ),
      ),
      // 按钮保留字体配置，实际渲染由 NeumorphicButton 接管
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _buttonStyle(fontStyle, tokens)),
      filledButtonTheme:
          FilledButtonThemeData(style: _buttonStyle(fontStyle, tokens)),
      textButtonTheme:
          TextButtonThemeData(style: _buttonStyle(fontStyle, tokens)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: _buttonStyle(fontStyle, tokens)),
      iconButtonTheme:
          IconButtonThemeData(style: _buttonStyle(fontStyle, tokens)),
    );
  }

  /// 构建文字主题
  static TextTheme _buildTextTheme(TextStyle base, NeumorphicTokens tokens) {
    return TextTheme(
      // Display
      displayLarge: base.copyWith(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.1,
        color: tokens.textPrimary,
      ),
      displayMedium: base.copyWith(
        fontSize: 36,
        fontWeight: FontWeight.w700,
        height: 1.15,
        color: tokens.textPrimary,
      ),
      displaySmall: base.copyWith(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: tokens.textPrimary,
      ),
      // Headline
      headlineLarge: base.copyWith(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.25,
        color: tokens.textPrimary,
      ),
      headlineMedium: base.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        height: 1.3,
        color: tokens.textPrimary,
      ),
      headlineSmall: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: tokens.textPrimary,
      ),
      // Title
      titleLarge: base.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.35,
        color: tokens.textPrimary,
      ),
      titleMedium: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: tokens.textPrimary,
      ),
      titleSmall: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: tokens.textPrimary,
      ),
      // Body
      bodyLarge: base.copyWith(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.6,
        color: tokens.textPrimary,
      ),
      bodyMedium: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
        color: tokens.textPrimary,
      ),
      bodySmall: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
        color: tokens.textSecondary,
      ),
      // Label
      labelLarge: base.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: tokens.textPrimary,
      ),
      labelMedium: base.copyWith(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: tokens.textSecondary,
      ),
      labelSmall: base.copyWith(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.4,
        color: tokens.textHint,
      ),
    );
  }

  /// 构建统一的按钮样式
  ///
  /// NeumorphicButton 接管主要按钮渲染，这里仅保留字体配置，
  /// 确保未迁移的 Material 按钮仍能正常显示中文字体。
  static ButtonStyle _buttonStyle(TextStyle style, NeumorphicTokens tokens) {
    return ButtonStyle(
      textStyle: WidgetStatePropertyAll(style),
      foregroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return tokens.textHint;
        }
        return tokens.textPrimary;
      }),
      backgroundColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMedium),
        ),
      ),
    );
  }
}
