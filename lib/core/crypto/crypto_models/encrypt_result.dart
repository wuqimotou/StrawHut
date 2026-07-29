import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';

/// 加密结果
@immutable
class EncryptResult {
  const EncryptResult({
    required this.chunks,
    required this.chunkSize,
    required this.totalChunks,
    required this.originalPayloadSize,
  });

  /// 加密后的分块列表
  final List<ChunkInfo> chunks;

  /// 分块大小（字节）
  final int chunkSize;

  /// 总分块数
  final int totalChunks;

  /// 原始载荷大小（字节）
  final int originalPayloadSize;
}

/// 解密结果
@immutable
class DecryptResult {
  const DecryptResult({
    required this.payloadMetadata,
    required this.payloadBytes,
    this.decryptedFilePath,
  });

  /// 载荷元数据
  final PayloadMetadata payloadMetadata;

  /// 解密后的载荷字节
  ///
  /// 流式解密时此字段为空 [Uint8List]，应使用 [decryptedFilePath] 访问数据。
  final Uint8List payloadBytes;

  /// 流式解密时的临时文件路径
  ///
  /// 非空时，[payloadBytes] 为空 [Uint8List]，应使用此文件路径访问解密后的数据。
  /// 适用于大文件场景，避免将整个文件内容加载到内存导致 OOM。
  final String? decryptedFilePath;
}

/// 流式解密结果
@immutable
class DecryptStreamResult {
  const DecryptStreamResult({
    required this.payloadMetadata,
    required this.targetPath,
  });

  /// 载荷元数据
  final PayloadMetadata payloadMetadata;

  /// 解密后写入的目标文件路径
  final String targetPath;
}
