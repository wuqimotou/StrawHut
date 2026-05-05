import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// 应用主题配置
///
/// 定义 StrawHut 的亮色和暗色主题方案。
///
/// 设计特点：
/// - 使用 Material 3 设计规范（useMaterial3: true）
/// - 主色调为绿色（seedColor: Colors.green），呼应稻草人/农业主题
/// - 支持系统级亮色/暗色主题自动切换
/// - 配置跨平台中文字体支持，解决 Windows/Android/iOS 上中文显示异常问题
///
/// 字体配置：
/// - Windows：Microsoft YaHei（微软雅黑）→ 完美支持简体中文
/// - macOS / iOS：PingFang SC（苹方-简）→ 苹果系统中文字体
/// - Android：系统默认 Noto Sans CJK SC（思源黑体）→ Android 系统中文字体
/// - Linux：Noto Sans CJK SC → 开源中文字体
///
/// 配色方案：
/// - 亮色主题：适合日常使用，白色背景
/// - 暗色主题：适合夜间使用，深色背景，减少眼睛疲劳
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
  /// 私有构造函数，防止实例化
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
  ///
  /// Flutter 会按顺序尝试列表中的字体，直到找到可用的字体。
  /// 将当前平台字体放在第一位，确保优先使用平台原生中文字体。
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
  ///
  /// 将平台原生字体放在最前，其他平台字体作为回退。
  /// 这样如果某个平台缺少指定字体，会尝试下一个。
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
  ///
  /// 将字体列表作为 fontFamilyFallback，确保多平台兼容。
  static TextStyle _fontStyle() => TextStyle(
        fontFamily: _fontFallbacks.first,
        fontFamilyFallback: _fontFallbacks.skip(1).toList(),
      );

  /// 构建统一的按钮样式
  ///
  /// Material 3 按钮有独立的字体配置，需单独设置中文字体。
  static ButtonStyle _buttonStyle(TextStyle style) => ButtonStyle(
        textStyle: WidgetStatePropertyAll(style),
      );

  /// 亮色主题
  ///
  /// 基于 Material 3 的亮色配色方案。
  /// seedColor: Colors.green 生成一套绿色调的组件颜色。
  static ThemeData get lightTheme {
    final fontStyle = _fontStyle();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      fontFamily: _platformFont,
      fontFamilyFallback: _fontFallbacks.skip(1).toList(),
      textTheme: TextTheme(
        bodyLarge: fontStyle,
        bodyMedium: fontStyle,
        bodySmall: fontStyle,
        titleLarge: fontStyle,
        titleMedium: fontStyle,
        titleSmall: fontStyle,
        labelLarge: fontStyle,
        labelMedium: fontStyle,
        labelSmall: fontStyle,
        displayLarge: fontStyle,
        displayMedium: fontStyle,
        displaySmall: fontStyle,
        headlineLarge: fontStyle,
        headlineMedium: fontStyle,
        headlineSmall: fontStyle,
      ),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _buttonStyle(fontStyle)),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(fontStyle)),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle(fontStyle)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: _buttonStyle(fontStyle)),
      iconButtonTheme: IconButtonThemeData(style: _buttonStyle(fontStyle)),
    );
  }

  /// 暗色主题
  ///
  /// 基于 Material 3 的暗色配色方案。
  /// 在暗色背景下仍使用绿色作为主色调，保持一致的品牌视觉。
  static ThemeData get darkTheme {
    final fontStyle = _fontStyle();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
      ),
      fontFamily: _platformFont,
      fontFamilyFallback: _fontFallbacks.skip(1).toList(),
      textTheme: TextTheme(
        bodyLarge: fontStyle,
        bodyMedium: fontStyle,
        bodySmall: fontStyle,
        titleLarge: fontStyle,
        titleMedium: fontStyle,
        titleSmall: fontStyle,
        labelLarge: fontStyle,
        labelMedium: fontStyle,
        labelSmall: fontStyle,
        displayLarge: fontStyle,
        displayMedium: fontStyle,
        displaySmall: fontStyle,
        headlineLarge: fontStyle,
        headlineMedium: fontStyle,
        headlineSmall: fontStyle,
      ),
      elevatedButtonTheme:
          ElevatedButtonThemeData(style: _buttonStyle(fontStyle)),
      filledButtonTheme: FilledButtonThemeData(style: _buttonStyle(fontStyle)),
      textButtonTheme: TextButtonThemeData(style: _buttonStyle(fontStyle)),
      outlinedButtonTheme:
          OutlinedButtonThemeData(style: _buttonStyle(fontStyle)),
      iconButtonTheme: IconButtonThemeData(style: _buttonStyle(fontStyle)),
    );
  }
}
