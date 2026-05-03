// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appThemeModeHash() => r'4ac6c3738fb0d9e445d45e981d29eac78e524e5e';

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
///
/// Copied from [AppThemeMode].
@ProviderFor(AppThemeMode)
final appThemeModeProvider =
    AutoDisposeNotifierProvider<AppThemeMode, ThemeMode>.internal(
  AppThemeMode.new,
  name: r'appThemeModeProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appThemeModeHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppThemeMode = AutoDisposeNotifier<ThemeMode>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
