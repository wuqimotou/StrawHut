import 'package:flutter/material.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

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
/// - 标签列表（软质胶囊样式）
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
        content: const StrawContent(
          encryptionAlgorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
          chunkSize: DEFAULT_CHUNK_SIZE,
          totalChunks: 0,
          originalPayloadSize: 0,
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
    final tokens = NeumorphicTokens.ofContext(context);
    return NeumorphicContainer(
      shape: NeumorphicShape.convex,
      intensity: NeumorphicIntensity.subtle,
      borderRadius: tokens.radiusLarge,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ========== 卡片标题（大字号） ==========
          Text(
            meta.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: tokens.textPrimary,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 12),

          // ========== 发布者信息和发布日期 ==========
          Row(
            children: [
              // 匿名标识（软质凹陷胶囊）
              if (meta.isAnonymous) ...[
                _buildAnonymousTag(tokens),
                const SizedBox(width: 8),
              ],
              // 发布者代号
              NeumorphicIcon(
                StrawIcons.person,
                size: 18,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  meta.publisherAlias,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
                ),
              ),
              const Spacer(),
              // 发布日期
              NeumorphicIcon(
                StrawIcons.calendar,
                size: 16,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(meta.publishDate),
                style: TextStyle(
                  fontSize: 13,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),

          // ========== 描述文本 ==========
          if (meta.description != null && meta.description!.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: tokens.divider),
            const SizedBox(height: 12),
            Text(
              meta.description!,
              style: TextStyle(
                fontSize: 14,
                color: tokens.textSecondary,
                height: 1.6,
              ),
            ),
          ],

          // ========== 标签列表（软质胶囊） ==========
          if (meta.tags.isNotEmpty) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: tokens.divider),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: meta.tags.map((tag) => _buildTag(tokens, tag)).toList(),
            ),
          ],

          // ========== 加密算法标识 ==========
          const SizedBox(height: 16),
          Divider(height: 1, color: tokens.divider),
          const SizedBox(height: 12),
          Row(
            children: [
              NeumorphicIcon(
                StrawIcons.lock,
                size: 16,
                color: tokens.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                '加密算法：${strawFile.content.encryptionAlgorithm}',
                style: TextStyle(
                  fontSize: 12,
                  color: tokens.textHint,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 构建匿名标识软质胶囊
  ///
  /// 使用凹陷态容器 + 水墨警告色，避免 Material 3 默认的橙色高饱和。
  Widget _buildAnonymousTag(NeumorphicTokens tokens) {
    return NeumorphicContainer(
      shape: NeumorphicShape.concave,
      intensity: NeumorphicIntensity.subtle,
      borderRadius: 6,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          NeumorphicIcon(
            StrawIcons.eyeOff,
            size: 14,
            color: tokens.warning,
          ),
          const SizedBox(width: 4),
          Text(
            '匿名',
            style: TextStyle(
              color: tokens.warning,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建标签软质胶囊
  ///
  /// 凸起小胶囊，表面同背景色，靠双向阴影定义体积。
  Widget _buildTag(NeumorphicTokens tokens, String tag) {
    return NeumorphicContainer(
      shape: NeumorphicShape.convex,
      intensity: NeumorphicIntensity.subtle,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Text(
        tag,
        style: TextStyle(
          fontSize: 12,
          color: tokens.textSecondary,
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
