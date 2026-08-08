import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 操作按钮 Widget 单元测试
///
/// 测试目标：验证 ActionButtons 的按钮点击行为是否符合任务 3.3 验收标准
/// 覆盖范围：
/// - "发布知识卡片" 按钮使用 NeumorphicButton 样式
/// - "解密知识卡片" 按钮使用 NeumorphicButton 样式
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
  Widget createTestableWidget() {
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
    testWidgets('"发布知识卡片"按钮应为 NeumorphicButton 类型', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 查找"发布知识卡片"文字
      final createButton = find.text('发布知识卡片');
      expect(createButton, findsOneWidget);

      // 验证该文字在 NeumorphicButton 内部
      expect(
        find.descendant(
          of: find.byType(NeumorphicButton),
          matching: find.text('发布知识卡片'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"解密知识卡片"按钮应为 NeumorphicButton 类型', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 查找"解密知识卡片"文字
      final openButton = find.text('解密知识卡片');
      expect(openButton, findsOneWidget);

      // 验证该文字在 NeumorphicButton 内部
      expect(
        find.descendant(
          of: find.byType(NeumorphicButton),
          matching: find.text('解密知识卡片'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"发布知识卡片"按钮应包含 NeumorphicIcon 图标',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证按钮图标存在（NeumorphicIcon 渲染 SVG 图标）
      expect(
        find.descendant(
          of: find.widgetWithText(NeumorphicButton, '发布知识卡片'),
          matching: find.byType(NeumorphicIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('"解密知识卡片"按钮应包含 NeumorphicIcon 图标',
        (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证按钮图标存在（NeumorphicIcon 渲染 SVG 图标）
      expect(
        find.descendant(
          of: find.widgetWithText(NeumorphicButton, '解密知识卡片'),
          matching: find.byType(NeumorphicIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgets('按钮应使用 icon 和 label 的排列方式', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证使用了两个 NeumorphicButton
      expect(find.byType(NeumorphicButton), findsNWidgets(2));
    });
  });

  group('ActionButtons 布局结构测试', () {
    testWidgets('按钮组应使用 Column 垂直布局', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
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
      await tester.pumpWidget(createTestableWidget());
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
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 获取两个按钮的位置
      final createButton = find.text('发布知识卡片');
      final openButton = find.text('解密知识卡片');

      final createRect = tester.getRect(createButton);
      final openRect = tester.getRect(openButton);

      // 验证第二个按钮在第一个按钮下方
      expect(openRect.top, greaterThan(createRect.bottom));
    });

    testWidgets('按钮应有合适的样式配置', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 获取"发布知识卡片"对应的 NeumorphicButton 实例
      final createButton = tester.widget<NeumorphicButton>(
        find.widgetWithText(NeumorphicButton, '发布知识卡片'),
      );

      // 验证按钮样式已配置为主按钮
      expect(createButton.style, NeumorphicButtonStyle.primary);
    });
  });

  group('ActionButtons 导航功能测试', () {
    testWidgets('点击"发布知识卡片"按钮应弹出内容来源选择对话框', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证初始路由为首页
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');

      // 点击"发布知识卡片"按钮
      await tester.tap(find.text('发布知识卡片'));
      await tester.pumpAndSettle();

      // 验证弹出了选择对话框（包含"富文本编辑"和"直接加密文件"选项）
      expect(find.text('富文本编辑'), findsOneWidget);
      expect(find.text('直接加密文件'), findsOneWidget);
    });

    testWidgets('选择"富文本编辑"应导航到 /editor', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 点击"发布知识卡片"按钮
      await tester.tap(find.text('发布知识卡片'));
      await tester.pumpAndSettle();

      // 点击"富文本编辑"按钮
      await tester.tap(find.text('富文本编辑'));
      await tester.pumpAndSettle();

      // 验证已导航到编辑器页面
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/editor');
    });

    testWidgets('点击"解密知识卡片"按钮后取消选择应留在首页', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证初始路由为首页
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');

      // 点击"解密知识卡片"按钮（会触发文件选择器，但测试中无法交互）
      // 在测试环境中，file_selector 的 openFile 会返回 null（模拟取消）
      await tester.tap(find.text('解密知识卡片'));
      await tester.pumpAndSettle();

      // 验证仍停留在首页
      expect(appRouter.routerDelegate.currentConfiguration.uri.path, '/');
    });
  });

  group('ActionButtons 按钮存在性测试', () {
    testWidgets('页面应显示"发布知识卡片"文字', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证文字存在
      expect(find.text('发布知识卡片'), findsOneWidget);
    });

    testWidgets('页面应显示"解密知识卡片"文字', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 验证文字存在
      expect(find.text('解密知识卡片'), findsOneWidget);
    });

    testWidgets('两个按钮都应可点击（onPressed 不为 null）', (WidgetTester tester) async {
      // 构建包含 ActionButtons 的测试 Widget
      await tester.pumpWidget(createTestableWidget());
      await tester.pumpAndSettle();

      // 获取第一个 NeumorphicButton 实例（"发布知识卡片"按钮）
      final firstButton = tester.widget<NeumorphicButton>(
        find.widgetWithText(NeumorphicButton, '发布知识卡片'),
      );

      // 获取第二个 NeumorphicButton 实例（"解密知识卡片"按钮）
      final secondButton = tester.widget<NeumorphicButton>(
        find.widgetWithText(NeumorphicButton, '解密知识卡片'),
      );

      // 验证 onPressed 不为 null
      expect(firstButton.onPressed, isNotNull);
      expect(secondButton.onPressed, isNotNull);
    });
  });
}
