import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/publish_dialog.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';
import 'package:strawhut/presentation/screens/editor/widgets/preview_panel.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_editor.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_toolbar.dart';

/// 知识卡片编辑器主页面
///
/// 提供完整的富文本编辑体验，包括编辑工具栏、编辑区域、预览切换、发布功能。
///
/// 页面结构：
/// - AppBar：标题 + 返回按钮 + 发布按钮
/// - 主体区域：根据编辑模式切换显示
///   - 编辑模式：QuillToolbar + QuillEditor
///   - 预览模式：PreviewPanel
/// - 底部栏：预览/编辑模式切换按钮
///
/// 架构位置：应用层（Presentation Layer） -> 页面
/// 路由：/editor
/// 状态管理：Riverpod ConsumerStatefulWidget
///
/// 数据流：
/// 1. 页面初始化 -> 创建 QuillController
/// 2. 用户编辑内容 -> QuillEditor 实时更新 EditorContent Provider
/// 3. 用户点击发布 -> 弹出 PublishDialog
/// 4. 用户返回 -> 自动清理资源
class EditorScreen extends ConsumerStatefulWidget {
  /// 创建编辑器页面实例
  const EditorScreen({super.key});

  @override
  ConsumerState<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends ConsumerState<EditorScreen> {
  /// Quill 编辑器控制器，管理编辑器的内容和选区
  late final quill.QuillController _quillController;

  /// QuillEditor 组件的 GlobalKey，用于访问 flushDraft 方法
  final _quillEditorKey = GlobalKey<QuillEditorState>();

  /// 当前是否为预览模式
  bool _isPreviewMode = false;

  /// 防抖定时器，用于延迟保存草稿
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    // 初始化 Quill 控制器，绑定空白文档
    _quillController = quill.QuillController(
      document: quill.Document(),
      selection: const TextSelection.collapsed(offset: 0),
    );
  }

  @override
  void dispose() {
    // 清理定时器，防止内存泄漏
    _debounceTimer?.cancel();
    // 清理 Quill 控制器
    _quillController.dispose();
    super.dispose();
  }

  /// 构建编辑器页面
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar：标题 + 返回按钮 + 发布按钮
      appBar: _buildAppBar(context),
      // 主体区域：根据编辑模式切换
      body: _isPreviewMode
          ? const PreviewPanel()
          : Column(
              children: [
                // 编辑工具栏
                QuillToolbar(controller: _quillController),
                // 编辑器主体，占据剩余空间
                Expanded(
                  child: QuillEditor(
                    key: _quillEditorKey,
                    controller: _quillController,
                  ),
                ),
              ],
            ),
      // 底部操作栏
      bottomNavigationBar: _buildBottomBar(context),
    );
  }

  /// 构建 AppBar
  ///
  /// 包含返回按钮、页面标题、发布按钮。
  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      // 左侧：返回按钮
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => _handleBack(context),
        tooltip: '返回',
      ),
      // 中间：页面标题，根据模式显示不同文本
      title: Text(
        _isPreviewMode ? '预览模式' : '编辑知识卡片',
        style: Theme.of(context).textTheme.titleLarge,
      ),
      // 右侧：发布按钮
      actions: [
        IconButton(
          icon: const Icon(Icons.publish),
          onPressed: () => _handlePublish(context),
          tooltip: '发布',
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  /// 构建底部操作栏
  ///
  /// 包含预览/编辑模式切换按钮。
  Widget _buildBottomBar(BuildContext context) {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor,
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 切换按钮
            OutlinedButton.icon(
              onPressed: _toggleMode,
              icon: Icon(
                _isPreviewMode ? Icons.edit : Icons.visibility,
                size: 20,
              ),
              label: Text(
                _isPreviewMode ? '返回编辑' : '预览',
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 切换编辑/预览模式
  void _toggleMode() {
    setState(() {
      _isPreviewMode = !_isPreviewMode;
    });
  }

  /// 处理返回操作
  ///
  /// 检查是否有未保存内容，弹出确认对话框。
  Future<void> _handleBack(BuildContext context) async {
    final hasContent = _hasActualContent();

    if (hasContent) {
      final shouldPop = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('确认离开？'),
          content: const Text('您有未保存的内容，确定要离开吗？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('离开'),
            ),
          ],
        ),
      );

      if (shouldPop == true && mounted) {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      }
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  /// 处理发布操作
  ///
  /// 弹出 PublishDialog 发布对话框，用户确认后执行发布流程。
  /// 发布成功后清空编辑器内容。
  Future<void> _handlePublish(BuildContext context) async {
    // 在弹出对话框前，立即刷新草稿，确保防抖等待中的内容被保存
    _quillEditorKey.currentState?.flushDraft();
    await PublishDialog.show(context);
    // 发布对话框关闭后，如果内容已被清空（说明发布成功），同步清空编辑器
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) {
      _quillController.clear();
    }
  }

  /// 检查编辑器是否有实际内容（非空白文档）
  ///
  /// Quill 空文档的 Delta JSON 为 [{"insert":"\n"}]，
  /// 需要排除这种情况，只有用户实际输入了内容才返回 true。
  bool _hasActualContent() {
    final document = _quillController.document;
    final plainText = document.toPlainText().trim();
    return plainText.isNotEmpty;
  }
}
