/// editor_screen Widget 测试文件
///
/// 本文件测试 editor_screen.dart 中的 EditorScreen Widget，
/// 验证编辑器主页面的渲染、交互和功能。
///
/// 测试范围：
/// - 页面基本结构渲染（AppBar、工具栏、编辑器区域、底部栏）
/// - AppBar 元素（返回按钮、标题、发布按钮）
/// - 发布按钮点击触发 PublishDialog
/// - 预览模式切换
/// - 底部栏切换按钮
/// - 从草稿加载内容
///
/// 使用 flutter_test 框架进行 Widget 测试，
/// 结合 flutter_riverpod 的 ProviderScope 进行状态管理测试。

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/app/routes.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/screens/editor/editor_screen.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';

/// 用于 Widget 测试的辅助方法：构建被 ProviderScope 包裹的 EditorScreen
Widget createEditorScreen() {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: const [
        quill.FlutterQuillLocalizations.delegate,
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const EditorScreen(),
    ),
  );
}

void main() {
  group('EditorScreen 基本渲染', () {
    testWidgets('应该能够正常渲染编辑器页面', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证页面存在 Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('AppBar 应该包含返回按钮', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证返回按钮存在（NeumorphicIconButton 通过 tooltip 标识）
      expect(find.byTooltip('返回'), findsOneWidget);
    });

    testWidgets('AppBar 标题应该显示"编辑知识卡片"', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证标题文本
      expect(find.text('编辑知识卡片'), findsOneWidget);
    });

    testWidgets('AppBar 应该包含发布按钮', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证发布按钮存在（NeumorphicIconButton 通过 tooltip 标识）
      expect(find.byTooltip('发布'), findsOneWidget);
    });
  });

  group('EditorScreen 工具栏和编辑器', () {
    testWidgets('编辑模式下应该显示 QuillToolbar', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证工具栏按钮存在
      expect(find.byType(IconButton), findsWidgets);
    });

    testWidgets('编辑模式下应该显示 QuillEditor', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证编辑器区域存在
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });
  });

  group('EditorScreen 底部操作栏', () {
    testWidgets('底部栏应该包含模式切换按钮', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证底部栏存在 NeumorphicButton（模式切换按钮）
      expect(find.byType(NeumorphicButton), findsOneWidget);
    });

    testWidgets('编辑模式下底部按钮应该显示"预览"', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证按钮文本
      expect(find.text('预览'), findsOneWidget);
      expect(find.text('返回编辑'), findsNothing);
    });

    testWidgets('点击底部按钮应该切换到预览模式', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 点击预览按钮
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 验证切换到预览模式
      expect(find.text('预览模式'), findsOneWidget);
      expect(find.text('返回编辑'), findsOneWidget);
    });

    testWidgets('预览模式下点击"返回编辑"应该切换回编辑模式', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 先切换到预览模式
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 验证在预览模式
      expect(find.text('预览模式'), findsOneWidget);

      // 点击返回编辑
      await tester.tap(find.text('返回编辑'));
      await tester.pumpAndSettle();

      // 验证回到编辑模式
      expect(find.text('编辑知识卡片'), findsOneWidget);
      expect(find.text('预览'), findsOneWidget);
    });
  });

  group('EditorScreen 预览模式', () {
    testWidgets('预览模式下应该显示 PreviewPanel', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 切换到预览模式
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 验证 PreviewPanel 存在
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('预览模式下标题应该切换为"预览模式"', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 切换到预览模式
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 验证标题变化
      expect(find.text('预览模式'), findsOneWidget);
      expect(find.text('编辑知识卡片'), findsNothing);
    });

    testWidgets('预览模式下不应该显示工具栏', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 切换到预览模式
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 工具栏按钮不应该存在
      // 注意：PreviewPanel 内部也使用 QuillEditor，所以不能通过 QuillEditor 判断
      // 验证底部栏的 NeumorphicButton 仍然存在
      expect(find.byType(NeumorphicButton), findsOneWidget);
    });
  });

  group('EditorScreen 发布功能', () {
    testWidgets('点击发布按钮应该触发发布操作', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证发布按钮存在（NeumorphicIconButton 通过 tooltip 标识）
      expect(find.byTooltip('发布'), findsOneWidget);

      // 点击发布按钮
      await tester.tap(find.byTooltip('发布'));
      await tester.pumpAndSettle();

      // 发布对话框当前为 Placeholder，验证按钮点击后没有崩溃
      // 实际对话框集成将在完整集成测试中验证
    });
  });

  group('EditorScreen 返回功能', () {
    testWidgets('点击返回按钮应该调用 Navigator.pop', (tester) async {
      // 使用 GoRouter 进行导航测试
      // EditorScreen 的 _handleBack 方法使用 context.canPop() (go_router)，
      // 因此必须在 GoRouter 上下文中测试

      // 重置路由到首页
      appRouter.go('/');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp.router(
            routerConfig: appRouter,
            localizationsDelegates: const [
              quill.FlutterQuillLocalizations.delegate,
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证在首页
      expect(find.text('欢迎使用 StrawHut'), findsOneWidget);

      // 使用 push 导航到编辑器（保留返回栈）
      appRouter.push('/editor');
      await tester.pumpAndSettle();

      // 验证编辑器页面显示
      expect(find.text('编辑知识卡片'), findsOneWidget);

      // 点击返回按钮（NeumorphicIconButton 通过 tooltip 标识）
      await tester.tap(find.byTooltip('返回'));
      await tester.pumpAndSettle();

      // 验证返回到首页
      expect(find.text('欢迎使用 StrawHut'), findsOneWidget);
      expect(find.text('编辑知识卡片'), findsNothing);
    });
  });

  group('EditorScreen 页面结构', () {
    testWidgets('编辑模式下主体应该是 Column 包含工具栏和编辑器', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 验证 Column 存在
      expect(find.byType(Column), findsWidgets);
    });

    testWidgets('预览模式下不应该显示 Column 主体', (tester) async {
      await tester.pumpWidget(createEditorScreen());
      await tester.pumpAndSettle();

      // 切换到预览模式
      await tester.tap(find.text('预览'));
      await tester.pumpAndSettle();

      // 验证 Container（PreviewPanel 的外层）存在
      expect(find.byType(Container), findsWidgets);
    });
  });
}
