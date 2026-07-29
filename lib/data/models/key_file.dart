import 'package:flutter/foundation.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';

/// .key 密钥文件模型
///
/// 代表一张完整的密钥文件，用于独立保存和传输加密密钥。
/// 对应 .key 文件的完整 JSON 结构。
///
/// 文件结构：
/// ```json
/// {
///   "format_version": "1.0.0",
///   "key_metadata": { ... },  // 密钥元信息
///   "key_data": { ... },      // 密钥数据
///   "integrity": { ... }      // 完整性校验
/// }
/// ```
///
/// 设计原则：
/// - 密钥文件与 .straw 文件分离存储和传输
/// - 用户自主选择是否导出 .key 文件
/// - 包含关联元信息，方便用户识别密钥用途
///
/// 架构位置：数据层（Data Layer）
@immutable
class KeyFile {
  /// 创建密钥文件实例
  ///
  /// 所有参数均为必填，确保密钥文件结构完整。
  const KeyFile({
    required this.formatVersion,
    required this.keyMetadata,
    required this.keyData,
    required this.integrity,
  });

  /// 从 JSON 映射反序列化密钥文件
  ///
  /// 参数：[json] - 完整的 .key 文件 JSON 映射
  /// 返回：解析后的 KeyFile 实例
  factory KeyFile.fromJson(Map<String, dynamic> json) {
    return KeyFile(
      formatVersion: FormatVersion.fromString(
        json['format_version'] as String,
      ),
      keyMetadata: KeyMetadata.fromJson(
        json['key_metadata'] as Map<String, dynamic>,
      ),
      keyData: KeyData.fromJson(
        json['key_data'] as Map<String, dynamic>,
      ),
      integrity: IntegrityInfo.fromJson(
        json['integrity'] as Map<String, dynamic>,
      ),
    );
  }

  /// 文件格式版本号
  ///
  /// 与 .straw 版本独立管理。
  final FormatVersion formatVersion;

  /// 密钥元信息
  ///
  /// 包含密钥标识、创建时间、关联卡片等描述信息。
  final KeyMetadata keyMetadata;

  /// 密钥数据
  ///
  /// 包含 Base64 编码的实际密钥和编码方式。
  final KeyData keyData;

  /// 完整性校验信息
  ///
  /// 用于验证 .key 文件是否被篡改。
  final IntegrityInfo integrity;

  /// 判断两个 KeyFile 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyFile &&
          runtimeType == other.runtimeType &&
          formatVersion == other.formatVersion &&
          keyMetadata == other.keyMetadata &&
          keyData == other.keyData &&
          integrity == other.integrity;

  /// 计算 KeyFile 对象的哈希值
  @override
  int get hashCode =>
      Object.hash(formatVersion, keyMetadata, keyData, integrity);

  /// 将密钥文件序列化为 JSON 映射
  Map<String, dynamic> toJson() => {
        'format_version': formatVersion.toString(),
        'key_metadata': keyMetadata.toJson(),
        'key_data': keyData.toJson(),
        'integrity': integrity.toJson(),
      };
}

/// 密钥元信息
///
/// 封装 .key 文件中 `key_metadata` 对象的信息。
/// 用于帮助用户识别和管理密钥。
///
/// 字段说明：
/// - [keyId]: 密钥唯一标识
/// - [createdAt]: 创建时间（ISO 8601 UTC）
/// - [associatedCardTitle]: 关联的卡片标题
/// - [associatedCardId]: 关联的卡片标识（预留）
/// - [keyAlgorithm]: 加密算法
/// - [keyLengthBits]: 密钥长度（比特）
/// - [notes]: 用户备注
@immutable
class KeyMetadata {
  /// 创建密钥元信息实例
  const KeyMetadata({
    required this.keyId,
    required this.createdAt,
    required this.keyAlgorithm,
    required this.keyLengthBits,
    this.associatedCardTitle,
    this.associatedCardId,
    this.notes,
  });

