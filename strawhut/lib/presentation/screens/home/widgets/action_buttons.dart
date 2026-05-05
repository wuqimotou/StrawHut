import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'package:strawhut/core/file_io/file_selection_service.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

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
    // On mobile, buttons need 56dp minimum height for touch targets
    final isMobile = !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS);
    final buttonMinHeight = isMobile ? 56.0 : 48.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "新建知识卡片" 按钮
        // 点击后导航到编辑器页面，用户可以开始创建新的加密知识卡片
        SizedBox(
          height: buttonMinHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              _onCreateNewCard(context);
            },
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('发布知识卡片'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        // "打开知识卡片" 按钮
        // 点击后弹出文件选择器，用户可以选择已有的 .straw 文件进行查看
        SizedBox(
          height: buttonMinHeight,
          child: ElevatedButton.icon(
            onPressed: () {
              _onOpenCard(context, ref);
            },
            icon: const Icon(Icons.folder_open_outlined),
            label: const Text('解密知识卡片'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  /// 处理"新建知识卡片"按钮点击事件
  ///
  /// 使用 go_router 导航到编辑器页面（/editor）。
  ///
  /// 流程：
  /// 1. 用户点击按钮
  /// 2. 调用 context.go('/editor') 进行路由跳转
  /// 3. 用户进入编辑器页面开始创作
  ///
  /// 参数：[context] - BuildContext 用于获取 go_router
  void _onCreateNewCard(BuildContext context) {
    // 使用 go_router 的 go() 方法进行路由跳转
    // go() 会替换当前路由栈中的路由，用户无法返回到首页
    // 这符合预期行为：进入编辑器后不需要返回首页
    context.go('/editor');
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

  /// 在 Android 上弹出文件来源选择对话框
  void _showOpenCardOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('从相册加载'),
                subtitle: const Text('选择 .png 格式的加密知识卡片图片'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  // Use a post-frame callback to ensure the bottom sheet is fully dismissed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _doOpenCardFromGallery(context, ref);
                  });
                },
              ),
              ListTile(
                leading: const Icon(Icons.folder_open),
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
        );
      },
    );
  }

  /// 从相册选择 .png 文件（Android 使用 image_picker，Desktop 使用 FilePicker）
  Future<void> _doOpenCardFromGallery(
      BuildContext context, WidgetRef ref) async {
    Uint8List? bytes;
    String? fileName;

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      // Android: 使用 image_picker 可靠地从相册读取图片
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      bytes = await pickedFile.readAsBytes();
      // Always force .png extension since we know we're picking a PNG knowledge card.
      // image_picker may return filenames like "image_picker_xxx.jpg" or no extension.
      fileName = 'strawhut_card.png';
    } else {
      // Desktop: 使用 FileSelectionService
      final fileSelectionService = ref.read(fileSelectionServiceProvider);
      final result = await fileSelectionService.pickImageFile();
      if (result == null) return;
      bytes = result.$1;
      fileName = result.$2;
    }

    if (bytes == null || fileName == null) return;

    if (context.mounted) {
      ref.read(pendingFileBytesProvider.notifier).state = (bytes, fileName);
      context.go('/reader?path=${Uri.encodeComponent(fileName)}');
    }
  }

  /// 从文件系统选择 .straw 或 .png 文件
  Future<void> _doOpenCard(BuildContext context, WidgetRef ref) async {
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
    final result = await fileSelectionService.pickStrawOrPngFile();

    if (result == null) return;

    final (bytes, fileName) = result;

    if (context.mounted) {
      ref.read(pendingFileBytesProvider.notifier).state = (bytes, fileName);
      context.go('/reader?path=${Uri.encodeComponent(fileName)}');
    }
  }
}
