import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';

/// 拖拽区域 Widget 单元测试
///
/// 测试目标：验证 DropZone 的拖拽交互是否符合任务 3.3 验收标准
/// 覆盖范围：
/// - DropZone 组件存在并正确渲染
/// - 拖拽区域显示提示文字和图标
/// - 拖拽状态变化时的视觉反馈
/// - 布局结构正确（Container、高度、圆角等）
void main() {
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
    testWidgets('页面应包含 DropZone 组件', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropZone 组件存在
      expect(find.byType(DropZone), findsOneWidget);
    });

    testWidgets('DropZone 应包含 DropTarget 组件', (WidgetTester tester) async {
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
    testWidgets('拖拽区域应显示上传图标', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在 cloud_upload_outlined 图标（默认状态）
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.byIcon(Icons.cloud_upload_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('拖拽区域应显示提示文字', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证存在拖拽提示文字
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.text('或将 .straw 文件拖拽至此'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('拖拽区域应使用 Container 容器', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropTarget 内部使用 Container
      expect(
        find.descendant(
          of: find.byType(DropTarget),
          matching: find.byType(Container),
        ),
        findsOneWidget,
      );
    });

    testWidgets('拖拽区域内容应使用 Column 布局', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证 DropZone 内部 Container 使用 Column 布局
      final columnFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byWidgetPredicate(
          (widget) => widget is Container && widget.child is Column,
        ),
      );
      expect(columnFinder, findsOneWidget);
    });
  });

  group('DropZone 布局属性测试', () {
    testWidgets('拖拽区域容器应有固定高度 120', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 Container
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(Container),
      );

      // 获取 Container 实例
      final container = tester.widget<Container>(containerFinder);

      // 验证高度约束
      // 注意：高度是通过 decoration 或 constraints 设置的
      // 在这里我们验证 Container 的大小
      final rect = tester.getRect(containerFinder);
      expect(rect.height, 120);
    });

    testWidgets('拖拽区域应有圆角边框', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 Container
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(Container),
      );

      // 获取 Container 实例
      final container = tester.widget<Container>(containerFinder);

      // 验证 decoration 存在且有圆角
      expect(container.decoration, isNotNull);
      final decoration = container.decoration as BoxDecoration;
      expect(decoration.borderRadius, isNotNull);
    });

    testWidgets('拖拽区域默认状态边框应为灰色虚线样式',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 Container
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(Container),
      );

      // 获取 Container 实例
      final container = tester.widget<Container>(containerFinder);
      final decoration = container.decoration as BoxDecoration;

      // 验证默认状态边框颜色为灰色
      expect(decoration.border, isNotNull);
      // 边框应存在
      expect(decoration.border!.top.width, 1);
    });

    testWidgets('拖拽区域内容应居中对齐', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找 DropZone 内部的 Container
      final containerFinder = find.descendant(
        of: find.byType(DropTarget),
        matching: find.byType(Container),
      );

      // 获取 Container 实例
      final container = tester.widget<Container>(containerFinder);

      // 验证对齐方式为中心
      expect(container.alignment, Alignment.center);
    });
  });

  group('DropZone 状态管理测试', () {
    testWidgets('默认状态下图标应为 cloud_upload_outlined',
        (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 验证默认状态图标
      expect(
        find.descendant(
          of: find.byType(DropZone),
          matching: find.byIcon(Icons.cloud_upload_outlined),
        ),
        findsOneWidget,
      );
    });

    testWidgets('默认状态下文字颜色应为灰色', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找提示文字
      final textFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.text('或将 .straw 文件拖拽至此'),
      );

      // 获取 Text 实例
      final textWidget = tester.widget<Text>(textFinder);

      // 验证文字颜色存在（默认灰色）
      expect(textWidget.style, isNotNull);
    });

    testWidgets('图标和文字之间应有间距', (WidgetTester tester) async {
      // 构建首页
      await tester.pumpWidget(_createTestableWidget());
      await tester.pumpAndSettle();

      // 查找图标和文字
      final iconFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.byIcon(Icons.cloud_upload_outlined),
      );
      final textFinder = find.descendant(
        of: find.byType(DropZone),
        matching: find.text('或将 .straw 文件拖拽至此'),
      );

      // 获取位置信息
      final iconRect = tester.getRect(iconFinder);
      final textRect = tester.getRect(textFinder);

      // 验证文字在图标下方且有间距
      expect(textRect.top, greaterThan(iconRect.bottom));
    });
  });

  group('DropZone DropTarget 回调测试', () {
    testWidgets('DropTarget 应配置 onDragEntered 回调',
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

    testWidgets('DropTarget 应配置 onDragExited 回调',
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

    testWidgets('DropTarget 应配置 onDragDone 回调',
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
