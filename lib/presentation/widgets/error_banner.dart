import 'package:flutter/material.dart';

/// 错误横幅组件
///
/// 在页面顶部显示错误提示信息，支持关闭操作。
///
/// 架构位置：应用层 → 通用 UI 组件
/// 使用场景：
/// - 文件加载失败时在 HomeScreen 顶部显示
/// - 解密失败时在 ReaderScreen 顶部显示
/// - 格式验证失败时在任意页面显示
///
/// 设计特点：
/// - 浅红色背景（Colors.red.shade100）+ 红色错误图标
/// - 错误消息文字可换行（Expanded）
/// - 可选的关闭按钮（onDismiss）
/// - 固定在页面顶部，不随内容滚动
///
/// 使用示例：
/// ```dart
/// ErrorBanner(
///   message: '文件加载失败：文件格式不正确',
///   onDismiss: () => setState(() => showError = false),
/// )
/// ```
class ErrorBanner extends StatelessWidget {
  /// 错误提示文字
  ///
  /// 必填参数，人类可读的错误描述。
  final String message;

  /// 关闭按钮回调
  ///
  /// 可选参数，为 null 时不显示关闭按钮。
  /// 通常在用户点击关闭按钮后设置错误状态为 false。
  final VoidCallback? onDismiss;

  /// 创建错误横幅实例
  ///
  /// 参数说明：
  /// - [message]: 错误提示文字，必填
  /// - [onDismiss]: 可选的关闭按钮回调
  const ErrorBanner({
    super.key,
    required this.message,
    this.onDismiss,
  });

  /// 构建错误横幅 UI
  ///
  /// 布局结构：
  /// - Container（浅红色背景 + 内边距）
  ///   - Row
  ///     - Icon（错误图标）
  ///     - Text（错误消息，可换行）
  ///     - IconButton（关闭按钮，可选）
  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.red.shade100,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error, color: Colors.red),
          const SizedBox(width: 12),
          Expanded(child: Text(message)),
          if (onDismiss != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: onDismiss,
            ),
        ],
      ),
    );
  }
}
