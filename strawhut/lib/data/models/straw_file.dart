import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';

@immutable
class StrawFile {
  const StrawFile({
    required this.formatVersion,
    required this.meta,
    required this.content,
    required this.integrity,
  });

  factory StrawFile.fromJson(Map<String, dynamic> json) {
    return StrawFile(
      formatVersion: FormatVersion.fromString(
        json['format_version'] as String,
      ),
      meta: CardMeta.fromJson(json['meta'] as Map<String, dynamic>),
      content: StrawContent.fromJson(json['content'] as Map<String, dynamic>),
      integrity: IntegrityInfo.fromJson(
        json['integrity'] as Map<String, dynamic>,
      ),
    );
  }

  final FormatVersion formatVersion;
  final CardMeta meta;
  final StrawContent content;
  final IntegrityInfo integrity;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StrawFile &&
          runtimeType == other.runtimeType &&
          formatVersion == other.formatVersion &&
          meta == other.meta &&
          content == other.content &&
          integrity == other.integrity;

  @override
  int get hashCode => Object.hash(formatVersion, meta, content, integrity);

  Map<String, dynamic> toJson() => {
        'format_version': formatVersion.toString(),
        'meta': meta.toJson(),
        'content': content.toJson(),
        'integrity': integrity.toJson(),
      };

  /// 将 StrawFile 组装为 JSON 字符串（仅 JSON Header 部分）
  ///
  /// 在二进制 .straw v2.0 格式中，此方法生成的是嵌入二进制文件中的
  /// JSON Header 字符串，不包含加密分块数据。
  String assembleHeaderToJson() => jsonEncode(toJson());

  /// 将 StrawFile 组装为 JSON 字符串的兼容别名
  ///
  /// 与 [assembleHeaderToJson] 相同，保留此方法以兼容现有调用方。
  /// 新代码应优先使用 [assembleHeaderToJson]。
  String assembleToJson() => assembleHeaderToJson();
}
