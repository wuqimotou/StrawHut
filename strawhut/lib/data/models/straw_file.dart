import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';

/// .straw 知识卡片文件模型
///
/// 这是 StrawHut 最核心的数据模型，代表一张完整的知识卡片。
/// 对应 .straw 文件的完整 JSON 结构。
///
/// 文件结构：
/// ```json
/// {
///   "format_version": "1.0.0",
///   "meta": { ... },         // 公开元数据
///   "content": { ... },      // 加密内容
///   "integrity": { ... }     // 完整性校验
/// }
/// ```
///
/// 架构位置：数据层（Data Layer）
/// 依赖模型：FormatVersion, CardMeta, EncryptedContent, IntegrityInfo
/// 使用场景：
/// - FileIOService 读取 .straw 文件后解析为此对象
/// - PublishDialog 组装各部分后序列化为此对象
@immutable
class StrawFile {
  /// 创建知识卡片实例
  ///
  /// 所有参数均为必填，确保卡片结构完整。
  const StrawFile({
    required this.formatVersion,
    required this.meta,
    required this.content,
    required this.integrity,
  });

  /// 从 JSON 映射反序列化知识卡片
  ///
  /// 参数：[json] - 完整的 .straw 文件 JSON 映射
  /// 返回：解析后的 StrawFile 实例
  ///
  /// 解析流程：
  /// 1. 从 format_version 字符串创建 FormatVersion
  /// 2. 从 meta 对象创建 CardMeta
  /// 3. 从 content 对象提取字段创建 EncryptedContent
  /// 4. 从 integrity 对象创建 IntegrityInfo
  factory StrawFile.fromJson(Map<String, dynamic> json) {
    final contentMap = json['content'] as Map<String, dynamic>;
    return StrawFile(
      formatVersion: FormatVersion.fromString(
        json['format_version'] as String,
      ),
      meta: CardMeta.fromJson(json['meta'] as Map<String, dynamic>),
      content: EncryptedContent.fromJson(contentMap),
      integrity: IntegrityInfo.fromJson(
        json['integrity'] as Map<String, dynamic>,
      ),
    );
  }

  /// 文件格式版本号
  ///
  /// 用于验证文件格式兼容性。
  /// 当前版本为 "1.0.0"，主版本为 1。
  final FormatVersion formatVersion;

  /// 公开元数据
  ///
  /// 包含标题、发布者、标签等未加密信息。
  /// 即使不解密知识内容也能看到这些元数据。
  final CardMeta meta;

  /// 加密内容
  ///
  /// 包含加密后的 Delta JSON、IV 和算法标识。
  /// 只有使用正确的 256 位密钥才能解密。
  final EncryptedContent content;

  /// 完整性校验信息
  ///
  /// 包含 SHA-256 哈希和算法标识，
  /// 用于验证文件是否被篡改。
  final IntegrityInfo integrity;

  /// 判断两个 StrawFile 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrawFile &&
          runtimeType == other.runtimeType &&
          formatVersion == other.formatVersion &&
          meta == other.meta &&
          content == other.content &&
          integrity == other.integrity;

  /// 计算 StrawFile 对象的哈希值
  @override
  int get hashCode => Object.hash(formatVersion, meta, content, integrity);

  /// 将知识卡片序列化为 JSON 映射
  ///
  /// 返回的 Map 包含完整的 .straw 文件结构。
  /// 可通过 [assembleToJson] 进一步转换为 JSON 字符串。
  Map<String, dynamic> toJson() => {
        'format_version': formatVersion.toString(),
        'meta': meta.toJson(),
        'content': content.toJson(),
        'integrity': integrity.toJson(),
      };

  /// 将知识卡片组装为完整的 JSON 字符串
  ///
  /// 这是发布流程的最后一步：
  /// 1. 各部分组装为 StrawFile 对象
  /// 2. 调用此方法生成 JSON 字符串
  /// 3. 写入 .straw 文件
  ///
  /// 返回：完整的 .straw 文件 JSON 字符串
  String assembleToJson() => jsonEncode(toJson());
}
