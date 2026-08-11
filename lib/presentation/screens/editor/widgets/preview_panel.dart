import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_editor.dart';
import 'package:strawhut/presentation/widgets/quill_content_styles.dart';

/// 预览面板组件
///
/// 使用只读 QuillEditor 渲染当前编辑内容，提供编辑/预览模式切换功能。
///
/// 架构位置：应用层（Presentation Layer） -> 编辑器子组件
/// 使用场景：EditorScreen 中切换到预览模式时显示
///
/// 核心功能：
/// - 将当前 Delta JSON 解析为 Document 对象
/// - 使用 QuillEditor 只读模式渲染（readOnly: true）
/// - 不显示工具栏，纯内容展示
/// - 支持滚动长内容
///
/// 使用场景：
/// 1. 用户在编辑器中点击"预览"按钮
/// 2. EditorScreen 切换显示 PreviewPanel 替代 QuillEditor
/// 3. 预览内容 -> 点击"返回编辑"切回编辑器
class PreviewPanel extends ConsumerStatefulWidget {
  const PreviewPanel({super.key});

  @override
  ConsumerState<PreviewPanel> createState() => _PreviewPanelState();
}

class _PreviewPanelState extends ConsumerState<PreviewPanel> {
  quill.QuillController? _controller;
  String? _lastContent;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  quill.QuillController _getOrCreateController(String contentJson) {
    if (_controller == null || _lastContent != contentJson) {
      _controller?.dispose();
      _controller = quill.QuillController(
        document: _parseDocument(contentJson),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      _lastContent = contentJson;
    }
    return _controller!;
  }

  quill.Document _parseDocument(String contentJson) {
    if (contentJson.isEmpty) {
      return quill.Document();
    }

    try {
      final data = jsonDecode(contentJson);

      List<dynamic>? ops;
      if (data is Map<String, dynamic>) {
        ops = data['ops'] as List<dynamic>?;
      } else if (data is List<dynamic>) {
        ops = data;
      }

      if (ops == null || ops.isEmpty) {
        return quill.Document();
      }
      return quill.Document.fromJson(ops);
    } on Object catch (e) {
      debugPrint('预览面板：Delta JSON 解析失败：$e');
      return quill.Document();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contentJson = ref.watch(editorContentProvider);
    final controller = _getOrCreateController(contentJson);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              // 嵌入内容构建器（图片、视频、分隔线等）
              embedBuilders: [
                ...FlutterQuillEmbeds.editorBuilders(),
                const HorizontalRuleEmbedBuilder(),
              ],
              enableInteractiveSelection: false,
              showCursor: false,
              maxContentWidth: 800,
              customStyles: buildQuillContentStyles(theme),
            ),
          ),
        ),
      ),
    );
  }
}
