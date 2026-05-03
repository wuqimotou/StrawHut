import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/home/home_screen.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';

/// 首页 Widget 单元测试
///
/// 测试目标：验证 HomeScreen 页面布局和组件是否符合任务 3.3 验收标准
/// 覆盖范围：
/// - 页面包含 AppBar、标题、Logo 图标
/// - "新建知识卡片" 按钮存在且点击后导航到 /editor
/// - "打开知识卡片" 按钮存在
/// - DropZone 组件存在
/// - 布局结构正确（Column、居中、间距等）
void main() {
  /// 在每个测试前重置路由到初始状态
  ///
  /// 因为 appRouter 是全局单例，测试之间会共享状态，
  /// 所以每次测试前都需要重置路由到首页。
  setUp(() {
    appRouter.go('/');
  });

  /// 构建带路由的测试 Widget
  ///
  /// 此辅助方法创建一个包含完整路由配置的 MaterialApp，
  /// 用于测试需要导航功能的 Widget。
  /// 使用 ProviderScope 包裹以支持 EditorScreen 中的 Riverpod 依赖。
  Widget _createTestableWidget() {
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

  group('HomeScreen 页面布局测试', () {
    testWidgets('页面应包含 Scaffold 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证页面根组件为 Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('页面应包含 AppBar 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 AppBar
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('AppBar 标题应显示 "StrawHut - 去中心化加密知识分享平台"',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 AppBar 标题文字
      expect(
        find.text('StrawHut - 去中心化加密知识分享平台'),
        findsOneWidget,
      );
    });

    testWidgets('AppBar 标题应居中显示', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 AppBar 并验证 centerTitle 属性
      final appBar = tester.widget<AppBar>(find.byType(AppBar));
      expect(appBar.centerTitle, true);
    });

    testWidgets('页面应显示欢迎标题 "欢迎使用 StrawHut"',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证欢迎标题文字存在
      expect(find.text('欢迎使用 StrawHut'), findsOneWidget);
    });

    testWidgets('页面应显示副标题引导文字', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证副标题文字存在
      expect(
        find.text('创建加密知识卡片，安全分享你的知识'),
        findsOneWidget,
      );
    });

    testWidgets('页面应显示大号 Lock 图标作为 Logo',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 lock_outline_rounded 图标
      expect(find.byIcon(Icons.lock_outline_rounded), findsOneWidget);

      // 验证图标大小为 80
      final icon = tester.widget<Icon>(find.byIcon(Icons.lock_outline_rounded));
      expect(icon.size, 80);
    });
  });

  group('HomeScreen 组件结构测试', () {
    testWidgets('页面应包含 ActionButtons 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 ActionButtons 组件
      expect(find.byType(ActionButtons), findsOneWidget);
    });

    testWidgets('页面应包含 DropZone 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 DropZone 组件
      expect(find.byType(DropZone), findsOneWidget);
    });

    testWidgets('页面 body 应使用 Column 布局', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 Column 布局
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('页面 body 应使用 Center 居中对齐', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 Scaffold 的 body 使用 Center 组件（通过查找 HomeScreen 内部的 Center）
      // 注意：MaterialApp 内部也会使用 Center，所以我们验证至少有一个 Center
      final centerWidgets = tester.widgetList<Center>(find.byType(Center));
      expect(centerWidgets.isNotEmpty, true);
      
      // 验证 HomeScreen 的 Column 被 Center 包裹
      final columnFinder = find.descendant(
        of: find.byType(HomeScreen),
        matching: find.byWidgetPredicate(
          (widget) => widget is Center && widget.child is SingleChildScrollView,
        ),
      );
      expect(columnFinder, findsWidgets);
    });

    testWidgets('页面 body 应使用 SingleChildScrollView 支持滚动',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 SingleChildScrollView 用于支持小屏幕滚动
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('页面 body 应使用 ConstrainedBox 限制最大宽度',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 ConstrainedBox 用于宽度限制
      expect(find.byType(ConstrainedBox), findsWidgets);
    });

    testWidgets('页面组件排列顺序应为：图标 -> 标题 -> 副标题 -> 按钮 -> 拖拽区域',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 获取所有可见的文字和图标
      final iconFinder = find.byIcon(Icons.lock_outline_rounded);
      final welcomeFinder = find.text('欢迎使用 StrawHut');
      final subtitleFinder = find.text('创建加密知识卡片，安全分享你的知识');
      final createButtonFinder = find.text('新建知识卡片');
      final openButtonFinder = find.text('打开知识卡片');
      final dropZoneFinder = find.text('或将 .straw 文件拖拽至此');

      // 验证所有元素都存在
      expect(iconFinder, findsOneWidget);
      expect(welcomeFinder, findsOneWidget);
      expect(subtitleFinder, findsOneWidget);
      expect(createButtonFinder, findsOneWidget);
      expect(openButtonFinder, findsOneWidget);
      expect(dropZoneFinder, findsOneWidget);

      // 验证垂直排列顺序
      final iconRect = tester.getRect(iconFinder);
      final welcomeRect = tester.getRect(welcomeFinder);
      final subtitleRect = tester.getRect(subtitleFinder);
      final createButtonRect = tester.getRect(createButtonFinder);
      final openButtonRect = tester.getRect(openButtonFinder);
      final dropZoneRect = tester.getRect(dropZoneFinder);

      // 验证从上到下的顺序
      expect(welcomeRect.top, greaterThan(iconRect.bottom));
      expect(subtitleRect.top, greaterThan(welcomeRect.bottom));
      expect(createButtonRect.top, greaterThan(subtitleRect.bottom));
      expect(openButtonRect.top, greaterThan(createButtonRect.bottom));
      expect(dropZoneRect.top, greaterThan(openButtonRect.bottom));
    });
  });

  group('HomeScreen 导航功能测试', () {
    testWidgets('点击"新建知识卡片"按钮应导航到 /editor',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证初始路由为首页
      expect(
          appRouter.routerDelegate.currentConfiguration.uri.path, '/');

      // 查找并点击"新建知识卡片"按钮
      final createButton = find.text('新建知识卡片');
      expect(createButton, findsOneWidget);
      await tester.tap(createButton);
      await tester.pumpAndSettle();

      // 验证已导航到编辑器页面
      expect(
          appRouter.routerDelegate.currentConfiguration.uri.path, '/editor');
    });
  });
}
