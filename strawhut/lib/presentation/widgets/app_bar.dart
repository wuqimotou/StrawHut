import 'package:flutter/material.dart';

/// 自定义应用栏组件
///
/// 封装 AppBar，提供统一的标题和可选的操作按钮。
///
/// 架构位置：应用层 → 通用 UI 组件
/// 使用场景：各页面（HomeScreen、EditorScreen、ReaderScreen）的 appBar 参数
///
/// 设计特点：
/// - 实现 PreferredSizeWidget 接口，可直接作为 Scaffold.appBar
/// - 支持自定义标题文字
/// - 支持右侧操作按钮列表（actions）
/// - 使用 Material 3 AppBar 默认样式
///
/// 使用示例：
/// ```dart
/// Scaffold(
///   appBar: AppAppBar(
///     title: 'StrawHut',
///     actions: [IconButton(icon: Icon(Icons.publish), onPressed: _publish)],
///   ),
/// )
/// ```
class AppAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 标题文字
  final String title;

  /// 右侧操作按钮列表
  ///
  /// 可选参数，为 null 时不显示操作按钮。
  final List<Widget>? actions;

  /// 创建应用栏实例
  ///
  /// 参数说明：
  /// - [title]: 标题文字，必填
  /// - [actions]: 可选的操作按钮列表
  const AppAppBar({
    super.key,
    required this.title,
    this.actions,
  });

  /// 构建应用栏 UI
  ///
  /// 返回标准的 AppBar Widget。
  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      actions: actions,
    );
  }

  /// 返回应用栏的首选尺寸
  ///
  /// 使用 Material Design 标准工具栏高度（kToolbarHeight = 56.0）。
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
