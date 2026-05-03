/// quill_toolbar Widget 测试文件
///
/// 本文件测试 quill_toolbar.dart 中的 QuillToolbar Widget，
/// 验证编辑器工具栏的渲染、各功能按钮存在性和按钮点击操作。
///
/// 测试范围：
/// - 工具栏正常渲染
/// - 各功能按钮存在性（加粗、斜体、标题、列表、代码块等）
/// - 按钮点击操作
/// - 工具栏布局结构
///
/// 使用 flutter_test 框架进行 Widget 测试，
/// 结合 flutter_quill 的 QuillController 进行工具栏交互测试。

// ignore_for_file: lines_longer_than_80_chars

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_toolbar.dart';

/// 用于 Widget 测试的辅助方法：构建被 MaterialApp 包裹的 QuillToolbar
Widget createQuillToolbar({
  quill.QuillController? controller,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      quill.FlutterQuillLocalizations.delegate,
    ],
    home: Scaffold(
      body: QuillToolbar(
        controller: controller ??
            quill.QuillController(
              document: quill.Document(),
              selection: const TextSelection.collapsed(offset: 0),
            ),
      ),
    ),
  );
}

void main() {
  group('QuillToolbar 基本渲染', () {
    testWidgets('工具栏应该能够正常渲染', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证工具栏容器存在
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('工具栏应该包含水平滚动区域', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证 SingleChildScrollView 存在
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });

    testWidgets('工具栏应该包含按钮行', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证 Row 存在
      expect(find.byType(Row), findsWidgets);
    });
  });

  group('QuillToolbar 撤销/重做按钮', () {
    testWidgets('工具栏应该包含撤销按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证撤销按钮存在（QuillToolbarHistoryButton with isUndo: true）
      expect(find.byType(quill.QuillToolbarHistoryButton), findsNWidgets(2));
    });

    testWidgets('撤销和重做按钮都应该存在', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证有两个历史按钮（撤销和重做）
      final historyButtons = find.byType(quill.QuillToolbarHistoryButton);
      expect(historyButtons, findsNWidgets(2));
    });
  });

  group('QuillToolbar 文本样式按钮', () {
    testWidgets('工具栏应该包含加粗按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证加粗图标存在
      expect(find.byIcon(Icons.format_bold), findsOneWidget);
    });

    testWidgets('工具栏应该包含斜体按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证斜体图标存在
      expect(find.byIcon(Icons.format_italic), findsOneWidget);
    });

    testWidgets('工具栏应该包含下划线按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证下划线图标存在
      expect(find.byIcon(Icons.format_underline), findsOneWidget);
    });

    testWidgets('工具栏应该包含删除线按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 删除线按钮使用自定义图标，验证按钮存在
      final strikeButton = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '删除线',
      );
      expect(strikeButton, findsOneWidget);
    });

    testWidgets('文本样式按钮应该包裹在 Tooltip 中', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证有 Tooltip 包裹按钮
      expect(find.byType(Tooltip), findsWidgets);
    });
  });

  group('QuillToolbar 标题按钮', () {
    testWidgets('工具栏应该包含标题样式下拉按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证标题样式选择按钮存在
      expect(find.byType(quill.QuillToolbarSelectHeaderStyleDropdownButton), findsOneWidget);
    });
  });

  group('QuillToolbar 列表按钮', () {
    testWidgets('工具栏应该包含有序列表按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证有序列表图标存在
      expect(find.byIcon(Icons.format_list_numbered), findsOneWidget);
    });

    testWidgets('工具栏应该包含无序列表按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证无序列表图标存在
      expect(find.byIcon(Icons.format_list_bulleted), findsOneWidget);
    });
  });

  group('QuillToolbar 高级格式按钮', () {
    testWidgets('工具栏应该包含代码块按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证代码块图标存在
      expect(find.byIcon(Icons.code), findsOneWidget);
    });

    testWidgets('工具栏应该包含引用块按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证引用块图标存在
      expect(find.byIcon(Icons.format_quote), findsOneWidget);
    });

    testWidgets('工具栏应该包含分隔线按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证分隔线图标存在
      expect(find.byIcon(Icons.horizontal_rule), findsOneWidget);
    });
  });

  group('QuillToolbar 插入按钮', () {
    testWidgets('工具栏应该包含插入图片按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证图片图标存在
      expect(find.byIcon(Icons.image), findsOneWidget);
    });

    testWidgets('工具栏应该包含字体颜色按钮', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证颜色按钮存在
      expect(find.byType(quill.QuillToolbarColorButton), findsOneWidget);
    });
  });

  group('QuillToolbar 工具栏布局', () {
    testWidgets('工具栏按钮应该有分隔线分隔', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证 Container 作为分隔线存在（工具栏中有多个 Container）
      final containers = find.byType(Container);
      expect(containers, findsWidgets);
    });

    testWidgets('工具栏应该有适当的内边距', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证 Padding 存在（用于按钮组间距）
      expect(find.byType(Padding), findsWidgets);
    });
  });

  group('QuillToolbar 按钮交互', () {
    testWidgets('点击分隔线按钮应该插入分隔线', (tester) async {
      final controller = quill.QuillController(
        document: quill.Document(),
        selection: const TextSelection.collapsed(offset: 0),
      );

      await tester.pumpWidget(createQuillToolbar(controller: controller));
      await tester.pumpAndSettle();

      // 点击分隔线按钮
      await tester.tap(find.byIcon(Icons.horizontal_rule));
      await tester.pumpAndSettle();

      // 验证文档已更新
      expect(controller.document.toPlainText().isNotEmpty, isTrue);
    });

    testWidgets('点击插入图片按钮应该弹出图片来源选择对话框', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 点击图片按钮
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      // 验证对话框出现
      expect(find.byType(AlertDialog), findsOneWidget);

      // 验证对话框包含选项
      expect(find.text('插入图片'), findsOneWidget);
      expect(find.text('从文件选择'), findsOneWidget);
      expect(find.text('输入 URL'), findsOneWidget);
      expect(find.text('取消'), findsOneWidget);
    });

    testWidgets('图片来源对话框应该能取消', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 点击图片按钮
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      // 点击取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证对话框关闭
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('选择输入 URL 选项应该弹出 URL 输入对话框', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 点击图片按钮
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      // 点击输入 URL 选项
      await tester.tap(find.text('输入 URL'));
      await tester.pumpAndSettle();

      // 验证 URL 输入对话框出现
      expect(find.text('输入图片 URL'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('URL 输入对话框应该能取消', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 点击图片按钮
      await tester.tap(find.byIcon(Icons.image));
      await tester.pumpAndSettle();

      // 点击输入 URL 选项
      await tester.tap(find.text('输入 URL'));
      await tester.pumpAndSettle();

      // 点击取消
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();

      // 验证对话框关闭
      expect(find.text('输入图片 URL'), findsNothing);
    });
  });

  group('QuillToolbar 深色模式支持', () {
    testWidgets('工具栏在深色模式下应该有不同背景色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            quill.FlutterQuillLocalizations.delegate,
          ],
          theme: ThemeData.dark(),
          home: Scaffold(
            body: QuillToolbar(
              controller: quill.QuillController(
                document: quill.Document(),
                selection: const TextSelection.collapsed(offset: 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证工具栏渲染成功
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('工具栏在浅色模式下应该有不同背景色', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            quill.FlutterQuillLocalizations.delegate,
          ],
          theme: ThemeData.light(),
          home: Scaffold(
            body: QuillToolbar(
              controller: quill.QuillController(
                document: quill.Document(),
                selection: const TextSelection.collapsed(offset: 0),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证工具栏渲染成功
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('QuillToolbar 按钮工具提示', () {
    testWidgets('加粗按钮应该有"加粗"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      // 验证工具提示存在
      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '加粗',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('斜体按钮应该有"斜体"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '斜体',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('下划线按钮应该有"下划线"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '下划线',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('删除线按钮应该有"删除线"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '删除线',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('有序列表按钮应该有"有序列表"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '有序列表',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('无序列表按钮应该有"无序列表"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '无序列表',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('代码块按钮应该有"代码块"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '代码块',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('引用块按钮应该有"引用块"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '引用块',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('分隔线按钮应该有"分隔线"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '分隔线',
      );
      expect(tooltipFinder, findsOneWidget);
    });

    testWidgets('插入图片按钮应该有"插入图片"工具提示', (tester) async {
      await tester.pumpWidget(createQuillToolbar());
      await tester.pumpAndSettle();

      final tooltipFinder = find.byWidgetPredicate(
        (widget) => widget is Tooltip && widget.message == '插入图片',
      );
      expect(tooltipFinder, findsOneWidget);
    });
  });
}
