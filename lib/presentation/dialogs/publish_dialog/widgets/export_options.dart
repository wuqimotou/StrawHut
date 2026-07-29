import 'package:flutter/material.dart';

/// 发布对话框 - 导出选项组件
///
/// 提供密钥文件导出选项，用户可选择是否同时生成 .key 文件。
///
/// 架构位置：应用层（Presentation Layer）→ 发布对话框子组件
/// 使用场景：PublishDialog 中密钥生成后显示
///
/// 功能说明：
/// - "导出 .key 文件" 复选框
/// - 勾选后，在保存 .straw 文件后弹出 .key 文件保存对话框
/// - 默认不勾选（密钥文件为可选导出）
///
/// 设计原则：
/// - .key 文件与 .straw 文件分离存储和传输
/// - 用户自主选择是否导出
/// - 避免密钥与加密内容一起泄露
class ExportOptions extends StatelessWidget {
  /// 创建导出选项组件实例
  ///
  /// 参数说明：
  /// - [value]: 当前是否勾选导出选项
  /// - [onChanged]: 勾选状态变化时的回调函数
  const ExportOptions({
    required this.value,
    required this.onChanged,
    super.key,
  });

  /// 当前是否勾选导出选项
  final bool value;

  /// 勾选状态变化时的回调函数
  final ValueChanged<bool?> onChanged;

  /// 构建导出选项 UI
  ///
  /// 布局结构：
  /// - CheckboxListTile
  ///   - title: '导出 .key 文件'
  ///   - subtitle: '密钥文件可单独保存和传输'
  ///
  /// 使用 CheckboxListTile 而非单独的 Checkbox，
  /// 因为前者提供更好的点击区域和视觉反馈。
  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      // 复选框标题
      title: const Text('导出 .key 文件'),

      // 副标题：解释 .key 文件的作用
      subtitle: const Text(
        '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
        style: TextStyle(fontSize: 12),
      ),

      // 当前勾选状态
      value: value,

      // 勾选状态变化时的回调
      onChanged: onChanged,

      // 复选框位置：放在右侧
      controlAffinity: ListTileControlAffinity.leading,

      // 内容边距
      contentPadding: EdgeInsets.zero,

      // 选中时的颜色
      activeColor: Theme.of(context).colorScheme.primary,

      // 选中时显示勾选图标
      checkColor: Colors.white,
    );
  }
}
