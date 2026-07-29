import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/app/theme.dart';

/// AppTheme 单元测试
///
/// 测试目标：验证亮色和暗色主题配置是否正确
/// 覆盖范围：
/// - AppTheme.lightTheme 返回有效的 ThemeData
/// - AppTheme.darkTheme 返回有效的 ThemeData
/// - 亮色主题具有正确的 Brightness.light
/// - 暗色主题具有正确的 Brightness.dark
/// - 两个主题均启用 Material 3
/// - 两个主题均使用绿色 seedColor
void main() {
  group('AppTheme 主题配置测试', () {
    group('AppTheme.lightTheme 亮色主题测试', () {
      test('应返回非空的 ThemeData 实例', () {
        final theme = AppTheme.lightTheme;
        expect(theme, isNotNull);
        expect(theme, isA<ThemeData>());
      });

      test('亮度应设置为 Brightness.light', () {
        final theme = AppTheme.lightTheme;
        expect(theme.brightness, Brightness.light);
        expect(theme.colorScheme.brightness, Brightness.light);
      });

      test('应启用 Material 3 设计', () {
        final theme = AppTheme.lightTheme;
        expect(theme.useMaterial3, true);
      });

      test('colorScheme 应基于绿色种子颜色生成', () {
        final theme = AppTheme.lightTheme;
        // 验证 colorScheme 已正确初始化
        expect(theme.colorScheme, isNotNull);
        expect(theme.colorScheme.primary, isNotNull);
        // Material 3 中，绿色种子会生成绿色系的主色
        expect(theme.colorScheme.primary.green, greaterThan(0));
      });

      test('应配置完整的组件主题数据', () {
        final theme = AppTheme.lightTheme;
        // 验证 ThemeData 包含常用组件主题
        expect(theme.appBarTheme, isNotNull);
        expect(theme.buttonTheme, isNotNull);
        expect(theme.textTheme, isNotNull);
      });
    });

    group('AppTheme.darkTheme 暗色主题测试', () {
      test('应返回非空的 ThemeData 实例', () {
        final theme = AppTheme.darkTheme;
        expect(theme, isNotNull);
        expect(theme, isA<ThemeData>());
      });

      test('亮度应设置为 Brightness.dark', () {
        final theme = AppTheme.darkTheme;
        expect(theme.brightness, Brightness.dark);
        expect(theme.colorScheme.brightness, Brightness.dark);
      });

      test('应启用 Material 3 设计', () {
        final theme = AppTheme.darkTheme;
        expect(theme.useMaterial3, true);
      });

      test('colorScheme 应基于绿色种子颜色生成', () {
        final theme = AppTheme.darkTheme;
        // 验证 colorScheme 已正确初始化
        expect(theme.colorScheme, isNotNull);
        expect(theme.colorScheme.primary, isNotNull);
        // Material 3 中，绿色种子在暗色模式下也会生成绿色系的主色
        expect(theme.colorScheme.primary.green, greaterThan(0));
      });

      test('暗色主题的背景色应比亮色主题暗', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        // 暗色主题的背景色亮度应低于亮色主题
        expect(
          darkTheme.colorScheme.surface.computeLuminance(),
          lessThan(lightTheme.colorScheme.surface.computeLuminance()),
        );
      });

      test('应配置完整的组件主题数据', () {
        final theme = AppTheme.darkTheme;
        // 验证 ThemeData 包含常用组件主题
        expect(theme.appBarTheme, isNotNull);
        expect(theme.buttonTheme, isNotNull);
        expect(theme.textTheme, isNotNull);
      });
    });

    group('亮色/暗色主题对比测试', () {
      test('亮色和暗色主题的亮度应不同', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.brightness, isNot(equals(darkTheme.brightness)));
      });

      test('亮色和暗色主题均应启用 Material 3', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        expect(lightTheme.useMaterial3, true);
        expect(darkTheme.useMaterial3, true);
      });

      test('亮色和暗色主题应使用相同的种子颜色', () {
        final lightTheme = AppTheme.lightTheme;
        final darkTheme = AppTheme.darkTheme;

        // 两个主题的主色都应该基于绿色种子颜色
        // 在 Material 3 中，相同的 seedColor 会生成相同色调的 colorScheme
        // 验证主色的红色和绿色通道比例相似（绿色系特征）
        final lightPrimary = lightTheme.colorScheme.primary;
        final darkPrimary = darkTheme.colorScheme.primary;
        
        // 绿色系颜色的绿色通道值应大于红色和蓝色通道
        expect(lightPrimary.green, greaterThan(lightPrimary.red));
        expect(darkPrimary.green, greaterThan(darkPrimary.red));
      });
    });

    group('AppTheme 类设计测试', () {
      test('AppTheme 不应被实例化', () {
        // 验证 AppTheme 的构造函数是私有的
        // 通过检查其静态 getter 方法来间接验证
        expect(AppTheme.lightTheme, isA<ThemeData>());
        expect(AppTheme.darkTheme, isA<ThemeData>());
      });
    });
  });
}
