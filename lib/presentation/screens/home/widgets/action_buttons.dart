import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/publish_dialog.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/picked_file_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 首页操作按钮组件
///
/// 显示首页的核心操作按钮组，包括：
/// - "新建知识卡片" 按钮：导航到 EditorScreen
/// - "打开知识卡片" 按钮：触发文件选择器，选择 .straw 文件后导航到 ReaderScreen
///
/// 架构位置：应用层（Presentation Layer）→ 首页子组件
/// 使用场景：HomeScreen 的 body 中使用
///
/// 按钮交互流程：
/// 1. 点击"新建知识卡片" → go_router 导航到 /editor
/// 2. 点击"打开知识卡片" → 调用 FilePicker 选择文件
///    → 验证文件扩展名为 .straw
///    → go_router 导航到 /reader?path=xxx
class ActionButtons extends ConsumerWidget {
  /// 创建操作按钮组件实例
  const ActionButtons({super.key});

  /// 构建按钮 UI
  ///
  /// 布局结构：
  /// - Column 布局，垂直排列两个按钮
  /// - 使用 ElevatedButton 样式，带有图标和文字
  /// - 按钮之间有足够的间距
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final minHeight = isMobile ? 56.0 : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "发布知识卡片"：主 CTA（墨色填充）
        NeumorphicButton(
          label: '发布知识卡片',
          icon: StrawIcons.plusCircle,
          style: NeumorphicButtonStyle.primary,
          expanded: true,
          minimumSize: Size(double.infinity, minHeight),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          onPressed: () => _onCreateNewCard(context),
        ),
        const SizedBox(height: 16),
        // "解密知识卡片"：次级 CTA（软质凸起）
        NeumorphicButton(
          label: '解密知识卡片',
          icon: StrawIcons.folderOpen,
          expanded: true,
          minimumSize: Size(double.infinity, minHeight),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          onPressed: () => _onOpenCard(context, ref),
        ),
      ],
    );
  }

  /// 处理"发布知识卡片"按钮点击事件
  ///
  /// 弹出选择对话框，让用户选择内容来源：
  /// - "富文本编辑"：进入编辑器，编辑后发布
  /// - "直接加密文件"：跳过编辑器，直接打开发布对话框
  void _onCreateNewCard(BuildContext context) {
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);

    if (isMobile) {
      _showCreateOptionsMobile(context);
    } else {
      _showCreateOptionsDesktop(context);
    }
  }

  /// 桌面端：弹出软质选择对话框
  ///
  /// 约束：两个选项 UI 权重一致（都用 secondary 软质按钮），
  /// 垂直排列在底部，宽度增加。
  void _showCreateOptionsDesktop(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return Dialog(
          backgroundColor: tokens.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusXLarge),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '发布知识卡片',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '请选择内容来源：',
                    style: TextStyle(
                      fontSize: 14,
                      color: tokens.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  // 选项一：富文本编辑（权重一致）
                  NeumorphicButton(
                    label: '富文本编辑',
                    icon: StrawIcons.editNote,
                    expanded: true,
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      context.go('/editor');
                    },
                  ),
                  const SizedBox(height: 12),
                  // 选项二：直接加密文件（权重一致）
                  NeumorphicButton(
                    label: '直接加密文件',
                    icon: StrawIcons.uploadFile,
                    expanded: true,
                    minimumSize: const Size(double.infinity, 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      PublishDialog.show(
                        context,
                        initialMode: ContentSourceMode.fileUpload,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// 移动端：弹出底部软质选择框
  ///
  /// 约束：两个 ListTile 权重一致，垂直排列。
  void _showCreateOptionsMobile(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusXLarge),
        ),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: NeumorphicIcon(
                    StrawIcons.editNote,
                    color: tokens.textPrimary,
                  ),
                  title: const Text('富文本编辑'),
                  subtitle: const Text('在编辑器中创作内容后发布'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.go('/editor');
                  },
                ),
                ListTile(
                  leading: NeumorphicIcon(
                    StrawIcons.uploadFile,
                    color: tokens.textPrimary,
                  ),
                  title: const Text('直接加密文件'),
                  subtitle: const Text('选择文件直接加密，无需编辑'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    PublishDialog.show(
                      context,
                      initialMode: ContentSourceMode.fileUpload,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 处理"打开知识卡片"按钮点击事件
  ///
  /// Android: 弹出底部选择框，支持"从相册加载(.png)"和"从文件系统加载(.straw/.png)"
  /// Desktop: 直接调用文件选择器
  ///
  /// 流程：
  /// 1. 用户点击按钮
  /// 2. Android 弹出底部选择框，Desktop 直接选择文件
  /// 3. 选择 .straw 或 .png 文件
  /// 4. 导航到阅读器页面并传入文件数据
  Future<void> _onOpenCard(BuildContext context, WidgetRef ref) async {
    final isAndroid =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

    if (isAndroid) {
      _showOpenCardOptions(context, ref);
    } else {
      await _doOpenCard(context, ref);
    }
  }

  /// 在 Android 上弹出文件来源选择软质底部框
  void _showOpenCardOptions(BuildContext context, WidgetRef ref) {
    final tokens = NeumorphicTokens.ofContext(context);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(tokens.radiusXLarge),
        ),
      ),
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: NeumorphicIcon(
                    StrawIcons.image,
                    color: tokens.textPrimary,
                  ),
                  title: const Text('从相册加载'),
                  subtitle: const Text('选择 .png 格式的加密知识卡片图片'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _doOpenCardFromGallery(context, ref);
                    });
                  },
                ),
                ListTile(
                  leading: NeumorphicIcon(
                    StrawIcons.folderOpen,
                    color: tokens.textPrimary,
                  ),
                  title: const Text('从文件系统加载'),
                  subtitle: const Text('选择 .straw 或 .png 文件'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      _doOpenCard(context, ref);
                    });
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// 从相册选择 .png 文件（Android 使用 image_picker，Desktop 使用 FilePicker）
  Future<void> _doOpenCardFromGallery(
      BuildContext context, WidgetRef ref,) async {
    Uint8List bytes;
    String fileName;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android: 使用 image_picker 可靠地从相册读取图片
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      bytes = await pickedFile.readAsBytes();
      // Always force .png extension since we know we're picking a PNG
      // knowledge card.
      // image_picker may return filenames like "image_picker_xxx.jpg" or
      // no extension.
      fileName = 'strawhut_card.png';
    } else {
      // Desktop: 使用 FileSelectionService
      final fileSelectionService = ref.read(fileSelectionServiceProvider);
      final result = await fileSelectionService.pickImageFile();
      if (result == null) return;
      bytes = result.$1;
      fileName = result.$2;
    }

    if (context.mounted) {
      ref.read(pendingFileBytesProvider.notifier).state = (bytes, fileName);
      context.go('/reader?path=${Uri.encodeComponent(fileName)}');
    }
  }

  /// 从文件系统选择 .straw 或 .png 文件
  ///
  /// 安卓端使用路径模式（withData: false），避免将大文件加载到内存导致 OOM。
  /// 桌面端仍使用字节模式。
  Future<void> _doOpenCard(BuildContext context, WidgetRef ref) async {
    final fileSelectionService = ref.read(fileSelectionServiceProvider);

    if (fileSelectionService.isAndroid) {
      // 安卓端：使用路径模式，避免将大文件加载到内存
      final filePath = await fileSelectionService.pickStrawOrPngFilePath();
      if (filePath == null) return;
      if (context.mounted) {
        context.go('/reader?path=${Uri.encodeComponent(filePath)}');
      }
    } else {
      // 桌面端：使用字节模式
      final result = await fileSelectionService.pickStrawOrPngFile();
      if (result == null) return;
      final (bytes, fileName) = result;
      if (context.mounted) {
        ref.read(pendingFileBytesProvider.notifier).state = (bytes, fileName);
        context.go('/reader?path=${Uri.encodeComponent(fileName)}');
      }
    }
  }
}
