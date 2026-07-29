import 'package:strawhut/core/crypto/crypto_models/source_type.dart';

/// 内容类型分类
///
/// 解密后根据载荷元数据判断的展示分类。
enum ContentType {
  /// 富文本（QuillViewer 渲染）
  richText,

  /// 文本文件（SelectableText 展示）
  text,

  /// Markdown 文件（flutter_markdown 渲染）
  markdown,

  /// 图片文件（Image.memory 展示）
  image,

  /// 音频文件（audioplayers 播放）
  audio,

  /// 视频文件（video_player 播放）
  video,

  /// PDF 文件（syncfusion 查看器）
  pdf,

  /// 其他文件（保存对话框）
  other,
}

/// 内容类型分类器
///
/// 根据文件后缀名分类内容类型，用于决定解密后的展示方式。
class ContentTypeClassifier {
  ContentTypeClassifier._();

  /// 文本文件后缀集合
  static const Set<String> _textExtensions = {
    'txt',
    'json',
    'xml',
    'csv',
    'log',
    'yaml',
    'yml',
    'ini',
    'conf',
    'sh',
    'bat',
    'py',
    'js',
    'ts',
    'html',
    'css',
    'sql',
    'toml',
    'env',
    'c',
    'cpp',
    'h',
    'java',
    'kt',
    'go',
    'rs',
    'rb',
    'php',
    'swift',
    'dart',
  };

  /// 图片文件后缀集合
  static const Set<String> _imageExtensions = {
    'jpg',
    'jpeg',
    'png',
    'gif',
    'bmp',
    'webp',
  };

  /// 音频文件后缀集合
  static const Set<String> _audioExtensions = {
    'mp3',
    'wav',
    'ogg',
    'aac',
    'flac',
    'm4a',
  };

  /// 视频文件后缀集合
  static const Set<String> _videoExtensions = {
    'mp4',
    'mkv',
    'mov',
    'avi',
    'webm',
    '3gp',
  };

  /// 根据来源类型和文件后缀分类内容类型
  ///
  /// 分类优先级：
  /// 1. sourceType == richText → 富文本
  /// 2. sourceType == rawFile → 根据后缀匹配分类
  /// 3. 后缀未匹配 → 归入"其他"
  static ContentType classify({
    required SourceType sourceType,
    required String originalExtension,
  }) {
    // 富文本模式优先
    if (sourceType == SourceType.richText) {
      return ContentType.richText;
    }

    // 文件加密模式按后缀分类
    final ext = originalExtension.toLowerCase();

    if (ext == 'md') {
      return ContentType.markdown;
    }

    if (_textExtensions.contains(ext)) {
      return ContentType.text;
    }

    if (_imageExtensions.contains(ext)) {
      return ContentType.image;
    }

    if (_audioExtensions.contains(ext)) {
      return ContentType.audio;
    }

    if (_videoExtensions.contains(ext)) {
      return ContentType.video;
    }

    if (ext == 'pdf') {
      return ContentType.pdf;
    }

    return ContentType.other;
  }

  /// 判断内容类型是否需要临时文件
  ///
  /// 音频、视频、PDF 和其他文件类型需要临时文件。
  /// 大图片（>10MB）也需要临时文件，但此方法不判断大小。
  static bool needsTempFile(ContentType contentType) {
    switch (contentType) {
      case ContentType.richText:
      case ContentType.text:
      case ContentType.markdown:
        return false;
      case ContentType.image:
        // 小图不需要，大图需要，由调用方判断
        return false;
      case ContentType.audio:
      case ContentType.video:
      case ContentType.pdf:
      case ContentType.other:
        return true;
    }
  }
}
