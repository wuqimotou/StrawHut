import 'dart:typed_data';

import 'package:flutter/material.dart';

/// 图片内容查看器组件
///
/// 用于展示解密后的图片内容。
///
/// 架构位置：应用层（Presentation Layer）-> 阅读器子组件
/// 使用场景：ReaderScreen 解密成功后，内容类型为 image 时展示
///
/// 核心功能：
/// - 使用 Image.memory 直接从字节渲染图片
/// - 支持缩放和查看原图
/// - 自适应图片大小
class ImageViewer extends StatelessWidget {
  /// 创建图片查看器组件实例
  ///
  /// 参数：
  /// - [imageBytes] - 解密后的图片字节数据，必填
  const ImageViewer({
    required this.imageBytes,
    super.key,
  });

  /// 解密后的图片字节数据
  final Uint8List imageBytes;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 800),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          imageBytes,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 64,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '图片加载失败',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '图片数据可能已损坏或格式不受支持',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
