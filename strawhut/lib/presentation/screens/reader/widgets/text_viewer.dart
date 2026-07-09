import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

/// 文本内容查看器组件
///
/// 用于展示解密后的纯文本或 Markdown 内容。
///
/// 架构位置：应用层（Presentation Layer）-> 阅读器子组件
/// 使用场景：ReaderScreen 解密成功后，内容类型为 text 或 markdown 时展示
///
/// 核心功能：
/// - 纯文本模式：使用 SelectableText 展示，支持文本选择
/// - Markdown 模式：使用 flutter_markdown 渲染 Markdown 格式
class TextViewer extends StatelessWidget {
  /// 创建文本查看器组件实例
  ///
  /// 参数：
  /// - [text] - 要展示的文本内容，必填
  /// - [isMarkdown] - 是否为 Markdown 格式，默认 false
  const TextViewer({
    required this.text,
    this.isMarkdown = false,
    super.key,
  });

  /// 要展示的文本内容
  final String text;

  /// 是否为 Markdown 格式
  final bool isMarkdown;

  @override
  Widget build(BuildContext context) {
    if (isMarkdown) {
      return MarkdownBody(
        data: text,
        selectable: true,
        styleSheet: MarkdownStyleSheet.fromTheme(
          Theme.of(context),
        ).copyWith(
          p: Theme.of(context).textTheme.bodyLarge,
          h1: Theme.of(context).textTheme.headlineMedium,
          h2: Theme.of(context).textTheme.headlineSmall,
          h3: Theme.of(context).textTheme.titleLarge,
          code: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                backgroundColor:
                    Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
        ),
      );
    }

    return SelectableText(
      text,
      style: Theme.of(context).textTheme.bodyLarge,
    );
  }
}
