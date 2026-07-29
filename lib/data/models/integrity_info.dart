import 'package:flutter/foundation.dart';

/// 完整性校验信息
///
/// 封装文件完整性校验的哈希值和算法标识。
/// 用于 .straw 和 .key 文件的 `integrity` 对象。
///
/// 字段说明：
/// - [hash]: 完整性校验哈希，格式为 "sha256:{十六进制哈希值}"
/// - [hashAlgorithm]: 哈希算法标识，固定为 "SHA-256"
///
/// 使用示例：
/// ```json
/// {
///   "hash": "sha256:abcdef1234567890...",
///   "hash_algorithm": "SHA-256"
/// }
/// ```
@immutable
class IntegrityInfo {
  /// 创建完整性校验信息实例
  ///
  /// 参数说明：
  /// - [hash]: 哈希值字符串，必填
  /// - [hashAlgorithm]: 算法标识，必填
  const IntegrityInfo({
    required this.hash,
    required this.hashAlgorithm,
  });

  /// 从 JSON 映射反序列化完整性校验信息
  ///
  /// 参数：[json] - 文件中的 `integrity` 对象
  /// 返回：解析后的 IntegrityInfo 实例
  factory IntegrityInfo.fromJson(Map<String, dynamic> json) {
    return IntegrityInfo(
      hash: json['hash'] as String,
      hashAlgorithm: json['hash_algorithm'] as String,
    );
  }

  /// 文件内容的 SHA-256 哈希值
  ///
  /// 格式："sha256:{64 位十六进制字符}"
  /// 示例：
  /// "sha256:5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8"
  final String hash;

  /// 哈希算法标识
  ///
  /// 固定为 "SHA-256"，与 IntegrityConstants.hashAlgorithm 一致。
  final String hashAlgorithm;

  /// 判断两个 IntegrityInfo 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IntegrityInfo &&
          runtimeType == other.runtimeType &&
          hash == other.hash &&
          hashAlgorithm == other.hashAlgorithm;

  /// 计算 IntegrityInfo 对象的哈希值
  @override
  int get hashCode => Object.hash(hash, hashAlgorithm);

  /// 将完整性校验信息序列化为 JSON 映射
  ///
  /// 返回的 Map 可直接嵌入文件的 `integrity` 字段。
  Map<String, dynamic> toJson() => {
        'hash': hash,
        'hash_algorithm': hashAlgorithm,
      };
}
