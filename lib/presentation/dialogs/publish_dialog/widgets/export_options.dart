import 'package:flutter/material.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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
  /// - NeumorphicContainer（凹槽背景）
  ///   - Row
  ///     - NeumorphicIcon（密钥图标）
  ///     - Expanded（标题 + 副标题）
  ///     - Checkbox（Neumorphic tokens 配色）
  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return NeumorphicContainer(
      shape: NeumorphicShape.concave,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          NeumorphicIcon(
            StrawIcons.password,
            size: 20,
            color: tokens.inkSecondary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '导出 .key 文件',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
                  style: TextStyle(
                    fontSize: 12,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Checkbox(
            value: value,
            onChanged: onChanged,
            activeColor: tokens.inkPrimary,
            checkColor: tokens.surface,
            side: BorderSide(color: tokens.surfaceAlt, width: 1.5),
          ),
        ],
      ),
    );
  }
}
