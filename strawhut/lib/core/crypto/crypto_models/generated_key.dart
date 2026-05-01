import 'dart:typed_data';

/// 加密密钥生成结果模型
class GeneratedKey {
  final Uint8List bytes;
  final String base64;

  const GeneratedKey({required this.bytes, required this.base64});
}
