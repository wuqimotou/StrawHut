import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// .key 密钥文件模型
class KeyFile {
  final FormatVersion formatVersion;
  final KeyMetadata keyMetadata;
  final KeyData keyData;
  final IntegrityInfo integrity;

  const KeyFile({
    required this.formatVersion,
    required this.keyMetadata,
    required this.keyData,
    required this.integrity,
  });

  Map<String, dynamic> toJson() => {
    'format_version': formatVersion.toString(),
    'key_metadata': keyMetadata.toJson(),
    'key_data': keyData.toJson(),
    'integrity': integrity.toJson(),
  };

  factory KeyFile.fromJson(Map<String, dynamic> json) {
    return KeyFile(
      formatVersion: FormatVersion.fromString(json['format_version'] as String),
      keyMetadata: KeyMetadata.fromJson(json['key_metadata'] as Map<String, dynamic>),
      keyData: KeyData.fromJson(json['key_data'] as Map<String, dynamic>),
      integrity: IntegrityInfo.fromJson(json['integrity'] as Map<String, dynamic>),
    );
  }
}

/// 密钥元信息
class KeyMetadata {
  final String keyId;
  final String createdAt;
  final String? associatedCardTitle;
  final String? associatedCardId;
  final String keyAlgorithm;
  final int keyLengthBits;
  final String? notes;

  const KeyMetadata({
    required this.keyId,
    required this.createdAt,
    this.associatedCardTitle,
    this.associatedCardId,
    required this.keyAlgorithm,
    required this.keyLengthBits,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'key_id': keyId,
    'created_at': createdAt,
    if (associatedCardTitle != null) 'associated_card_title': associatedCardTitle,
    if (associatedCardId != null) 'associated_card_id': associatedCardId,
    'key_algorithm': keyAlgorithm,
    'key_length_bits': keyLengthBits,
    if (notes != null) 'notes': notes,
  };

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
}

/// 密钥数据
class KeyData {
  final String keyBase64;
  final String encoding;

  const KeyData({
    required this.keyBase64,
    required this.encoding,
  });

  Map<String, dynamic> toJson() => {
    'key_base64': keyBase64,
    'encoding': encoding,
  };

  factory KeyData.fromJson(Map<String, dynamic> json) {
    return KeyData(
      keyBase64: json['key_base64'] as String,
      encoding: json['encoding'] as String,
    );
  }
}
