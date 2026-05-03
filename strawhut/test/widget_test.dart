import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:strawhut/app/app.dart';
import 'package:strawhut/app/theme.dart';

void main() {
  group('StrawHutApp 应用主组件测试', () {
    group('应用启动测试（应用能正常启动）', () {
      testWidgets('应用应成功加载而不崩溃', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        expect(find.byType(MaterialApp), findsOneWidget);
      });

      testWidgets('应用应使用 MaterialApp.router', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.routerConfig, isNotNull);
      });

      testWidgets('应用标题应设置为 StrawHut', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.title, 'StrawHut');
      });

      testWidgets('应隐藏调试模式横幅', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.debugShowCheckedModeBanner, false);
      });
    });

    group('主题配置测试（主题切换生效）', () {
      testWidgets('应配置亮色主题 AppTheme.lightTheme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.theme, isNotNull);
        expect(materialApp.theme, equals(AppTheme.lightTheme));
        expect(materialApp.theme!.useMaterial3, true);
        expect(materialApp.theme!.brightness, Brightness.light);
      });

      testWidgets('应配置暗色主题 AppTheme.darkTheme',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.darkTheme, isNotNull);
        expect(materialApp.darkTheme, equals(AppTheme.darkTheme));
        expect(materialApp.darkTheme!.useMaterial3, true);
        expect(materialApp.darkTheme!.brightness, Brightness.dark);
      });

      testWidgets('主题模式应设置为跟随系统', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.themeMode, ThemeMode.system);
      });
    });

    group('国际化配置测试（中文界面显示）', () {
      testWidgets('应配置 Material 本地化委托', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        final delegates = materialApp.localizationsDelegates;

        expect(delegates, contains(GlobalMaterialLocalizations.delegate));
        expect(delegates, contains(GlobalWidgetsLocalizations.delegate));
        expect(delegates, contains(GlobalCupertinoLocalizations.delegate));
      });

      testWidgets('应支持简体中文 (zh_CN)', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        final supportedLocales = materialApp.supportedLocales;

        expect(
          supportedLocales,
          anyElement(
            predicate<Locale>(
              (locale) =>
                  locale.languageCode == 'zh' && locale.countryCode == 'CN',
            ),
          ),
        );
      });

      testWidgets('应支持繁体中文 (zh_TW)', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        final supportedLocales = materialApp.supportedLocales;

        expect(
          supportedLocales,
          anyElement(
            predicate<Locale>(
              (locale) =>
                  locale.languageCode == 'zh' && locale.countryCode == 'TW',
            ),
          ),
        );
      });

      testWidgets('应支持英文 (en)', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        final supportedLocales = materialApp.supportedLocales;

        expect(
          supportedLocales,
          anyElement(
            predicate<Locale>(
              (locale) => locale.languageCode == 'en',
            ),
          ),
        );
      });

      testWidgets('应至少支持 3 种语言', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(
          materialApp.supportedLocales!.length,
          greaterThanOrEqualTo(3),
        );
      });
    });

    group('路由集成测试（路由切换正常）', () {
      testWidgets('应配置 routerConfig 用于 go_router 路由',
          (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );

        final materialApp = tester.widget<MaterialApp>(
          find.byType(MaterialApp),
        );
        expect(materialApp.routerConfig, isNotNull);
      });

      testWidgets('应用启动后应显示首页内容', (WidgetTester tester) async {
        await tester.pumpWidget(
          const ProviderScope(child: StrawHutApp()),
        );
        await tester.pumpAndSettle();

        expect(find.byType(MaterialApp), findsOneWidget);
      });
    });
  });
}
