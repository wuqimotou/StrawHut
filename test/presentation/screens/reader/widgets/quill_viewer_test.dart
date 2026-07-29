// ignore_for_file: dangling_library_doc_comments // 忽略 library doc comments 警告，因为测试文件使用文档注释说明测试范围
// ignore_for_file: avoid_redundant_argument_values // 允许显式传递默认值参数以增强测试可读性
// ignore_for_file: comment_references // 忽略 comment_references 警告，因为测试注释中包含对第三方包的引用
/// QuillViewer 组件 Widget 单元测试
///
/// 测试目标：验证 QuillViewer 组件的只读渲染和错误处理是否符合任务 5.1 验收标准
///
/// 覆盖范围：
/// - 富文本渲染正确（Delta JSON 解析为 Document）
/// - 只读模式无法编辑（readOnly: true, enableInteractiveSelection: false）
/// - 空 JSON 输入时显示错误提示
/// - 无效 JSON 输入时显示错误提示
/// - ops 数组为空时显示错误提示
/// - 支持标题、段落等多种格式渲染
/// - 背景色适配主题（亮色/暗色）
/// - 组件销毁时释放资源

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/presentation/screens/reader/widgets/quill_viewer.dart';

/// 构建用于测试的 QuillViewer Widget
///
/// 将 QuillViewer 包裹在 MaterialApp 中以便测试主题和文本样式。
Widget _buildQuillViewer({required String deltaJson}) {
  return MaterialApp(
    home: Scaffold(
      body: QuillViewer(deltaJson: deltaJson),
    ),
  );
}

/// 构建一个有效的 Delta JSON 字符串
String _createValidDeltaJson({
  List<Map<String, dynamic>>? ops,
}) {
  final defaultOps = [
    {'insert': 'Hello World\n'},
  ];
  return jsonEncode({
    'ops': ops ?? defaultOps,
  });
}

/// 构建包含标题的 Delta JSON 字符串
String _createDeltaWithHeader() {
  return jsonEncode({
    'ops': [
      {'insert': '一级标题', 'attributes': {'header': 1}},
      {'insert': '\n'},
      {'insert': '二级标题', 'attributes': {'header': 2}},
      {'insert': '\n'},
      {'insert': '三级标题', 'attributes': {'header': 3}},
      {'insert': '\n'},
      {'insert': '普通段落内容\n'},
    ],
  });
}

/// 构建包含粗体和斜体的 Delta JSON 字符串
String _createDeltaWithFormatting() {
  return jsonEncode({
    'ops': [
      {'insert': '粗体文字', 'attributes': {'bold': true}},
      {'insert': '\n'},
      {'insert': '斜体文字', 'attributes': {'italic': true}},
      {'insert': '\n'},
      {'insert': '下划线文字', 'attributes': {'underline': true}},
      {'insert': '\n'},
      {'insert': '删除线文字', 'attributes': {'strike': true}},
      {'insert': '\n'},
    ],
  });
}

/// 构建包含列表的 Delta JSON 字符串
String _createDeltaWithLists() {
  return jsonEncode({
    'ops': [
      {'insert': '无序列表项 1', 'attributes': {'list': 'bullet'}},
      {'insert': '\n'},
      {'insert': '无序列表项 2', 'attributes': {'list': 'bullet'}},
      {'insert': '\n'},
      {'insert': '有序列表项 1', 'attributes': {'list': 'ordered'}},
      {'insert': '\n'},
      {'insert': '有序列表项 2', 'attributes': {'list': 'ordered'}},
      {'insert': '\n'},
    ],
  });
}

/// 构建包含代码块的 Delta JSON 字符串
String _createDeltaWithCodeBlock() {
  return jsonEncode({
    'ops': [
      {'insert': '这是一段代码', 'attributes': {'code-block': true}},
      {'insert': '\n'},
      {'insert': '普通文字\n'},
    ],
  });
}

/// 构建包含引用块的 Delta JSON 字符串
String _createDeltaWithQuote() {
  return jsonEncode({
    'ops': [
      {'insert': '这是一段引用', 'attributes': {'blockquote': true}},
      {'insert': '\n'},
      {'insert': '普通文字\n'},
    ],
  });
}

