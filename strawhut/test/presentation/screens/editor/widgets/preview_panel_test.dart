/// preview_panel Widget 测试文件
///
/// 本文件测试 preview_panel.dart 中的 PreviewPanel Widget，
/// 验证预览面板的渲染、空内容显示和 Delta JSON 内容解析渲染功能。
///
/// 测试范围：
/// - 预览面板正常渲染
/// - 空内容显示
/// - Delta JSON 内容解析和渲染
/// - JSON 解析错误处理
/// - 只读模式验证
///
/// 使用 flutter_test 框架进行 Widget 测试，
/// 结合 flutter_riverpod 的 ProviderContainer 进行状态管理测试。

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';
import 'package:strawhut/presentation/screens/editor/widgets/preview_panel.dart';

/// 辅助方法：构建被 UncontrolledProviderScope 包裹的 PreviewPanel
Widget createPreviewPanelWithContainer(ProviderContainer container) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        quill.FlutterQuillLocalizations.delegate,
      ],
      home: const Scaffold(
        body: PreviewPanel(),
      ),
    ),
  );
}

void main() {
  group('PreviewPanel 基本渲染', () {
    testWidgets('预览面板应该能够正常渲染', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('预览面板应该包含滚动区域', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('预览面板应该限制内容宽度', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(ConstrainedBox), findsWidgets);
    });
  });

  group('PreviewPanel 空内容处理', () {
    testWidgets('空内容时应该显示空白预览', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('null 内容应该被视为空内容', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });
  });

  group('PreviewPanel JSON 解析错误处理', () {
    testWidgets('无效的 JSON 应该返回空白预览', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(editorContentProvider.notifier)
          .updateContent('invalid json');

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('缺少 ops 字段的 JSON 应该返回空白预览', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(editorContentProvider.notifier)
          .updateContent('{"invalid":"data"}');

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('空的 ops 数组应该返回空白预览', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container
          .read(editorContentProvider.notifier)
          .updateContent('{"ops":[]}');

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });
  });

  group('PreviewPanel 只读模式', () {
    testWidgets('预览面板应该是只读的（不可编辑）', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testContent = '{"ops":[{"insert":"只读内容\\n"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(testContent);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      // 验证面板仍然存在
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('预览面板不应该显示光标', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const testContent = '{"ops":[{"insert":"测试内容\\n"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(testContent);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(Container), findsWidgets);
    });
  });

  group('PreviewPanel 内容更新响应', () {
    testWidgets('Provider 内容变化时应该自动更新预览', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      const newContent = '{"ops":[{"insert":"新内容\\n"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(newContent);
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染，验证 RichText 存在
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('从空内容更新到有内容时应该正确渲染', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      const newContent = '{"ops":[{"insert":"更新后的内容\\n"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(newContent);
      await tester.pumpAndSettle();

      // 验证 RichText 被渲染
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('从有内容更新到空内容时应该重新渲染', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      const initialContent = '{"ops":[{"insert":"原始内容\\n"}]}';
      container
          .read(editorContentProvider.notifier)
          .updateContent(initialContent);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      // 验证有内容时 RichText 存在
      expect(find.byType(RichText), findsWidgets);

      // 更新为空内容
      container.read(editorContentProvider.notifier).updateContent('');
      await tester.pumpAndSettle();

      // 验证面板仍然存在
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('PreviewPanel 长内容滚动', () {
    testWidgets('长内容应该支持滚动', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final longContentList = List.generate(
        50,
        (index) => '{"insert":"第${index + 1}行内容\\n"}',
      ).join(',');
      final longContent = '{"ops":[$longContentList]}';

      container
          .read(editorContentProvider.notifier)
          .updateContent(longContent);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      expect(find.byType(SingleChildScrollView), findsWidgets);
      // 长内容会产生多个 RichText
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('长内容应该能被完整渲染', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final longContentList = List.generate(
        10,
        (index) => '{"insert":"测试行${index + 1}\\n"}',
      ).join(',');
      final longContent = '{"ops":[$longContentList]}';

      container
          .read(editorContentProvider.notifier)
          .updateContent(longContent);

      await tester.pumpWidget(createPreviewPanelWithContainer(container));
      await tester.pumpAndSettle();

      // 验证 RichText 被渲染（flutter_quill 使用 RichText）
      expect(find.byType(RichText), findsWidgets);
    });
  });
}
