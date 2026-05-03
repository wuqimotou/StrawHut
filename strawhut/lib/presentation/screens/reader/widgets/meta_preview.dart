import 'package:flutter/material.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 元数据预览组件
///
/// 在 ReaderScreen 中展示知识卡片的公开元数据（未解密即可见）。
///
/// 架构位置：应用层（Presentation Layer）-> 阅读器子组件
/// 使用场景：ReaderScreen 未解密状态时显示在页面上方
///
/// 显示内容：
/// - 卡片标题（大字号）
/// - 发布者代号
/// - 发布日期（格式化显示）
/// - 描述文本
/// - 标签列表（Chip 样式）
/// - 匿名标识（如果是匿名模式）
/// - 加密算法标识
///
/// 数据来源：StrawFile.meta（CardMeta 对象）
/// 展示时机：.straw 文件解析成功后、用户输入密钥前
class MetaPreview extends StatelessWidget {
  /// 创建元数据预览组件实例
  ///
  /// 参数：
  /// - [strawFile] - 知识卡片文件对象，用于提取元数据和加密算法信息
  const MetaPreview({required this.strawFile, super.key});

  /// 便捷构造方法：直接从 CardMeta 创建
  ///
  /// 用于仅需展示元数据、不需要加密算法信息的场景。
  factory MetaPreview.fromMeta(CardMeta meta) {
    // 创建一个仅包含元数据的 StrawFile 实例
    // 注意：此方法仅用于 UI 展示，不适用于加密/解密操作
    return MetaPreview(
      strawFile: StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: meta,
        content: const EncryptedContent(
          encryptedDataBase64: '',
          ivBase64: '',
          algorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
        ),
        integrity: const IntegrityInfo(
          hash: '',
          hashAlgorithm: HASH_ALGORITHM_SHA256,
        ),
      ),
    );
  }

  /// 知识卡片文件对象
  final StrawFile strawFile;

  /// 获取关联的 CardMeta 对象
  CardMeta get meta => strawFile.meta;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ========== 卡片标题（大字号） ==========
            Text(
              meta.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),

            // ========== 发布者信息和发布日期 ==========
            Row(
              children: [
                // 匿名标识
                if (meta.isAnonymous) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.visibility_off,
                          size: 14,
                          color: Colors.orange,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '匿名',
                          style: TextStyle(
                            color: Colors.orange[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                // 发布者代号
                Icon(
                  Icons.person_outline,
                  size: 18,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    meta.publisherAlias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const Spacer(),
                // 发布日期
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  _formatDate(meta.publishDate),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),

            // ========== 描述文本 ==========
            if (meta.description != null && meta.description!.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                meta.description!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],

            // ========== 标签列表 ==========
            if (meta.tags.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: meta.tags.map((tag) {
                  return Chip(
                    label: Text(
                      tag,
                      style: const TextStyle(fontSize: 12),
                    ),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],

            // ========== 加密算法标识 ==========
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Text(
                  '加密算法：${strawFile.content.algorithm}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 格式化 ISO 8601 日期字符串为可读格式
  ///
  /// 将 "2026-05-01T12:00:00Z" 格式化为 "2026-05-01"。
  /// 如果解析失败，返回原始字符串。
  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } on Exception {
      return isoDate;
    }
  }
}
