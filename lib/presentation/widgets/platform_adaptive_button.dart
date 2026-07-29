import 'package:flutter/material.dart';

/// 平台自适应按钮组件
///
/// 根据运行平台自动选择合适的按钮样式。
///
/// 架构位置：应用层 → 通用 UI 组件
/// 使用场景：各页面和对话框中的操作按钮
///
/// 设计特点：
/// - 使用 ElevatedButton.icon 提供图标+文字组合按钮
/// - 支持自定义图标（可选）
/// - Material 3 默认样式，在 Windows 和移动端均有一致表现
///
/// 使用示例：
/// ```dart
/// PlatformAdaptiveButton(
///   label: '发布',
///   icon: Icons.cloud_upload,
///   onPressed: _publish,
/// )
/// ```
class PlatformAdaptiveButton extends StatelessWidget {
  /// 按钮文字
  ///
  /// 必填参数，显示按钮的功能描述。
  final String label;

  /// 按钮点击回调
  ///
  /// 必填参数，用户点击按钮时执行的逻辑。
  final VoidCallback onPressed;

  /// 按钮图标
  ///
  /// 可选参数，为 null 时不显示图标。
  final IconData? icon;

  /// 创建平台自适应按钮实例
  ///
  /// 参数说明：
  /// - [label]: 按钮文字，必填
  /// - [onPressed]: 点击回调，必填
  /// - [icon]: 可选的图标
  const PlatformAdaptiveButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
  });

  /// 构建按钮 UI
  ///
  /// 布局结构：
  /// - ElevatedButton.icon
  ///   - icon: 图标（可选，为 null 时显示空 Widget）
  ///   - label: 文字
  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: icon != null ? Icon(icon) : const SizedBox.shrink(),
      label: Text(label),
    );
  }
}
