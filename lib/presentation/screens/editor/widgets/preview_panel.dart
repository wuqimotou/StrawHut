import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';

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
    } catch (e) {
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
              enableInteractiveSelection: false,
              padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 0),
              showCursor: false,
              maxContentWidth: 800,
              customStyles: quill.DefaultStyles(
                paragraph: quill.DefaultTextBlockStyle(
                  theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(8, 8),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                h1: quill.DefaultTextBlockStyle(
                  theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 28,
                      ) ??
                      const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(16, 8),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                h2: quill.DefaultTextBlockStyle(
                  theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 22,
                      ) ??
                      const TextStyle(
                          fontSize: 22, fontWeight: FontWeight.bold),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(12, 6),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                h3: quill.DefaultTextBlockStyle(
                  theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ) ??
                      const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w600),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(10, 4),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                lists: quill.DefaultListBlockStyle(
                  theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(4, 4),
                  const quill.VerticalSpacing(0, 0),
                  null,
                  null,
                ),
                quote: quill.DefaultTextBlockStyle(
                  theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
                      ) ??
                      const TextStyle(fontSize: 14),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(8, 8),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                code: quill.DefaultTextBlockStyle(
                  TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: isDark ? Colors.green[300] : Colors.green[800],
                  ),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(8, 8),
                  const quill.VerticalSpacing(0, 0),
                  BoxDecoration(
                    color: isDark ? Colors.grey[800] : Colors.grey[100],
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                sizeSmall: const TextStyle(fontSize: 12),
                sizeLarge: const TextStyle(fontSize: 18),
                sizeHuge: const TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
