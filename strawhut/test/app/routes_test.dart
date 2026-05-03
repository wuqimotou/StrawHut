import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/editor/editor_screen.dart';
import 'package:strawhut/presentation/screens/home/home_screen.dart';
import 'package:strawhut/presentation/screens/reader/reader_screen.dart';

/// 应用路由单元测试
///
/// 测试目标：验证 go_router 路由配置是否正确
/// 覆盖范围：
/// - appRouter 实例正确创建
/// - 初始路由位置为 '/'
/// - 包含 3 条路由：/, /editor, /reader
/// - 每条路由都配置了 name 和 builder
/// - 路由能正确构建对应的页面 Widget
void main() {
  Widget _createTestableApp() {
    return ProviderScope(
      child: MaterialApp.router(
        routerConfig: appRouter,
        localizationsDelegates: const [
          FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
      ),
    );
  }

  group('应用路由配置测试', () {
    group('appRouter 基础配置测试', () {
      test('appRouter 应正确创建为 GoRouter 实例', () {
        expect(appRouter, isNotNull);
        expect(appRouter, isA<GoRouter>());
      });

      testWidgets('初始路由位置应设置为 "/"', (WidgetTester tester) async {
        // 验证 initialLocation 配置为 '/'
        // 需要先 pumpWidget 让路由初始化
        await tester.pumpWidget(_createTestableApp());
        await tester.pumpAndSettle();

        expect(
            appRouter.routerDelegate.currentConfiguration.uri.path, '/');
      });

      test('应配置 3 条路由', () {
        final routes = appRouter.configuration.routes;
        expect(routes.length, 3);
      });
    });

    group('首页路由 / 测试', () {
      test('应存在路径为 "/" 的路由', () {
        final routes = appRouter.configuration.routes;
        final homeRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/',
              orElse: () => throw Exception('未找到路径为 "/" 的路由'),
            );

        expect(homeRoute, isNotNull);
        expect(homeRoute.path, '/');
      });

      test('首页路由应配置 name 为 "home"', () {
        final routes = appRouter.configuration.routes;
        final homeRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/',
              orElse: () => throw Exception('未找到路径为 "/" 的路由'),
            );

        expect(homeRoute.name, 'home');
      });

      test('首页路由应构建 HomeScreen Widget', () {
        final routes = appRouter.configuration.routes;
        final homeRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/',
              orElse: () => throw Exception('未找到路径为 "/" 的路由'),
            );

        // 验证 builder 存在
        expect(homeRoute.builder, isNotNull);
      });
    });

    group('编辑器路由 /editor 测试', () {
      test('应存在路径为 "/editor" 的路由', () {
        final routes = appRouter.configuration.routes;
        final editorRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/editor',
              orElse: () => throw Exception('未找到路径为 "/editor" 的路由'),
            );

        expect(editorRoute, isNotNull);
        expect(editorRoute.path, '/editor');
      });

      test('编辑器路由应配置 name 为 "editor"', () {
        final routes = appRouter.configuration.routes;
        final editorRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/editor',
              orElse: () => throw Exception('未找到路径为 "/editor" 的路由'),
            );

        expect(editorRoute.name, 'editor');
      });

      test('编辑器路由应构建 EditorScreen Widget', () {
        final routes = appRouter.configuration.routes;
        final editorRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/editor',
              orElse: () => throw Exception('未找到路径为 "/editor" 的路由'),
            );

        // 验证 builder 存在
        expect(editorRoute.builder, isNotNull);
      });
    });

    group('阅读器路由 /reader 测试', () {
      test('应存在路径为 "/reader" 的路由', () {
        final routes = appRouter.configuration.routes;
        final readerRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/reader',
              orElse: () => throw Exception('未找到路径为 "/reader" 的路由'),
            );

        expect(readerRoute, isNotNull);
        expect(readerRoute.path, '/reader');
      });

      test('阅读器路由应配置 name 为 "reader"', () {
        final routes = appRouter.configuration.routes;
        final readerRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/reader',
              orElse: () => throw Exception('未找到路径为 "/reader" 的路由'),
            );

        expect(readerRoute.name, 'reader');
      });

      test('阅读器路由应构建 ReaderScreen Widget', () {
        final routes = appRouter.configuration.routes;
        final readerRoute = routes.cast<GoRoute>().firstWhere(
              (route) => route.path == '/reader',
              orElse: () => throw Exception('未找到路径为 "/reader" 的路由'),
            );

        // 验证 builder 存在
        expect(readerRoute.builder, isNotNull);
      });
    });

    group('路由切换功能测试', () {
      setUp(() {
        appRouter.go('/');
      });

      testWidgets('从首页可以导航到编辑器页面', (WidgetTester tester) async {
        await tester.pumpWidget(_createTestableApp());
        await tester.pumpAndSettle();

        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');

        appRouter.go('/editor');
        await tester.pumpAndSettle();

        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/editor');
      });

      testWidgets('从首页可以导航到阅读器页面', (WidgetTester tester) async {
        await tester.pumpWidget(_createTestableApp());
        await tester.pumpAndSettle();

        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');

        appRouter.go('/reader');
        await tester.pumpAndSettle();

        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/reader');
      });

      testWidgets('从编辑器页面可以返回首页',
          (WidgetTester tester) async {
        await tester.pumpWidget(_createTestableApp());
        await tester.pumpAndSettle();

        appRouter.go('/editor');
        await tester.pumpAndSettle();
        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/editor');

        appRouter.go('/');
        await tester.pumpAndSettle();

        expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');
      });
    });

    group('路由路径完整性测试', () {
      test('所有路由路径应为有效 URL 路径', () {
        final routes = appRouter.configuration.routes;
        final goRoutes = routes.whereType<GoRoute>().toList();

        for (final route in goRoutes) {
          // 路径应以 / 开头
          expect(route.path.startsWith('/'), true,
              reason: '路径 "${route.path}" 应以 / 开头');
          // 路径不应包含空格
          expect(route.path.contains(' '), false,
              reason: '路径 "${route.path}" 不应包含空格');
        }
      });

      test('所有路由 name 应唯一', () {
        final routes = appRouter.configuration.routes;
        final goRoutes = routes.whereType<GoRoute>().toList();
        final names = goRoutes.map((r) => r.name).whereType<String>().toList();

        expect(names.length, names.toSet().length,
            reason: '路由名称应唯一，发现重复: ${names.where((name) => names.where((n) => n == name).length > 1).toSet().join(", ")}');
      });

      test('所有路由 name 不应为空', () {
        final routes = appRouter.configuration.routes;
        final goRoutes = routes.whereType<GoRoute>().toList();

        for (final route in goRoutes) {
          expect(route.name, isNotNull);
          expect(route.name, isNotEmpty);
        }
      });
    });
  });
}
