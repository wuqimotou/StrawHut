import 'package:flutter/foundation.dart';

/// .straw 文件内容描述（JSON Header 中的 content 对象）
///
/// 描述加密载荷的元信息，不包含密文本身。
/// 密文存储在二进制分块载荷中，由 FileIOService 读写。
@immutable
class StrawContent {
  const StrawContent({
    required this.encryptionAlgorithm,
    required this.chunkSize,
    required this.totalChunks,
    required this.originalPayloadSize,
    this.saltBase64,
    this.kdfAlgorithm,
    this.kdfIterations,
  });

  /// 从 JSON 反序列化
  factory StrawContent.fromJson(Map<String, dynamic> json) {
    return StrawContent(
      encryptionAlgorithm: json['encryption_algorithm'] as String,
      chunkSize: json['chunk_size'] as int,
      totalChunks: json['total_chunks'] as int,
      originalPayloadSize: json['original_payload_size'] as int,
      saltBase64: json['salt'] as String?,
      kdfAlgorithm: json['kdf_algorithm'] as String?,
      kdfIterations: json['kdf_iterations'] as int?,
    );
  }

  /// 加密算法，固定为 "AES-256-GCM"
  final String encryptionAlgorithm;

  /// 分块大小（字节）
  final int chunkSize;

  /// 总分块数
  final int totalChunks;

  /// 原始载荷大小（字节，含 PayloadMetadata 前缀）
  final int originalPayloadSize;

  /// Base64 编码的盐值（协商密钥模式）
  final String? saltBase64;

  /// 密钥派生算法标识（协商密钥模式）
  final String? kdfAlgorithm;

  /// KDF 迭代次数（协商密钥模式）
  final int? kdfIterations;

  /// 序列化为 JSON
  Map<String, dynamic> toJson() => {
        'encryption_algorithm': encryptionAlgorithm,
        'chunk_size': chunkSize,
        'total_chunks': totalChunks,
        'original_payload_size': originalPayloadSize,
        'salt': saltBase64,
        'kdf_algorithm': kdfAlgorithm,
        'kdf_iterations': kdfIterations,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrawContent &&
          encryptionAlgorithm == other.encryptionAlgorithm &&
          chunkSize == other.chunkSize &&
          totalChunks == other.totalChunks &&
          originalPayloadSize == other.originalPayloadSize &&
          saltBase64 == other.saltBase64 &&
          kdfAlgorithm == other.kdfAlgorithm &&
          kdfIterations == other.kdfIterations;

  @override
  int get hashCode => Object.hash(
        encryptionAlgorithm,
        chunkSize,
        totalChunks,
        originalPayloadSize,
        saltBase64,
        kdfAlgorithm,
        kdfIterations,
      );
}
