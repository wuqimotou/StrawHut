import 'dart:convert';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';

/// .straw 知识卡片文件模型
class StrawFile {
  final FormatVersion formatVersion;
  final CardMeta meta;
  final EncryptedContent content;
  final IntegrityInfo integrity;

  const StrawFile({
    required this.formatVersion,
    required this.meta,
    required this.content,
    required this.integrity,
  });

  Map<String, dynamic> toJson() => {
    'format_version': formatVersion.toString(),
    'meta': meta.toJson(),
    'content': content.toJson(),
    'integrity': integrity.toJson(),
  };

  factory StrawFile.fromJson(Map<String, dynamic> json) {
    return StrawFile(
      formatVersion: FormatVersion.fromString(json['format_version'] as String),
      meta: CardMeta.fromJson(json['meta'] as Map<String, dynamic>),
      content: EncryptedContent(
        encryptedDataBase64: json['content']['encrypted_data'] as String,
        ivBase64: json['content']['iv'] as String,
        algorithm: json['content']['encryption_algorithm'] as String,
      ),
      integrity: IntegrityInfo.fromJson(json['integrity'] as Map<String, dynamic>),
    );
  }

  String assembleToJson() => jsonEncode(toJson());
}

/// 完整性校验信息
class IntegrityInfo {
  final String hash;
  final String hashAlgorithm;

  const IntegrityInfo({
    required this.hash,
    required this.hashAlgorithm,
  });

  Map<String, dynamic> toJson() => {
    'hash': hash,
    'hash_algorithm': hashAlgorithm,
  };

  factory IntegrityInfo.fromJson(Map<String, dynamic> json) {
    return IntegrityInfo(
      hash: json['hash'] as String,
      hashAlgorithm: json['hash_algorithm'] as String,
    );
  }
}
