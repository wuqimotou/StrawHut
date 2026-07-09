import 'package:flutter/material.dart';
import 'package:strawhut/core/crypto/crypto_models/content_type_classifier.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';

/// 文件保存提示组件
///
/// 当解密后的文件类型无法在应用内直接展示时（如图片、音频、视频、PDF 等），
/// 提示用户保存文件到本地。
///
/// 架构位置：应用层（Presentation Layer）-> 阅读器子组件
/// 使用场景：ReaderScreen 解密成功后，内容类型非文本时展示
///
/// 核心功能：
/// - 显示文件信息（文件名、类型）
/// - 根据内容类型显示对应图标
/// - 提供保存文件按钮
class FileSavePrompt extends StatelessWidget {
  /// 创建文件保存提示组件实例
  ///
  /// 参数：
  /// - [metadata] - 载荷元数据，包含文件信息
  /// - [tempFilePath] - 临时文件路径（可选，用于保存操作）
  /// - [contentType] - 内容类型，用于选择图标
  /// - [onSave] - 保存文件回调
  const FileSavePrompt({
    required this.metadata,
    this.tempFilePath,
    this.contentType,
    required this.onSave,
    super.key,
  });

  /// 载荷元数据
  final PayloadMetadata metadata;

  /// 临时文件路径
  final String? tempFilePath;

  /// 内容类型（用于选择图标）
  final ContentType? contentType;

  /// 保存文件回调
  final VoidCallback onSave;

  /// 根据文件后缀获取图标
  IconData _getFileIcon() {
    // 优先根据内容类型选择图标
    if (contentType != null) {
      switch (contentType!) {
        case ContentType.image:
          return Icons.image_outlined;
        case ContentType.audio:
          return Icons.audio_file_outlined;
        case ContentType.video:
          return Icons.video_file_outlined;
        case ContentType.pdf:
          return Icons.picture_as_pdf_outlined;
        case ContentType.richText:
        case ContentType.text:
        case ContentType.markdown:
          return Icons.description_outlined;
        case ContentType.other:
          break;
      }
    }

    // 回退：根据扩展名选择图标
    final ext = metadata.originalExtension.toLowerCase();
    switch (ext) {
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.folder_zip_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart_outlined;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow_outlined;
      case 'apk':
      case 'exe':
      case 'dmg':
        return Icons.install_mobile_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }

  /// 获取类型标签文字
  String _getTypeLabel() {
    if (contentType != null) {
      switch (contentType!) {
        case ContentType.image:
          return '图片';
        case ContentType.audio:
          return '音频';
        case ContentType.video:
          return '视频';
        case ContentType.pdf:
          return 'PDF';
        case ContentType.richText:
          return '富文本';
        case ContentType.text:
          return '文本';
        case ContentType.markdown:
          return 'Markdown';
        case ContentType.other:
          return metadata.originalExtension.toUpperCase();
      }
    }
    return metadata.originalExtension.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final fileName =
        metadata.originalFileName ?? 'unknown.${metadata.originalExtension}';
    final typeLabel = _getTypeLabel();

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 文件图标
                Icon(
                  _getFileIcon(),
                  size: 72,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),

                // 文件名
                Text(
                  fileName,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 8),

                // 文件类型标签
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .secondaryContainer
                        .withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$typeLabel 文件',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontWeight: FontWeight.w500,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                // 提示文字
                Text(
                  '此$typeLabel文件需要保存到本地后查看，\n请选择保存位置。',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),

                // 保存按钮
                FilledButton.icon(
                  onPressed: tempFilePath != null ? onSave : null,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('保存文件'),
                ),

                // 临时文件不可用时的提示
                if (tempFilePath == null) ...[
                  const SizedBox(height: 8),
                  Text(
                    '临时文件不可用',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
