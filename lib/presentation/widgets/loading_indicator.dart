import 'package:flutter/material.dart';

import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';

/// 加载指示器组件
///
/// 通用加载状态展示组件，包含圆形进度指示器和可选提示文字。
///
/// 架构位置：应用层 → 通用 UI 组件
/// 使用场景：
/// - 文件加载中（HomeScreen 打开 .straw 文件时）
/// - 加密处理中（PublishDialog 点击"生成并加密"后）
/// - 解密处理中（DecryptDialog 点击"解密"后）
///
/// 设计特点：
/// - 垂直居中布局（Column + MainAxisSize.min）
/// - 可选的提示文字，显示在进度指示器下方
/// - Neumorphism 水墨风：凹陷凹槽内嵌软质进度环
///
/// 使用示例：
/// ```dart
/// LoadingIndicator(message: '正在加载文件...')
/// LoadingIndicator() // 仅进度指示器
/// ```
class LoadingIndicator extends StatelessWidget {
  /// 可选的加载提示文字
  ///
  /// 为 null 时不显示文字，仅展示圆形进度指示器。
  final String? message;

  /// 创建加载指示器实例
  ///
  /// 参数：[message] - 可选的加载提示文字
  const LoadingIndicator({super.key, this.message});

  /// 构建加载指示器 UI
  ///
  /// 布局结构：
  /// - Center → Column → NeumorphicInset(concave) 内 CircularProgressIndicator + Text（可选）
  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeumorphicContainer(
            shape: NeumorphicShape.concave,
            borderRadius: tokens.radiusXLarge,
            padding: const EdgeInsets.all(20),
            child: CircularProgressIndicator(
              color: tokens.inkPrimary,
              strokeWidth: 2.5,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            Text(
              message!,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
