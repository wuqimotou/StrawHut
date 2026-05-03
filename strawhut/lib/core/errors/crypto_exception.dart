import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 加密操作相关异常
///
/// 在加密、解密、密钥生成等操作失败时抛出此异常。
///
/// 常见触发场景：
/// - 解密时使用错误的密钥（GCM MAC 验证失败）
/// - 密文数据已损坏
/// - 密钥长度不正确（非 32 字节）
/// - 加密算法不支持
///
/// 错误代码建议：
/// - 'DECRYPTION_FAILED': 解密失败（密钥错误或密文损坏）
/// - 'INVALID_KEY_LENGTH': 密钥长度不正确
/// - 'UNSUPPORTED_ALGORITHM': 不支持的加密算法
///
/// 使用示例：
/// ```dart
/// try {
///   final decrypted = await cryptoService.decryptContent(...);
/// } on CryptoException catch (e) {
///   if (e.code == 'DECRYPTION_FAILED') {
///     showDialog('密钥错误或文件已损坏');
///   }
/// }
/// ```
class CryptoException extends StrawHutException {
  /// 创建一个新的 [CryptoException] 实例
  ///
  /// [message] 为异常描述，[code] 为可选的错误代码。
  const CryptoException(super.message, {super.code});
}
