import 'package:flutter/foundation.dart';

/// 知识卡片内容来源类型
///
/// 标识知识卡片的载荷来源：
/// - [richText]: 富文本模式，编辑器编写的 Quill Delta JSON
/// - [rawFile]: 文件加密模式，直接上传的原始文件
@immutable
enum SourceType {
  /// 富文本模式：编辑器编写的 Quill Delta JSON
  richText('rich_text'),

  /// 文件加密模式：直接上传的原始文件
  rawFile('raw_file');

  const SourceType(this.value);

  /// JSON 中的存储值
  final String value;

  /// 从 JSON 值解析
  static SourceType fromValue(String value) {
    return SourceType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => SourceType.richText,
    );
  }
}
