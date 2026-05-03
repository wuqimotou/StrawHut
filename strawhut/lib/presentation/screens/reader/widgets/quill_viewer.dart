import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';

/// Quill 内容查看器组件
///
/// 使用只读 QuillEditor 渲染解密后的知识内容。
///
/// 架构位置：应用层（Presentation Layer）-> 阅读器子组件
/// 使用场景：ReaderScreen 解密成功后显示，替代 MetaPreview
///
/// 核心功能：
/// - 将 Delta JSON 解析为 Quill Document
/// - 使用 QuillEditor 只读模式渲染（通过 QuillController.readOnly: true）
/// - 不支持任何编辑操作（enableInteractiveSelection: false）
/// - 支持滚动查看长文档
///
/// 数据来源：DecryptDialog 解密后返回的 Delta JSON 字符串
/// 展示时机：解密成功 + 完整性校验通过后
///
/// 使用示例：
/// ```dart
/// QuillViewer(deltaJson: decryptedContent)
/// ```
class QuillViewer extends StatefulWidget {
  /// 创建内容查看器组件实例
  ///
  /// 参数：
  /// - [deltaJson] - 解密后的 Delta JSON 字符串，必填
  const QuillViewer({required this.deltaJson, super.key});

  /// 解密后的 Delta JSON 字符串
  ///
  /// 此字符串是 Quill 编辑器导出的 Delta 格式，
  /// 结构示例：
  /// ```json
  /// {
  ///   "ops": [
  ///     { "insert": "标题\n", "attributes": { "header": 1 } },
  ///     { "insert": "正文内容\n" }
  ///   ]
  /// }
  /// ```
  final String deltaJson;

  @override
  State<QuillViewer> createState() => _QuillViewerState();
}

/// QuillViewer 的状态管理类
///
/// 负责管理只读编辑器的生命周期，
/// 确保在组件销毁时正确释放 QuillController 资源。
class _QuillViewerState extends State<QuillViewer> {
  /// Quill 控制器实例
  quill.QuillController? _controller;

  /// 标记文档解析是否成功
  bool _parseSuccess = true;

  @override
  void initState() {
    super.initState();
    // 初始化时创建只读控制器
    _controller = _createReadOnlyController(widget.deltaJson);
  }

  @override
  void dispose() {
    // 释放控制器资源，防止内存泄漏
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  /// 创建只读的 QuillController
  ///
  /// 将 Delta JSON 字符串解析为 Document 对象，
  /// 并配置为只读模式。
  ///
  /// 参数：[deltaJson] - Delta JSON 字符串
  /// 返回：配置为只读的 QuillController 实例
  quill.QuillController _createReadOnlyController(String deltaJson) {
    final document = _parseDocument(deltaJson);
    return quill.QuillController(
      document: document,
      selection: const TextSelection.collapsed(offset: 0),
      readOnly: true, // 启用只读模式，禁止编辑
    );
  }

  /// 将 Delta JSON 字符串解析为 Document 对象
  ///
  /// 解析流程：
  /// 1. 将 JSON 字符串解码为 Map
  /// 2. 提取 ops 数组（Document.fromJson 需要的是 ops 数组）
  /// 3. 创建 Document 实例
  ///
  /// 参数：[contentJson] - Delta JSON 字符串
  /// 返回：解析后的 Document 对象，解析失败时返回空文档
  quill.Document _parseDocument(String contentJson) {
    if (contentJson.isEmpty) {
      _parseSuccess = false;
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
        _parseSuccess = false;
        return quill.Document();
      }
      _parseSuccess = true;
      return quill.Document.fromJson(ops);
    } on Exception catch (e) {
      debugPrint('QuillViewer：Delta JSON 解析失败：$e');
      _parseSuccess = false;
      return quill.Document();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 检查文档是否有效
    if (!_parseSuccess) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '内容解析失败',
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                '知识卡片内容格式不正确，无法渲染。',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      // 背景色，适配主题
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
      ),
      // 使用 SingleChildScrollView 包裹，支持长文档滚动
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: quill.QuillEditor.basic(
            controller: _controller!,
            config: quill.QuillEditorConfig(
              // 嵌入内容构建器（图片、视频等）
              embedBuilders: FlutterQuillEmbeds.editorBuilders(),
              // 禁用交互选择，确保用户无法选中/复制文本
              enableInteractiveSelection: false,
              // 隐藏光标
              showCursor: false,
              // 内容内边距
              // 最大内容宽度，保证阅读体验
              maxContentWidth: 800,
              // 自定义样式，适配主题
              customStyles: quill.DefaultStyles(
                paragraph: quill.DefaultTextBlockStyle(
                  theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(8, 8),
                  quill.VerticalSpacing.zero,
                  null,
                ),
                h1: quill.DefaultTextBlockStyle(
                  theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ) ??
                      const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(16, 8),
                  quill.VerticalSpacing.zero,
                  null,
                ),
                h2: quill.DefaultTextBlockStyle(
                  theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 22,
                  ) ??
                      const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(12, 6),
                  quill.VerticalSpacing.zero,
                  null,
                ),
                h3: quill.DefaultTextBlockStyle(
                  theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ) ??
                      const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(10, 4),
                  quill.VerticalSpacing.zero,
                  null,
                ),
                lists: quill.DefaultListBlockStyle(
                  theme.textTheme.bodyLarge ?? const TextStyle(fontSize: 16),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(4, 4),
                  quill.VerticalSpacing.zero,
                  null,
                  null,
                ),
                quote: quill.DefaultTextBlockStyle(
                  theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyLarge?.color?.withValues(
                      alpha: 0.7,
                    ),
                  ) ?? const TextStyle(fontSize: 14),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(8, 8),
                  quill.VerticalSpacing.zero,
                  null,
                ),
                code: quill.DefaultTextBlockStyle(
                  TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                    color: isDark ? Colors.green[300] : Colors.green[800],
                  ),
                  quill.HorizontalSpacing.zero,
                  const quill.VerticalSpacing(8, 8),
                  quill.VerticalSpacing.zero,
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
