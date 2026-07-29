/// locale_provider 单元测试文件
///
/// 本文件测试 locale_provider.dart 中的 AppLocale Riverpod Notifier，
/// 验证应用语言/地区设置状态管理行为。
///
/// 测试范围：
/// - build(): 初始状态为 Locale('zh')
/// - setLocale(): 更新语言设置状态
///
/// 使用 riverpod 的 ContainerProviderTester 进行隔离测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/presentation/providers/locale_provider.dart';

void main() {
  group('AppLocale 初始状态', () {
    test('build() 应该返回 Locale("zh") 作为初始状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appLocaleProvider);

      expect(state, equals(const Locale('zh')));
      expect(state.languageCode, equals('zh'));
    });

    test('初始状态的 countryCode 应该为 null', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appLocaleProvider);

      expect(state.countryCode, isNull);
    });
  });

  group('AppLocale.setLocale', () {
    test('应该能够设置为英文 Locale("en")', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));

      final state = container.read(appLocaleProvider);
      expect(state, equals(const Locale('en')));
      expect(state.languageCode, equals('en'));
    });

    test('应该能够设置回中文 Locale("zh")', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先切换为英文
      container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(appLocaleProvider).languageCode, equals('en'));

      // 再切换回中文
      container.read(appLocaleProvider.notifier).setLocale(const Locale('zh'));
      expect(container.read(appLocaleProvider).languageCode, equals('zh'));
    });

    test('应该能够设置带国家代码的 Locale', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(appLocaleProvider.notifier)
          .setLocale(const Locale('en', 'US'));

      final state = container.read(appLocaleProvider);
      expect(state.languageCode, equals('en'));
      expect(state.countryCode, equals('US'));
    });

    test('多次设置应该覆盖之前的语言设置', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
      container.read(appLocaleProvider.notifier).setLocale(const Locale('zh'));
      container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));

      expect(container.read(appLocaleProvider).languageCode, equals('en'));
    });

    test('设置为相同值不应该导致错误', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(appLocaleProvider.notifier).setLocale(const Locale('zh'));
      container.read(appLocaleProvider.notifier).setLocale(const Locale('zh'));

      expect(container.read(appLocaleProvider), equals(const Locale('zh')));
    });
  });

  group('AppLocale 完整切换周期', () {
    test('完整的语言切换流程：zh -> en -> zh', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初始状态
      expect(container.read(appLocaleProvider), equals(const Locale('zh')));

      // 切换到英文
      container.read(appLocaleProvider.notifier).setLocale(const Locale('en'));
      expect(container.read(appLocaleProvider), equals(const Locale('en')));

      // 切换回中文
      container.read(appLocaleProvider.notifier).setLocale(const Locale('zh'));
      expect(container.read(appLocaleProvider), equals(const Locale('zh')));
    });

    test('应该支持常见的语言代码', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLocales = [
        Locale('zh'), // 中文
        Locale('en'), // 英文
        Locale('ja'), // 日文
        Locale('ko'), // 韩文
        Locale('fr'), // 法文
        Locale('de'), // 德文
        Locale('es'), // 西班牙文
      ];

      for (final locale in testLocales) {
        container.read(appLocaleProvider.notifier).setLocale(locale);
        expect(container.read(appLocaleProvider).languageCode, equals(locale.languageCode));
      }
    });

    test('应该支持带国家代码的语言设置', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testLocales = [
        Locale('en', 'US'), // 美式英语
        Locale('en', 'GB'), // 英式英语
        Locale('zh', 'CN'), // 简体中文
        Locale('zh', 'TW'), // 繁体中文
      ];

      for (final locale in testLocales) {
        container.read(appLocaleProvider.notifier).setLocale(locale);
        final state = container.read(appLocaleProvider);
        expect(state.languageCode, equals(locale.languageCode));
        expect(state.countryCode, equals(locale.countryCode));
      }
    });
  });
}
