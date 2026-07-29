import 'dart:typed_data';

/// AES-GCM 加密结果
///
/// 封装 AES-256-GCM 加密操作的输出，包含密文和初始化向量。
class AesGcmResult {
  /// 创建 AES-GCM 加密结果
  const AesGcmResult({required this.ciphertext, required this.iv});

  /// 密文数据（GCM 模式下包含认证标签附加在末尾）
  final Uint8List ciphertext;

  /// 初始化向量（新加密使用 12 字节，兼容旧版 16 字节）
  final Uint8List iv;
}

/// 平台加密通道抽象接口
///
/// 封装平台通信机制（MethodChannel / FFI），使 NativeCryptoService
/// 不直接依赖平台判断逻辑。新增平台只需实现此接口。
///
/// 架构位置：核心加密层 / 原生通道 (Core Crypto / Native Channel)
/// 被依赖方：NativeCryptoService, FallbackCryptoService
abstract class PlatformCryptoChannel {
  /// 生成密码学安全随机字节
  ///
  /// 使用平台级 CSPRNG 生成指定长度的随机字节。
  /// - Android: java.security.SecureRandom
  /// - Windows: BCryptGenRandom
  Future<Uint8List> generateRandom(int length);

  /// AES-256-GCM 加密
  ///
  /// 使用 AES-256-GCM 认证加密模式加密明文。
  /// 返回包含密文（含 16 字节 GCM 认证标签）和 IV 的结果。
  /// 新加密使用 12 字节 IV（NIST SP 800-38D 推荐值）。
  Future<AesGcmResult> encryptAesGcm(Uint8List plaintext, Uint8List key);

  /// AES-256-GCM 解密
  ///
  /// 使用 AES-256-GCM 认证加密模式解密密文。
  /// 支持兼容 12 字节和 16 字节两种 IV 长度。
  /// 密文末尾必须包含 16 字节 GCM 认证标签。
  Future<Uint8List> decryptAesGcm(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
  );

  /// PBKDF2-HMAC-SHA256 密钥派生
  ///
  /// 使用 PBKDF2 算法从口令派生指定长度的密钥。
  /// - Android: javax.crypto.SecretKeyFactory (PBKDF2WithHmacSHA256)
  /// - Windows: BCryptDeriveKeyPBKDF2 (要求 Windows 10 19041+)
  Future<Uint8List> deriveKeyPBKDF2({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  });
}
