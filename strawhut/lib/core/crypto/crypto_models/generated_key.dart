import 'dart:typed_data';

/// 加密密钥生成结果模型
///
/// 封装由 CSPRNG（密码学安全伪随机数生成器）生成的 256 位密钥。
/// 提供两种访问方式：
/// - [bytes]: 原始字节数组，用于加密/解密操作
/// - [base64]: Base64 编码字符串，用于展示、复制和保存到 .key 文件
///
/// 设计特点：
/// - 不可变对象（所有字段为 final），确保密钥在使用期间不被意外修改
/// - const 构造函数，支持编译期常量优化
///
/// 安全注意事项：
/// - [bytes] 包含敏感的密钥原始数据，使用后应尽快清理
/// - [base64] 编码不增加安全性，仅为方便传输
///
/// 使用示例：
/// ```dart
/// final key = GeneratedKey(bytes: keyBytes, base64: keyBase64);
/// // 加密时使用 bytes
/// await cryptoService.encryptContent(deltaJson: content, key: key.bytes);
/// // 展示时使用 base64
/// print('密钥: ${key.base64}');
/// ```
class GeneratedKey {
  /// 创建密钥生成结果实例
  ///
  /// 参数说明：
  /// - [bytes]: 32 字节密钥原始数据，不能为 null
  /// - [base64]: 对应的 Base64 编码字符串，不能为 null
  const GeneratedKey({required this.bytes, required this.base64});

  /// 密钥原始字节数组（32 字节）
  ///
  /// 用于 AES-256 加密/解密操作的实际密钥数据。
  /// 由 [Random.secure()] 生成，包含 256 位熵。
  final Uint8List bytes;

  /// 密钥的 Base64 编码字符串
  ///
  /// 用于：
  /// - 在 PublishDialog 中向用户展示密钥
  /// - 复制到剪贴板
  /// - 写入 .key 文件的 key_base64 字段
  /// - 用户手动输入解密时粘贴
  ///
  /// Base64 编码后长度约为 44 个字符（32 字节 → 43~44 字符）。
  final String base64;
}
