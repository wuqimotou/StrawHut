import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:strawhut/core/file_io/file_extensions.dart';

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
class ActionButtons extends StatelessWidget {
  /// 创建操作按钮组件实例
  const ActionButtons({super.key});

  /// 构建按钮 UI
  ///
  /// 布局结构：
  /// - Column 布局，垂直排列两个按钮
  /// - 使用 ElevatedButton 样式，带有图标和文字
  /// - 按钮之间有足够的间距
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // "新建知识卡片" 按钮
        // 点击后导航到编辑器页面，用户可以开始创建新的加密知识卡片
        ElevatedButton.icon(
          onPressed: () {
            _onCreateNewCard(context);
          },
          icon: const Icon(Icons.add_circle_outline),
          label: const Text('新建知识卡片'),
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
          ),
        ),
        const SizedBox(height: 16),
        // "打开知识卡片" 按钮
        // 点击后弹出文件选择器，用户可以选择已有的 .straw 文件进行查看
        OutlinedButton.icon(
          onPressed: () {
            _onOpenCard(context);
          },
          icon: const Icon(Icons.folder_open_outlined),
          label: const Text('打开知识卡片'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 16),
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
  /// 使用 file_selector 包弹出文件选择器，过滤 .straw 文件。
  ///
  /// 流程：
  /// 1. 用户点击按钮
  /// 2. 弹出系统文件选择对话框
  /// 3. 用户选择 .straw 文件
  /// 4. 导航到阅读器页面并传入文件路径
  ///
  /// 参数：[context] - BuildContext 用于获取 go_router
  Future<void> _onOpenCard(BuildContext context) async {
    // 定义文件类型过滤器，只允许选择 .straw 文件
    // 使用 XTypeGroup 定义 MIME 类型和扩展名过滤
    // 这确保用户只能看到和选择 StrawHut 知识卡片文件
    const typeGroup = XTypeGroup(
      label: 'StrawHut 知识卡片',
      extensions: <String>[FileExtensions.straw],
    );

    // 打开文件选择对话框
    // 参数说明：
    // - acceptedTypeGroups: 允许的文件类型组
    final file = await openFile(
      acceptedTypeGroups: <XTypeGroup>[typeGroup],
    );

    // 用户取消选择时，file 为 null，直接返回
    if (file == null) {
      return;
    }

    // 用户选择了文件，获取文件路径
    // file.path 是完整绝对路径，如 "C:\Users\xxx\Documents\card.straw"
    final filePath = file.path;

    // 验证文件路径有效性
    if (filePath.isEmpty) {
      if (context.mounted) {
        _showErrorSnackBar(context, '无效的文件路径');
      }
      return;
    }

    // 导航到阅读器页面，通过 query 参数传入文件路径
    // ReaderScreen 会从路由参数中获取路径并加载文件
    if (context.mounted) {
      context.go('/reader?path=${Uri.encodeComponent(filePath)}');
    }
  }

  /// 显示错误 SnackBar
  ///
  /// 在页面底部显示短暂的错误提示消息。
  ///
  /// 参数：
  /// - [context] - BuildContext 用于显示 SnackBar
  /// - [message] - 错误消息内容
  void _showErrorSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
