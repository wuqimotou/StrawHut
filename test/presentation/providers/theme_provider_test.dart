/// theme_provider 单元测试文件
///
/// 本文件测试 theme_provider.dart 中的 AppThemeMode Riverpod Notifier，
/// 验证应用主题模式状态管理行为。
///
/// 测试范围：
/// - build(): 初始状态为 ThemeMode.system
/// - setThemeMode(): 更新主题模式状态
///
/// 使用 riverpod 的 ContainerProviderTester 进行隔离测试。

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/presentation/providers/theme_provider.dart';

void main() {
  group('AppThemeMode 初始状态', () {
    test('build() 应该返回 ThemeMode.system 作为初始状态', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appThemeModeProvider);

      expect(state, equals(ThemeMode.system));
    });

    test('初始状态既不是 light 也不是 dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final state = container.read(appThemeModeProvider);

      expect(state, isNot(equals(ThemeMode.light)));
      expect(state, isNot(equals(ThemeMode.dark)));
    });
  });

  group('AppThemeMode.setThemeMode', () {
    test('应该能够设置为 ThemeMode.light', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(appThemeModeProvider), equals(ThemeMode.light));
    });

    test('应该能够设置为 ThemeMode.dark', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));
    });

    test('应该能够设置为 ThemeMode.system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 先设置为 dark
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));

      // 再设置回 system
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);

      expect(container.read(appThemeModeProvider), equals(ThemeMode.system));
    });

    test('多次设置应该覆盖之前的主题模式', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);

      expect(container.read(appThemeModeProvider), equals(ThemeMode.light));
    });

    test('设置为相同值不应该导致错误', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);

      expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));
    });
  });

  group('AppThemeMode 完整切换周期', () {
    test('完整的主题切换流程：system -> dark -> light -> system', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // 初始状态
      expect(container.read(appThemeModeProvider), equals(ThemeMode.system));

      // 切换到 dark
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.dark);
      expect(container.read(appThemeModeProvider), equals(ThemeMode.dark));

      // 切换到 light
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.light);
      expect(container.read(appThemeModeProvider), equals(ThemeMode.light));

      // 切换回 system
      container
          .read(appThemeModeProvider.notifier)
          .setThemeMode(ThemeMode.system);
      expect(container.read(appThemeModeProvider), equals(ThemeMode.system));
    });

    test('ThemeMode.values 中的所有模式都应该可以被设置', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      for (final mode in ThemeMode.values) {
        container.read(appThemeModeProvider.notifier).setThemeMode(mode);
        expect(container.read(appThemeModeProvider), equals(mode));
      }
    });
  });
}
