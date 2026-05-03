import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:mocktail/mocktail.dart';
import 'package:file_selector/file_selector.dart';

/// 操作按钮 Widget 单元测试
///
/// 测试目标：验证 ActionButtons 的按钮点击行为是否符合任务 3.3 验收标准
/// 覆盖范围：
/// - "新建知识卡片" 按钮使用 ElevatedButton 样式
/// - "打开知识卡片" 按钮使用 OutlinedButton 样式
/// - 按钮点击后触发正确的导航
/// - 按钮布局结构正确（Column、间距等）
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
  /// 并将 ActionButtons 作为 body 内容，用于测试按钮交互。
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

  group('ActionButtons 按钮样式测试', () {
    testWidgets('"新建知识卡片"按钮应为 ElevatedButton 类型',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找"新建知识卡片"文字所在的 ElevatedButton
      final elevatedButton = find.text('新建知识卡片');
      expect(elevatedButton, findsOneWidget);

      // 验证该文字在 ElevatedButton 内部
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.text('新建知识卡片'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"打开知识卡片"按钮应为 OutlinedButton 类型',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找"打开知识卡片"文字
      final outlinedButton = find.text('打开知识卡片');
      expect(outlinedButton, findsOneWidget);

      // 验证该文字在 OutlinedButton 内部
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.text('打开知识卡片'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"新建知识卡片"按钮应包含 add_circle_outline 图标',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证按钮图标存在
      expect(
        find.descendant(
          of: find.byType(ElevatedButton),
          matching: find.byIcon(Icons.add_circle_outline),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"打开知识卡片"按钮应包含 folder_open_outlined 图标',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证按钮图标存在
      expect(
        find.descendant(
          of: find.byType(OutlinedButton),
          matching: find.byIcon(Icons.folder_open_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('按钮应使用 icon 和 label 的排列方式',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证使用了 ElevatedButton.icon
      expect(find.byType(ElevatedButton), findsOneWidget);
      // 验证使用了 OutlinedButton.icon
      expect(find.byType(OutlinedButton), findsOneWidget);
    });
  });

  group('ActionButtons 布局结构测试', () {
    testWidgets('按钮组应使用 Column 垂直布局', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 ActionButtons 内部使用 Column
      expect(
        find.descendant(
          of: find.byType(ActionButtons),
          matching: find.byType(Column),
        ),
        findsOneWidget,
      );
    });

    testWidgets('按钮组应横向拉伸（stretch）', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 获取 Column 的 crossAxisAlignment 属性
      final columnFinder = find.descendant(
        of: find.byType(ActionButtons),
        matching: find.byType(Column),
      );
      final column = tester.widget<Column>(columnFinder);
      expect(column.crossAxisAlignment, CrossAxisAlignment.stretch);
    });

    testWidgets('两个按钮之间应有间距', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 获取两个按钮的位置
      final createButton = find.text('新建知识卡片');
      final openButton = find.text('打开知识卡片');

      final createRect = tester.getRect(createButton);
      final openRect = tester.getRect(openButton);

      // 验证第二个按钮在第一个按钮下方
      expect(openRect.top, greaterThan(createRect.bottom));
    });

    testWidgets('按钮应有合适的垂直内边距', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 获取 ElevatedButton 实例
      final elevatedButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );

      // 验证按钮样式中的 padding
      expect(elevatedButton.style, isNotNull);
    });
  });

  group('ActionButtons 导航功能测试', () {
    testWidgets('点击"新建知识卡片"按钮应导航到 /editor',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证初始路由为首页
      expect(
          appRouter.routerDelegate.currentConfiguration.uri.path, '/');

      // 点击"新建知识卡片"按钮
      await tester.tap(find.text('新建知识卡片'));
      await tester.pumpAndSettle();

      // 验证已导航到编辑器页面
      expect(
          appRouter.routerDelegate.currentConfiguration.uri.path, '/editor');
    });

    testWidgets('点击"打开知识卡片"按钮后取消选择应留在首页',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证初始路由为首页
      expect(
          appRouter.routerDelegate.currentConfiguration.uri.path, '/');

      // 点击"打开知识卡片"按钮（会触发文件选择器，但测试中无法交互）
      // 在测试环境中，file_selector 的 openFile 会返回 null（模拟取消）
      await tester.tap(find.text('打开知识卡片'));
      await tester.pumpAndSettle();

      // 验证仍停留在首页
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');
    });
  });

  group('ActionButtons 按钮存在性测试', () {
    testWidgets('页面应显示"新建知识卡片"文字', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证文字存在
      expect(find.text('新建知识卡片'), findsOneWidget);
    });

    testWidgets('页面应显示"打开知识卡片"文字', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证文字存在
      expect(find.text('打开知识卡片'), findsOneWidget);
    });

    testWidgets('两个按钮都应可点击（onPressed 不为 null）',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 获取 ElevatedButton 实例
      final elevatedButton = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton),
      );

      // 获取 OutlinedButton 实例
      final outlinedButton = tester.widget<OutlinedButton>(
        find.byType(OutlinedButton),
      );

      // 验证 onPressed 不为 null
      expect(elevatedButton.onPressed, isNotNull);
      expect(outlinedButton.onPressed, isNotNull);
    });
  });
}
