// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'locale_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$appLocaleHash() => r'59d8136d390b93b66160445edff3e3dc34196ff7';

/// 应用语言 Provider
///
/// 管理全局的语言/地区设置状态。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：Locale（语言代码）
/// 默认值：Locale('zh')（简体中文）
///
/// 使用场景：
/// - 设置页面提供语言切换选项
/// - MaterialApp.locale 绑定此 Provider
/// - AppLocalizations.of(context) 根据此 Locale 加载对应翻译
///
/// 支持的语言：
/// - 'zh': 简体中文（默认）
/// - 'en': 英文
///
/// 使用示例：
/// ```dart
/// // 切换语言
/// ref.read(appLocaleProvider.notifier).setLocale(Locale('en'));
/// // 监听语言
/// final locale = ref.watch(appLocaleProvider);
/// ```
///
/// Copied from [AppLocale].
@ProviderFor(AppLocale)
final appLocaleProvider =
    AutoDisposeNotifierProvider<AppLocale, Locale>.internal(
  AppLocale.new,
  name: r'appLocaleProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$appLocaleHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

typedef _$AppLocale = AutoDisposeNotifier<Locale>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
