import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/publish_dialog.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';
import 'package:strawhut/presentation/providers/picked_file_provider.dart';
import 'package:strawhut/presentation/screens/editor/widgets/preview_panel.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_editor.dart';
import 'package:strawhut/presentation/screens/editor/widgets/quill_toolbar.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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

class _EditorScreenState extends ConsumerState<EditorScreen>
    with WidgetsBindingObserver {
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
    WidgetsBinding.instance.addObserver(this);
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
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // App going to background
      if (_hasActualContent()) {
        // Show a brief reminder message before the app goes to background
        _showBackgroundWarning();
      }
    } else if (state == AppLifecycleState.resumed) {
      // App came back to foreground - check if draft still exists
      _checkDraftOnResume();
    }
  }

  /// Show a brief warning when app enters background with unsaved content.
  ///
  /// Uses a SnackBar to notify the user that their content is in memory only.
  void _showBackgroundWarning() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final tokens = NeumorphicTokens.ofContext(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            '内容仅保存在内存中，应用关闭后将丢失',
            style: TextStyle(fontSize: 14),
          ),
          backgroundColor: tokens.warning,
          duration: const Duration(seconds: 2),
        ),
      );
    });
  }

  /// Check draft status when app resumes from background.
  ///
  /// If draft exists but editor appears empty, show an option to restore.
  void _checkDraftOnResume() {
    if (!mounted) return;

    final draftManager = ref.read(draftManagerProvider);
    final hasDraft = draftManager.hasDraft();
    final hasContent = _hasActualContent();

    if (hasDraft && !hasContent) {
      // Draft exists but editor is empty - offer to restore
      _showDraftRestoreDialog();
    }
  }

  /// Show dialog to restore draft if it exists but editor is empty.
  void _showDraftRestoreDialog() {
    final tokens = NeumorphicTokens.ofContext(context);
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '发现草稿',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '检测到上次编辑的草稿内容，是否恢复？',
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: '新建文档',
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  const SizedBox(width: 12),
                  NeumorphicButton(
                    label: '恢复',
                    style: NeumorphicButtonStyle.primary,
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                      ref.read(editorContentProvider.notifier).loadFromDraft();
                      final content = ref.read(editorContentProvider);
                      if (content.isNotEmpty) {
                        try {
                          final doc = quill.Document.fromJson(
                            jsonDecode(content) as List,
                          );
                          _quillController.document = doc;
                        } on Object catch (e) {
                          debugPrint('Failed to restore draft: $e');
                        }
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建编辑器页面
  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return PopScope(
      canPop: !_hasActualContent(),
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        if (!_hasActualContent()) {
          if (context.canPop()) {
            context.pop();
          } else {
            context.go('/');
          }
        } else {
          _showExitConfirmationDialog();
        }
      },
      child: Scaffold(
        backgroundColor: tokens.surface,
        appBar: _buildAppBar(context, tokens),
        resizeToAvoidBottomInset: true,
        body: _isPreviewMode
            ? const PreviewPanel()
            : Column(
                children: [
                  QuillToolbar(controller: _quillController),
                  Expanded(
                    child: QuillEditor(
                      key: _quillEditorKey,
                      controller: _quillController,
                    ),
                  ),
                ],
              ),
        bottomNavigationBar: _buildBottomBar(context, tokens),
      ),
    );
  }

  /// 构建软质浮动 AppBar
  PreferredSize _buildAppBar(BuildContext context, NeumorphicTokens tokens) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 8),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(
            children: [
              NeumorphicIconButton(
                icon: StrawIcons.arrowBack,
                tooltip: '返回',
                onPressed: () => _handleBack(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _isPreviewMode ? '预览模式' : '编辑知识卡片',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              NeumorphicIconButton(
                icon: StrawIcons.publish,
                tooltip: '发布',
                color: tokens.inkPrimary,
                onPressed: () => _handlePublish(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建软质底部操作栏
  Widget _buildBottomBar(BuildContext context, NeumorphicTokens tokens) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            NeumorphicButton(
              label: _isPreviewMode ? '返回编辑' : '预览',
              icon: _isPreviewMode ? StrawIcons.editNote : StrawIcons.eye,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              minimumSize: const Size(48, 48),
              onPressed: _toggleMode,
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
    if (_hasActualContent()) {
      _showExitConfirmationDialog();
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/');
      }
    }
  }

  /// 显示退出确认对话框
  void _showExitConfirmationDialog() {
    final tokens = NeumorphicTokens.ofContext(context);
    showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '确认离开？',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '您有未保存的内容，确定要离开吗？',
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: '取消',
                    onPressed: () => Navigator.pop(dialogContext, false),
                  ),
                  const SizedBox(width: 12),
                  NeumorphicButton(
                    label: '离开',
                    style: NeumorphicButtonStyle.primary,
                    onPressed: () {
                      Navigator.pop(dialogContext, true);
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/');
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 处理发布操作
  ///
  /// 先检查编辑器是否为空，非空才弹出 PublishDialog。
  /// 发布成功后清空编辑器内容。
  Future<void> _handlePublish(BuildContext context) async {
    // 先检查编辑器是否有实际内容
    if (!_hasActualContent()) {
      if (!context.mounted) return;
      final tokens = NeumorphicTokens.ofContext(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('编辑器内容为空，无法发布'),
          backgroundColor: tokens.warning,
        ),
      );
      return;
    }

    // 在弹出对话框前，立即刷新草稿，确保防抖等待中的内容被保存
    _quillEditorKey.currentState?.flushDraft();
    await PublishDialog.show(context, initialMode: ContentSourceMode.editor);
    // 发布对话框关闭后，如果内容已被清空（说明发布成功），同步清空编辑器
    final content = ref.read(editorContentProvider);
    if (content.isEmpty) {
      _quillController.clear();
    }
  }

  /// 检查编辑器是否有实际内容（非空白文档）
  ///
  /// 通过 QuillController 的 document.toPlainText() 提取纯文本，
  /// trim() 后如果为空，视为空白文档。
  bool _hasActualContent() {
    final document = _quillController.document;
    final plainText = document.toPlainText().trim();
    return plainText.isNotEmpty;
  }
}
