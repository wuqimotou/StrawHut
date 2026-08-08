import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';

/// 载荷元数据
///
/// 存储于加密载荷内部（首块数据的前缀），受 AES-256-GCM 加密保护。
/// 解密后首先提取此信息，用于判断展示方式。
@immutable
class PayloadMetadata {
  const PayloadMetadata({
    required this.sourceType,
    required this.originalExtension,
    this.originalFileName,
  });

  /// 从 JSON 反序列化
  factory PayloadMetadata.fromJson(Map<String, dynamic> json) {
    return PayloadMetadata(
      sourceType: SourceType.fromValue(json['source_type'] as String),
      originalExtension: json['original_extension'] as String,
      originalFileName: json['original_file_name'] as String?,
    );
  }

  /// 从 UTF-8 字节反序列化
  factory PayloadMetadata.fromBytes(Uint8List bytes) {
    return PayloadMetadata.fromJson(
      jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>,
    );
  }

  /// 内容来源类型
  final SourceType sourceType;

  /// 原始文件后缀（不含点号）
  /// - 富文本模式："delta"
  /// - 文件加密模式：原始文件后缀，如 "pdf"、"mp4"
  final String originalExtension;

  /// 原始文件名（含后缀），如 "report.pdf"
  /// 富文本模式下为 null
  final String? originalFileName;

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'source_type': sourceType.value,
        'original_extension': originalExtension,
        if (originalFileName != null) 'original_file_name': originalFileName,
      };

  /// 序列化为 UTF-8 字节
  Uint8List toBytes() => Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PayloadMetadata &&
          sourceType == other.sourceType &&
          originalExtension == other.originalExtension &&
          originalFileName == other.originalFileName;

  @override
  int get hashCode =>
      Object.hash(sourceType, originalExtension, originalFileName);
}