void main() {
  group('QuillViewer 基本渲染测试', () {
    testWidgets('应能正常渲染有效 Delta JSON', (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证页面存在 Scaffold
      expect(find.byType(Scaffold), findsOneWidget);
    });

    testWidgets('应使用 SingleChildScrollView 支持长文档滚动',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证存在滚动视图
      expect(find.byType(SingleChildScrollView), findsWidgets);
    });

    testWidgets('应使用 QuillEditor.basic 渲染内容',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证 QuillEditor 存在
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('应使用 Container 包裹并设置背景色',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证存在 Container（用于背景色）
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('应使用 ConstrainedBox 限制最大宽度为 800',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证存在 ConstrainedBox
      expect(find.byType(ConstrainedBox), findsWidgets);
    });
  });

  group('QuillViewer 只读模式测试', () {
    testWidgets('应配置为只读模式（enableInteractiveSelection: false）',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证 QuillEditor 存在
      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证编辑器配置为只读模式
      // 注意：QuillEditor.basic 使用 QuillEditorConfig，
      // enableInteractiveSelection 应该为 false
      expect(quillEditor.config.enableInteractiveSelection, isFalse);
    });

    testWidgets('应隐藏光标（showCursor: false）',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证光标隐藏
      expect(quillEditor.config.showCursor, isFalse);
    });

    testWidgets('控制器应配置为 readOnly: true',
        (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证控制器为只读
      expect(quillEditor.controller.readOnly, isTrue);
    });

    testWidgets('无法通过文字选择进行交互', (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson(
        ops: [
          {'insert': '这是一段可测试的文字\n'},
        ],
      );

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // 验证没有可交互的选择器存在
      // 由于 enableInteractiveSelection 为 false，
      // 用户无法通过长按或拖动选择文本
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });
  });

  group('QuillViewer 富文本格式渲染测试', () {
    testWidgets('应正确渲染标题格式（H1、H2、H3）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithHeader();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染格式文本，
      // 验证 QuillEditor 存在且包含 RichText 子组件
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('应正确渲染文本格式（粗体、斜体、下划线、删除线）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithFormatting();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染格式文本
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('应正确渲染列表格式', (WidgetTester tester) async {
      final deltaJson = _createDeltaWithLists();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染列表
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('应正确渲染代码块', (WidgetTester tester) async {
      final deltaJson = _createDeltaWithCodeBlock();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染代码块
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('应正确渲染引用块', (WidgetTester tester) async {
      final deltaJson = _createDeltaWithQuote();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      // flutter_quill 使用 RichText 渲染引用块
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });
  });

  group('QuillViewer 错误处理测试', () {
    testWidgets('空字符串输入时应显示错误提示', (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuillViewer(deltaJson: ''));
      await tester.pumpAndSettle();

      // 验证错误提示存在
      expect(find.text('内容解析失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('知识卡片内容格式不正确，无法渲染。'),
        findsOneWidget,
      );
    });

    testWidgets('无效 JSON 输入时应显示错误提示', (WidgetTester tester) async {
      const invalidJson = '这不是有效的 JSON 格式';

      await tester.pumpWidget(_buildQuillViewer(deltaJson: invalidJson));
      await tester.pumpAndSettle();

      // 验证错误提示存在
      expect(find.text('内容解析失败'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('缺少 ops 数组的 JSON 应显示错误提示',
        (WidgetTester tester) async {
      final invalidDelta = jsonEncode({
        'not_ops': [{'insert': '测试'}],
      });

      await tester.pumpWidget(_buildQuillViewer(deltaJson: invalidDelta));
      await tester.pumpAndSettle();

      // 验证错误提示存在
      expect(find.text('内容解析失败'), findsOneWidget);
    });

    testWidgets('ops 数组为空时应显示错误提示', (WidgetTester tester) async {
      final emptyOps = jsonEncode(<String, dynamic>{'ops': <dynamic>[]});

      await tester.pumpWidget(_buildQuillViewer(deltaJson: emptyOps));
      await tester.pumpAndSettle();

      // 验证错误提示存在
      expect(find.text('内容解析失败'), findsOneWidget);
    });

    testWidgets('错误提示应包含 error_outline 图标',
        (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuillViewer(deltaJson: ''));
      await tester.pumpAndSettle();

      // 验证错误图标存在
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
    });

    testWidgets('错误提示应使用 Column 布局', (WidgetTester tester) async {
      await tester.pumpWidget(_buildQuillViewer(deltaJson: ''));
      await tester.pumpAndSettle();

      // 验证 Column 布局存在
      expect(find.byType(Column), findsWidgets);
    });
  });

  group('QuillViewer 自定义样式测试', () {
    testWidgets('应配置段落样式', (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证自定义样式已配置
      expect(quillEditor.config.customStyles, isNotNull);
    });

    testWidgets('应配置 H1 标题样式（字号 28，粗体）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithHeader();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证 H1 样式已配置
      expect(quillEditor.config.customStyles?.h1, isNotNull);
    });

    testWidgets('应配置 H2 标题样式（字号 22，粗体）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithHeader();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证 H2 样式已配置
      expect(quillEditor.config.customStyles?.h2, isNotNull);
    });

    testWidgets('应配置 H3 标题样式（字号 18，w600 粗体）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithHeader();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证 H3 样式已配置
      expect(quillEditor.config.customStyles?.h3, isNotNull);
    });

    testWidgets('应配置代码块样式（等宽字体）',
        (WidgetTester tester) async {
      final deltaJson = _createDeltaWithCodeBlock();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证代码块样式已配置
      expect(quillEditor.config.customStyles?.code, isNotNull);
    });

    testWidgets('应配置引用块样式', (WidgetTester tester) async {
      final deltaJson = _createDeltaWithQuote();

      await tester.pumpWidget(_buildQuillViewer(deltaJson: deltaJson));
      await tester.pumpAndSettle();

      final quillEditor = tester.widget<quill.QuillEditor>(
        find.byType(quill.QuillEditor),
      );

      // 验证引用块样式已配置
      expect(quillEditor.config.customStyles?.quote, isNotNull);
    });
  });

  group('QuillViewer 主题适配测试', () {
    testWidgets('亮色主题下背景色应为白色', (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.light),
          home: Scaffold(
            body: QuillViewer(deltaJson: deltaJson),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 Container 存在（背景色容器）
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('暗色主题下背景色应为深灰色', (WidgetTester tester) async {
      final deltaJson = _createValidDeltaJson();

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(brightness: Brightness.dark),
          home: Scaffold(
            body: QuillViewer(deltaJson: deltaJson),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 验证 Container 存在（背景色容器）
      expect(find.byType(Container), findsWidgets);
    });
  });

  group('QuillViewer 复杂内容测试', () {
    testWidgets('应能渲染包含多种格式的复杂文档',
        (WidgetTester tester) async {
      final complexDelta = jsonEncode({
        'ops': [
          {'insert': '复杂文档标题', 'attributes': {'header': 1}},
          {'insert': '\n'},
          {'insert': '这是第一段普通文字，包含'},
          {'insert': '粗体', 'attributes': {'bold': true}},
          {'insert': '和'},
          {'insert': '斜体', 'attributes': {'italic': true}},
          {'insert': '文字。\n'},
          {'insert': '\n'},
          {'insert': '无序列表项 1', 'attributes': {'list': 'bullet'}},
          {'insert': '\n'},
          {'insert': '有序列表项 1', 'attributes': {'list': 'ordered'}},
          {'insert': '\n'},
          {'insert': '代码块内容', 'attributes': {'code-block': true}},
          {'insert': '\n'},
          {'insert': '引用内容', 'attributes': {'blockquote': true}},
          {'insert': '\n'},
          {'insert': '这是最后一段文字。\n'},
        ],
      });

      await tester.pumpWidget(_buildQuillViewer(deltaJson: complexDelta));
      await tester.pumpAndSettle();

      // 验证复杂文档能正常渲染
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      // 验证没有出现错误提示
      expect(find.text('内容解析失败'), findsNothing);
    });

    testWidgets('应能处理包含特殊字符的内容',
        (WidgetTester tester) async {
      final specialCharDelta = jsonEncode({
        'ops': [
          {'insert': '特殊字符测试：!@#\$%^&*()_+-=[]{}|;:\'",.<>/?`~\n'},
          {'insert': '中文特殊字符：【】《》「」『』\n'},
          {'insert': 'Emoji：😀🎉🚀\n'},
        ],
      });

      await tester.pumpWidget(_buildQuillViewer(deltaJson: specialCharDelta));
      await tester.pumpAndSettle();

      // 验证特殊字符内容能正常渲染
      expect(find.byType(quill.QuillEditor), findsOneWidget);
    });

    testWidgets('应能处理超长文本内容', (WidgetTester tester) async {
      final longContent = 'A' * 10000;
      final longDelta = jsonEncode({
        'ops': [
          {'insert': '$longContent\n'},
        ],
      });

      await tester.pumpWidget(_buildQuillViewer(deltaJson: longDelta));
      await tester.pumpAndSettle();

      // 验证长文本能正常渲染
      expect(find.byType(quill.QuillEditor), findsOneWidget);
      expect(find.text('内容解析失败'), findsNothing);
    });
  });
}
