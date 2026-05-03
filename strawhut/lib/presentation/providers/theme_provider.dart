import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'theme_provider.g.dart';

/// 应用主题模式 Provider
///
/// 管理全局的亮色/暗色主题切换状态。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：ThemeMode（system、light、dark）
/// 默认值：ThemeMode.system（跟随系统）
///
/// 使用场景：
/// - 设置页面提供主题切换选项
/// - MaterialApp.themeMode 绑定此 Provider
///
/// 使用示例：
/// ```dart
/// // 切换主题
/// ref.read(appThemeModeProvider.notifier).setThemeMode(ThemeMode.dark);
/// // 监听主题
/// final themeMode = ref.watch(appThemeModeProvider);
/// ```
@riverpod
class AppThemeMode extends _$AppThemeMode {
  /// 初始状态：跟随系统主题
  @override
  ThemeMode build() {
    return ThemeMode.system;
  }

  /// 设置主题模式
  ///
  /// 参数：[mode] - ThemeMode.system（跟随系统）、ThemeMode.light（亮色）、ThemeMode.dark（暗色）
  void setThemeMode(ThemeMode mode) {
    state = mode;
  }
}
