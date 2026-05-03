import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_quill_extensions/flutter_quill_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';

/// Quill 富文本编辑器组件
///
/// 封装 flutter_quill 的 QuillEditor，作为 StrawHut 的核心编辑区域。
///
/// 架构位置：应用层（Presentation Layer） -> 编辑器子组件
/// 使用场景：EditorScreen 的主体区域
///
/// 核心功能：
/// - 绑定 QuillController 进行内容管理
/// - 监听内容变化 -> 更新 EditorContent Provider
/// - 自动保存到内存草稿（DraftManager）
/// - 支持撤销/重做
///
/// 数据流：
/// 1. 用户输入文本 -> QuillEditor.onChanged 触发
/// 2. 获取当前 Delta 对象 -> 序列化为 JSON
/// 3. 调用 EditorProvider.updateContent 更新状态
/// 4. EditorProvider 调用 DraftManager.saveToDraft 保存草稿
///
/// 性能要求：
/// - 编辑器响应延迟 < 50ms
/// - 大文档场景下保持流畅
class QuillEditor extends ConsumerStatefulWidget {
  /// 创建 Quill 编辑器组件实例
  ///
  /// 参数 [controller] - 外部传入的 QuillController，与工具栏共享
  const QuillEditor({
    super.key,
    required this.controller,
  });

  /// Quill 编辑器控制器，与工具栏共享同一个实例
  final quill.QuillController controller;

  @override
  QuillEditorState createState() => QuillEditorState();
}

class QuillEditorState extends ConsumerState<QuillEditor> {
  /// 防抖定时器，避免每次输入都立即更新 Provider
  Timer? _debounceTimer;

  /// 立即刷新草稿保存（取消防抖等待，立即更新 Provider）
  void flushDraft() {
    _saveToProvider();
  }

  /// 保存内容到 Provider
  void _saveToProvider() {
    try {
      final deltaJson =
          jsonEncode(widget.controller.document.toDelta().toJson());
      ref.read(editorContentProvider.notifier).updateContent(deltaJson);
    } catch (e) {
      debugPrint('编辑器内容序列化失败：$e');
    }
  }

  /// 构建编辑器 UI
  ///
  /// 使用 QuillEditor.basic 工厂方法创建编辑器实例，
  /// 并绑定控制器和配置参数。
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      // 编辑器容器：带背景色和内边距
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[850] : Colors.white,
      ),
      child: quill.QuillEditor.basic(
        controller: widget.controller,
        config: quill.QuillEditorConfig(
          // 嵌入内容构建器（图片、视频等）
          embedBuilders: FlutterQuillEmbeds.editorBuilders(),
          // 启用交互选择
          enableInteractiveSelection: true,
          // 启用键盘快捷键
          keyboardAppearance: theme.brightness,
          // 滚动配置
          scrollable: true,
          scrollPhysics: const BouncingScrollPhysics(),
          // 占位符提示文本
          placeholder: '开始编写你的知识卡片...',
          // 内容样式配置
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          // 显示光标
          showCursor: true,
          // 最大内容宽度（可选，用于限制阅读宽度）
          maxContentWidth: 800,
          // 最小高度
          minHeight: 400,
          // 自定义样式
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
                  const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
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
                  const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
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
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
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
                    color: theme.textTheme.bodyLarge?.color?.withOpacity(0.7),
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
    );
  }

  /// 从 Provider 加载草稿内容
  ///
  /// 当组件初始化时，检查是否存在草稿，
  /// 如果存在则将草稿内容加载到编辑器控制器中。
  void _loadDraftContent() {
    final draftContent = ref.read(editorContentProvider);
    if (draftContent.isNotEmpty) {
      try {
        final data = jsonDecode(draftContent);

        List<dynamic>? ops;
        if (data is Map<String, dynamic>) {
          ops = data['ops'] as List<dynamic>?;
        } else if (data is List<dynamic>) {
          ops = data;
        }

        if (ops != null && ops.isNotEmpty) {
          final document = quill.Document.fromJson(ops);
          widget.controller.document = document;
        }
      } catch (e) {
        // JSON 解析失败时忽略，使用空白文档
        debugPrint('草稿内容解析失败：$e');
      }
    }
  }

  @override
  void initState() {
    super.initState();

    // 监听内容变化，使用防抖避免频繁更新 Provider
    widget.controller.addListener(_onContentChanged);

    // 延迟加载草稿，避免在 build 阶段修改 controller 导致工具栏 rebuild 报错
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadDraftContent();
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    widget.controller.removeListener(_onContentChanged);
    super.dispose();
  }

  /// 内容变化回调（带防抖）
  ///
  /// 当编辑器内容发生变化时触发，延迟保存 Provider 状态，
  /// 避免频繁更新导致焦点丢失。
  void _onContentChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 300), _saveToProvider);
  }
}
