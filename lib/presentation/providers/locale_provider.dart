import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'locale_provider.g.dart';

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
@riverpod
class AppLocale extends _$AppLocale {
  /// 初始状态：简体中文
  @override
  Locale build() {
    return const Locale('zh');
  }

  /// 设置应用语言
  ///
  /// 参数：[locale] - 语言地区代码，如 Locale('zh')、Locale('en')
  void setLocale(Locale locale) {
    state = locale;
  }
}
