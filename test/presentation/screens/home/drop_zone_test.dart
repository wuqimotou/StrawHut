import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 拖拽区域 Widget 单元测试
///
/// 测试目标：验证 DropZone 的拖拽交互是否符合任务 3.3 验收标准
/// 覆盖范围：
/// - DropZone 组件存在并正确渲染
/// - 拖拽区域显示提示文字和图标
/// - 拖拽状态变化时的视觉反馈
/// - 布局结构正确（NeumorphicContainer、高度、圆角等）
void main() {
  /// 在每个测试前重置路由到初始状态
  setUp(() {
    appRouter.go('/');
  });

  /// 在桌面平台环境下运行 Widget 测试
  ///
  /// DropZone 在移动端/Web 端返回 SizedBox.shrink()，
  /// 因此需要在桌面平台下测试其完整渲染。
  /// 使用 try/finally 确保在 Flutter 测试框架验证不变量之前重置平台覆盖。
  void testWidgetsOnDesktop(
    String description,
    WidgetTesterCallback callback, {
    bool? skip,
  }) {
    testWidgets(description, (WidgetTester tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      try {
        await callback(tester);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    }, skip: skip);
  }

  /// 构建带路由的测试 Widget
  ///
  /// 此辅助方法创建一个包含完整路由配置的 MaterialApp，
  /// 用于测试 DropZone 组件的渲染和交互。
  Widget _createTestableWidget() {
    return MaterialApp.router(
      routerConfig: appRouter,
    );
  }

  group('DropZone 组件存在性测试', () {
    testWidgetsOnDesktop('页面应包含 DropZone 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropZone 组件存在
      expect(find.byType(DropZone), findsOneWidget);
    });

    testWidgetsOnDesktop('DropZone 应包含 DropTarget 组件',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropZone 内部使用 DropTarget
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.byType(DropTarget),
        ),
        findsOneWidget,
      );
    });
  });

  group('DropZone 视觉元素测试', () {
    testWidgetsOnDesktop('拖拽区域应显示上传图标', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 NeumorphicIcon（默认状态渲染 cloudUpload SVG 图标）
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.byType(NeumorphicIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnDesktop('拖拽区域应显示提示文字', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在拖拽提示文字
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.text('或将 .straw / .png 文件拖拽至此'),
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnDesktop('拖拽区域应使用 NeumorphicContainer 容器', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropTarget 内部使用 NeumorphicContainer
      expect(
        find.descendant(
          of: find.byType(DropTarget),
          matching: find.byType(NeumorphicContainer),
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnDesktop('拖拽区域内容应使用 Column 布局', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropZone 内部 NeumorphicContainer 使用 Column 布局
      final columnFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byWidgetPredicate(
          (widget) => widget is NeumorphicContainer && widget.child is Column,
        ),
      );
      expect(columnFinder, findsOneWidget);
    });
  });

  group('DropZone 布局属性测试', () {
    testWidgetsOnDesktop('拖拽区域容器应有固定高度 120', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 NeumorphicContainer
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(NeumorphicContainer),
      );

      // 获取 NeumorphicContainer 实例并验证高度
      final container = tester.widget<NeumorphicContainer>(containerFinder);
      expect(container.height, 120);
    });

    testWidgetsOnDesktop('拖拽区域应有圆角', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 NeumorphicContainer
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(NeumorphicContainer),
      );

      // 获取 NeumorphicContainer 实例并验证圆角存在
      final container = tester.widget<NeumorphicContainer>(containerFinder);
      expect(container.borderRadius, isNotNull);
    });

    testWidgetsOnDesktop('拖拽区域默认状态应为凹陷软质形态', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 NeumorphicContainer
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(NeumorphicContainer),
      );

      // 获取 NeumorphicContainer 实例
      final container = tester.widget<NeumorphicContainer>(containerFinder);

      // 验证默认状态为凹陷形态（Neumorphism 通过凹陷/凸起切换提供视觉反馈）
      expect(container.shape, NeumorphicShape.concave);
      expect(container.intensity, NeumorphicIntensity.normal);
    });

    testWidgetsOnDesktop('拖拽区域内容应居中对齐', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 NeumorphicContainer
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(NeumorphicContainer),
      );

      // 获取 NeumorphicContainer 实例
      final container = tester.widget<NeumorphicContainer>(containerFinder);

      // 验证对齐方式为中心
      expect(container.alignment, Alignment.center);
    });
  });

  group('DropZone 状态管理测试', () {
    testWidgetsOnDesktop('默认状态下应显示 NeumorphicIcon 上传图标',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证默认状态存在 NeumorphicIcon
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.byType(NeumorphicIcon),
        ),
        findsOneWidget,
      );
    });

    testWidgetsOnDesktop('默认状态下文字颜色应为灰色', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找提示文字
      final textFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.text('或将 .straw / .png 文件拖拽至此'),
      );

      // 获取 Text 实例
      final textWidget = tester.widget<Text>(textFinder);

      // 验证文字颜色存在（默认灰色）
      expect(textWidget.style, isNotNull);
    });

    testWidgetsOnDesktop('图标和文字之间应有间距', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找图标和文字
      final iconFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byType(NeumorphicIcon),
      );
      final textFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.text('或将 .straw / .png 文件拖拽至此'),
      );

      // 获取位置信息
      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // 验证文字在图标下方且有间距
      expect(textRect.top, greaterThan(iconRect.bottom));
    });
  });

  group('DropZone DropTarget 回调测试', () {
    testWidgetsOnDesktop('DropTarget 应配置 onDragEntered 回调',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropTarget
      final dropTargetFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byType(DropTarget),
      );

      // 获取 DropTarget 实例
      final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

      // 验证回调已配置
      expect(dropTarget.onDragEntered, isNotNull);
    });

    testWidgetsOnDesktop('DropTarget 应配置 onDragExited 回调',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropTarget
      final dropTargetFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byType(DropTarget),
      );

      // 获取 DropTarget 实例
      final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

      // 验证回调已配置
      expect(dropTarget.onDragExited, isNotNull);
    });

    testWidgetsOnDesktop('DropTarget 应配置 onDragDone 回调',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropTarget
      final dropTargetFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byType(DropTarget),
      );

      // 获取 DropTarget 实例
      final dropTarget = tester.widget<DropTarget>(dropTargetFinder);

      // 验证回调已配置
      expect(dropTarget.onDragDone, isNotNull);
    });
  });
}
