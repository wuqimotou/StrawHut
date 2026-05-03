import 'package:flutter/material.dart';

/// 应用主题配置
///
/// 定义 StrawHut 的亮色和暗色主题方案。
///
/// 设计特点：
/// - 使用 Material 3 设计规范（useMaterial3: true）
/// - 主色调为绿色（seedColor: Colors.green），呼应稻草人/农业主题
/// - 支持系统级亮色/暗色主题自动切换
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

  /// 亮色主题
  ///
  /// 基于 Material 3 的亮色配色方案。
  /// seedColor: Colors.green 生成一套绿色调的组件颜色。
  static ThemeData get lightTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      );

  /// 暗色主题
  ///
  /// 基于 Material 3 的暗色配色方案。
  /// 在暗色背景下仍使用绿色作为主色调，保持一致的品牌视觉。
  static ThemeData get darkTheme => ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark,
        ),
      );
}