  /// 从 JSON 映射反序列化密钥元信息
  factory KeyMetadata.fromJson(Map<String, dynamic> json) {
    return KeyMetadata(
      keyId: json['key_id'] as String,
      createdAt: json['created_at'] as String,
      associatedCardTitle: json['associated_card_title'] as String?,
      associatedCardId: json['associated_card_id'] as String?,
      keyAlgorithm: json['key_algorithm'] as String,
      keyLengthBits: json['key_length_bits'] as int,
      notes: json['notes'] as String?,
    );
  }

  /// 密钥唯一标识
  ///
  /// 格式：k_{时间戳}_{8位随机十六进制}
  /// 示例：k_20260501120000000_a3f7b2c1
  final String keyId;

  /// 密钥创建时间（ISO 8601 UTC 格式）
  ///
  /// 记录密钥生成的时间戳。
  /// 示例："2026-05-01T12:00:00Z"
  final String createdAt;

  /// 关联的卡片标题
  ///
  /// 可选字段，方便用户识别此密钥对应的知识卡片。
  final String? associatedCardTitle;

  /// 关联的卡片标识
  ///
  /// 预留字段，当前版本为 null。
  /// 未来 P2P 功能可能为每张卡片分配唯一标识。
  final String? associatedCardId;

  /// 加密算法标识
  ///
  /// 固定为 "AES-256-GCM"，与 .straw 文件中的算法一致。
  final String keyAlgorithm;

  /// 密钥长度（比特）
  ///
  /// 固定为 256，对应 32 字节的 AES 密钥。
  final int keyLengthBits;

  /// 用户自定义备注
  ///
  /// 可选字段，最长 200 字符。
  /// 用户可以添加任意说明文字。
  final String? notes;

  /// 判断两个 KeyMetadata 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyMetadata &&
          runtimeType == other.runtimeType &&
          keyId == other.keyId &&
          createdAt == other.createdAt &&
          keyAlgorithm == other.keyAlgorithm &&
          keyLengthBits == other.keyLengthBits &&
          associatedCardTitle == other.associatedCardTitle &&
          associatedCardId == other.associatedCardId &&
          notes == other.notes;

  /// 计算 KeyMetadata 对象的哈希值
  @override
  int get hashCode => Object.hash(
        keyId,
        createdAt,
        keyAlgorithm,
        keyLengthBits,
        associatedCardTitle,
        associatedCardId,
        notes,
      );

  /// 将密钥元信息序列化为 JSON 映射
  ///
  /// 可选字段为 null 时不会出现在 JSON 中。
  Map<String, dynamic> toJson() => {
        'key_id': keyId,
        'created_at': createdAt,
        if (associatedCardTitle != null)
          'associated_card_title': associatedCardTitle,
        if (associatedCardId != null) 'associated_card_id': associatedCardId,
        'key_algorithm': keyAlgorithm,
        'key_length_bits': keyLengthBits,
        if (notes != null) 'notes': notes,
      };
}

/// 密钥数据
///
/// 封装 .key 文件中 `key_data` 对象的信息。
/// 包含实际的加密密钥（Base64 编码）。
@immutable
class KeyData {
  /// 创建密钥数据实例
  const KeyData({
    required this.keyBase64,
    required this.encoding,
  });

  /// 从 JSON 映射反序列化密钥数据
  factory KeyData.fromJson(Map<String, dynamic> json) {
    return KeyData(
      keyBase64: json['key_base64'] as String,
      encoding: json['encoding'] as String,
    );
  }

  /// 密钥的 Base64 编码字符串
  ///
  /// 32 字节密钥经 Base64 编码后约 44 个字符。
  /// 用于解密 .straw 文件中的加密内容。
  final String keyBase64;

  /// 编码方式
  ///
  /// 固定为 "base64"，用于未来支持多种编码方式时的版本识别。
  final String encoding;

  /// 判断两个 KeyData 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is KeyData &&
          runtimeType == other.runtimeType &&
          keyBase64 == other.keyBase64 &&
          encoding == other.encoding;

  /// 计算 KeyData 对象的哈希值
  @override
  int get hashCode => Object.hash(keyBase64, encoding);

  /// 将密钥数据序列化为 JSON 映射
  Map<String, dynamic> toJson() => {
        'key_base64': keyBase64,
        'encoding': encoding,
      };
}
