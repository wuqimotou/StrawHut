import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:path/path.dart' as p;

import 'package:strawhut/core/file_io/file_extensions.dart';

/// 首页拖拽区域组件（仅 Windows 桌面端）
///
/// 使用 `desktop_drop` 包实现文件拖拽功能。
/// 允许用户将 .straw 文件从文件管理器直接拖入应用窗口。
///
/// 架构位置：应用层（Presentation Layer）→ 首页子组件
/// 平台限制：仅 Windows 桌面端可用，移动端不显示
///
/// 拖拽交互流程：
/// 1. 用户将 .straw 文件拖入应用窗口
/// 2. 拖拽区域高亮显示视觉反馈（边框变色、背景色变化）
/// 3. 用户释放文件 → 触发 onFilesDropped 回调
/// 4. 验证文件扩展名为 .straw
/// 5. 读取并解析文件内容
/// 6. 导航到 ReaderScreen 展示元数据预览
///
/// 设计要点：
/// - 拖拽过程中提供明确的视觉反馈
/// - 仅接受 .straw 文件，其他文件类型拒绝
/// - 文件解析失败时展示错误提示
class DropZone extends StatefulWidget {
  /// 创建拖拽区域组件实例
  const DropZone({super.key});

  @override
  State<DropZone> createState() => _DropZoneState();
}

/// DropZone 的状态类
///
/// 管理拖拽区域的视觉状态（是否正在拖拽进入）。
class _DropZoneState extends State<DropZone> {
  /// 标记是否有文件正在被拖入本组件区域
  ///
  /// 当文件被拖入时设置为 true，用于显示高亮视觉反馈。
  /// 当文件被拖出或释放后重置为 false。
  bool _isDragging = false;

  /// 构建拖拽区域 UI
  ///
  /// 布局结构：
  /// - DropTarget 包裹整个区域，监听拖拽事件
  /// - 虚线边框容器，内部显示提示文字和图标
  /// - 拖入时边框变为实线+高亮色，背景色变化
  @override
  Widget build(BuildContext context) {
    // On Android/iOS/web, drop zone is not supported - render nothing
    if (kIsWeb ||
        defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }

    // Windows/macOS/Linux: render drop zone
    // Use DropTarget 包裹拖拽区域，监听拖拽事件
    // desktop_drop 包提供跨平台拖拽支持
    return DropTarget(
      // 文件被拖入区域时触发
      // 设置 _isDragging 为 true，触发 UI 高亮反馈
      onDragEntered: (details) {
        setState(() {
          _isDragging = true;
        });
      },
      // 文件被拖出区域时触发
      // 重置 _isDragging 为 false，移除高亮反馈
      onDragExited: (details) {
        setState(() {
          _isDragging = false;
        });
      },
      // 文件在区域内释放时触发
      // 这是实际处理文件的核心回调
      onDragDone: (details) {
        // 重置拖拽状态
        setState(() {
          _isDragging = false;
        });
        // 将 DropItem 列表转换为文件路径字符串列表后处理
        final filePaths =
            details.files.map((dropItem) => dropItem.path).toList();
        _onFilesDropped(filePaths, context);
      },
      // 拖拽区域内容
      child: Container(
        // 容器高度固定，提供足够的拖拽目标区域
        height: 120,
        // 边框样式：拖入时为实线，平时为虚线
        decoration: BoxDecoration(
          // 背景色：拖入时显示高亮蓝色，平时为透明
          // 使用 withValues() 替代已弃用的 withOpacity()
          color: _isDragging
              ? Colors.blue.withValues(alpha: 0.1)
              : Colors.transparent,
          // 边框：拖入时为蓝色实线，平时为灰色虚线
          border: Border.all(
            color: _isDragging ? Colors.blue : Colors.grey[400]!,
            width: _isDragging ? 2 : 1,
            style: _isDragging ? BorderStyle.solid : BorderStyle.solid,
          ),
          // 圆角，让拖拽区域更美观
          borderRadius: BorderRadius.circular(12),
        ),
        // 居中对齐内部内容
        alignment: Alignment.center,
        // 内部内容：图标 + 提示文字
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 拖拽图标：根据状态变化
            Icon(
              _isDragging ? Icons.file_download : Icons.cloud_upload_outlined,
              size: 32,
              color: _isDragging ? Colors.blue : Colors.grey[600],
            ),
            const SizedBox(height: 8),
            // 提示文字：引导用户拖入 .straw 文件
            Text(
              '或将 .straw / .png 文件拖拽至此',
              style: TextStyle(
                color: _isDragging ? Colors.blue : Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// 处理文件拖入事件
  ///
  /// 当用户释放文件时调用此方法。
  ///
  /// 流程：
  /// 1. 检查是否有文件
  /// 2. 验证每个文件的扩展名
  /// 3. 只处理第一个有效的 .straw 文件
  /// 4. 导航到阅读器页面并传入文件路径
  ///
  /// 参数：
  /// - [files] - 拖入的文件路径列表
  /// - [context] - BuildContext 用于导航
  void _onFilesDropped(List<String> files, BuildContext context) {
    // 检查是否有文件被拖入
    // 如果没有文件，可能是用户误操作，直接返回
    if (files.isEmpty) {
      return;
    }

    // 遍历所有拖入的文件，查找第一个有效的 .straw 文件
    // 用户可以一次拖入多个文件，但我们只处理第一个知识卡片文件
    String? validFilePath;
    for (final filePath in files) {
      if (_isValidCardFile(filePath)) {
        validFilePath = filePath;
        break;
      }
    }

    // 如果没有找到有效的 .straw 文件
    // 向用户显示错误提示
    if (validFilePath == null) {
      _showErrorSnackBar(context, '请拖入有效的 .straw 或 .png 知识卡片文件');
      return;
    }

    // 找到有效文件后，导航到阅读器页面
    // 通过 query 参数传入文件路径
    context.go('/reader?path=${Uri.encodeComponent(validFilePath)}');
  }

  /// 验证文件是否为有效的 .straw 文件
  ///
  /// 检查文件扩展名是否为 .straw（不区分大小写）。
  /// 这是初步筛选，真正的格式验证在阅读器页面中进行。
  ///
  /// 参数：[filePath] - 文件完整路径
  /// 返回：true 表示是 .straw 文件，false 表示不是
  bool _isValidCardFile(String filePath) {
    final extension = p.extension(filePath);
    return extension.toLowerCase() == FileExtensions.straw ||
        extension.toLowerCase() == FileExtensions.png;
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
