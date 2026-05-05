import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as encrypt;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/memory_utils.dart';

/// 加密服务接口
///
/// 定义 StrawHut 核心加密/解密操作的契约。
/// 所有加密功能通过此接口实现，确保：
/// - 使用 AES-256-GCM 对称加密算法
/// - 使用 CSPRNG 生成加密安全的随机密钥
/// - 提供敏感数据内存清理机制
///
/// 架构位置：核心服务层（Core Service Layer）
/// 依赖接口：无
/// 被依赖方：应用层（PublishDialog、DecryptDialog）通过 Riverpod Provider 调用
abstract class ICryptoService {
  /// 生成加密密钥
  ///
  /// 使用 CSPRNG（密码学安全伪随机数生成器）生成 32 字节（256 位）随机密钥。
  /// 返回的 [GeneratedKey] 包含原始字节和 Base64 编码字符串。
  ///
  /// 安全要求：
  /// - 必须使用 [Random.secure()] 而非普通随机数生成器
  /// - 密钥生成后应尽快传递到加密操作，减少内存驻留时间
  Future<GeneratedKey> generateKey();

  /// 加密知识内容
  ///
  /// 使用 AES-256-GCM 模式加密 Quill 编辑器的 Delta JSON 内容。
  ///
  /// 参数说明：
  /// - [deltaJson]: Quill 编辑器导出的 Delta JSON 字符串（明文）
  /// - [key]: 32 字节加密密钥（由 [generateKey] 生成）
  ///
  /// 加密流程：
  /// 1. 生成 16 字节安全随机 IV（初始化向量）
  /// 2. 使用 AES-256-GCM 加密 deltaJson
  /// 3. 返回包含密文 Base64、IV Base64 和算法标识的 [EncryptedContent]
  ///
  /// 安全要求：
  /// - IV 必须使用安全随机数生成
  /// - 加密完成后应清理明文引用
  Future<EncryptedContent> encryptContent({
    required String deltaJson,
    required Uint8List key,
  });

  /// 解密知识内容
  ///
  /// 使用 AES-256-GCM 模式解密 .straw 文件中的加密内容。
  ///
  /// 参数说明：
  /// - [encryptedDataBase64]: Base64 编码的密文（来自 .straw 文件）
  /// - [ivBase64]: Base64 编码的 IV（来自 .straw 文件）
  /// - [key]: 32 字节解密密钥（用户手动输入或从 .key 文件解析）
  ///
  /// 返回值：解密后的 Delta JSON 字符串
  ///
  /// 异常处理：
  /// - 密钥错误时抛出 [CryptoException]
  /// - 密文损坏时抛出 [CryptoException]
  /// - GCM 模式自动验证 MAC，防止密文篡改
  Future<String> decryptContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  });

  /// 清理敏感数据
  ///
  /// 将内存中所有敏感数据引用置 null，降低内存泄露风险。
  ///
  /// 清理内容包括：
  /// - 加密/解密密钥（字节数组）
  /// - 明文内容（如适用）
  /// - 其他临时敏感变量
  ///
  /// 注意事项：
  /// - Dart 的 GC 机制不可控，无法强制立即回收
  /// - 最佳实践：调用此方法后尽快让引用超出作用域
  /// - 使用 [MemoryUtils.wipeBytes] 可将字节数组逐字节置零
  void clearSensitiveData();

  /// 从口令派生加密密钥
  ///
  /// 使用 PBKDF2-HMAC-SHA256 算法从用户口令派生 32 字节加密密钥。
  /// 用于协商密钥加密模式，允许用户通过口令保护知识卡片。
  ///
  /// 参数说明：
  /// - [passphrase]: 用户输入的口令
  /// - [salt]: 16 字节盐值（由 CSPRNG 生成）
  /// - [iterations]: PBKDF2 迭代次数，默认为 [KDF_ITERATIONS]（100000）
  ///
  /// 返回值：派生出的 32 字节密钥
  ///
  /// 安全说明：
  /// - 盐值必须使用 CSPRNG 生成，长度必须为 [SALT_LENGTH_BYTES]
  /// - 迭代次数越高，暴力破解成本越大，但派生耗时也越长
  /// - 派生后的密钥与 [generateKey] 生成的密钥用法一致
  Future<Uint8List> deriveKeyFromPassphrase({
    required String passphrase,
    required Uint8List salt,
    int iterations = KDF_ITERATIONS,
  });
}

/// 加密服务实现
///
/// 实现 [ICryptoService] 接口，提供完整的加密/解密功能。
///
/// 依赖的第三方库：
/// - `encrypt` 包：提供高层 AES-256-GCM 加密 API
/// - `pointycastle` 包（通过 encrypt 间接使用）：底层密码学原语
///
/// 使用示例：
/// ```dart
/// final cryptoService = CryptoService(integrityService);
/// final key = await cryptoService.generateKey();
/// final encrypted = await cryptoService.encryptContent(
///   deltaJson: '{"ops": [...]}',
///   key: key.bytes,
/// );
/// // ... 发布完成后清理敏感数据
/// cryptoService.clearSensitiveData();
/// ```
class CryptoService implements ICryptoService {
  /// 构造函数
  ///
  /// 创建加密服务实例，需要注入 [IntegrityService] 依赖。
  ///
  /// 参数说明：
  /// - [integrityService]: 完整性校验服务实例，用于哈希计算和验证
  CryptoService(this.integrityService);

  /// 完整性校验服务依赖
  ///
  /// 用于在加密/解密流程中进行数据完整性校验。
  /// 虽然当前加密/解密操作本身不直接使用此服务，
  /// 但在完整的发布/解密流程中，加密后需要计算哈希，
  /// 解密后需要验证完整性，因此作为依赖注入。
  final IntegrityService integrityService;

  /// 生成加密密钥
  ///
  /// 实现步骤：
  /// 1. 使用 [Random.secure()]（CSPRNG）生成 32 个安全随机字节
  /// 2. 将字节列表转换为 [Uint8List] 以便加密操作使用
  /// 3. 使用 [base64Encode] 将字节数组编码为 Base64 字符串
  /// 4. 返回包含原始字节和编码字符串的 [GeneratedKey]
  ///
  /// 安全注意事项：
  /// - 必须使用 [Random.secure()]，它由操作系统级别的 CSPRNG 支持
  /// - 在 Windows 上底层调用 CryptGenRandom，Linux/Mac 上调用 /dev/urandom
  /// - 密钥生成完成后应尽快用于加密操作，减少内存驻留时间
  /// - 调用方应在使用后调用 [clearSensitiveData] 清理密钥引用
  ///
  /// 性能参考：密钥生成耗时 < 1ms
  @override
  Future<GeneratedKey> generateKey() async {
    // 使用 CSPRNG 生成 32 个安全随机字节
    final random = Random.secure();
    final keyBytes = Uint8List(KEY_LENGTH_BYTES);
    for (var i = 0; i < KEY_LENGTH_BYTES; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    // 将密钥字节编码为 Base64 字符串，便于展示和传输
    final keyBase64 = base64Encode(keyBytes);

    return GeneratedKey(bytes: keyBytes, base64: keyBase64);
  }

  /// 加密知识内容
  ///
  /// 实现步骤：
  /// 1. 创建 AES 加密器，使用 GCM 模式（AEAD 认证加密）
  /// 2. 使用 [IV.fromSecureRandom] 生成 16 字节安全随机 IV
  /// 3. 将密钥字节包装为 [Key] 对象
  /// 4. 将 Delta JSON 字符串转为 UTF-8 字节后加密
  /// 5. 将密文和 IV 分别 Base64 编码
  /// 6. 返回 [EncryptedContent] 对象
  ///
  /// 参数说明：
  /// - [deltaJson]: Quill 编辑器导出的 Delta JSON 明文内容
  /// - [key]: 32 字节加密密钥（必须由 [generateKey] 生成）
  ///
  /// 安全注意事项：
  /// - IV 使用安全随机数生成，保证同一密钥下 IV 不重复
  /// - GCM 模式自动附加消息认证码（MAC），防止密文被篡改
  /// - 加密完成后应调用 [clearSensitiveData] 清理密钥引用
  /// - 明文 deltaJson 应在加密后尽快释放
  ///
  /// 性能优化建议（Phase 6）：
  /// - 使用 `compute` 在 Isolate 中执行加密，避免阻塞 UI 线程
  /// - 大文件（>1MB）可考虑分块加密
  @override
  Future<EncryptedContent> encryptContent({
    required String deltaJson,
    required Uint8List key,
  }) async {
    // 创建 AES-256-GCM 加密器（使用 encrypt 包的高层 API）
    final encrypter = encrypt.Encrypter(
      encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm),
    );

    // 生成 16 字节安全随机 IV
    final iv = encrypt.IV.fromSecureRandom(IV_LENGTH_BYTES);

    // 执行加密操作，将 Delta JSON 字符串转为 UTF-8 字节后加密
    final encrypted = encrypter.encrypt(deltaJson, iv: iv);

    // 将密文和 IV 分别 Base64 编码，便于序列化到 .straw 文件
    return EncryptedContent(
      encryptedDataBase64: base64Encode(encrypted.bytes),
      ivBase64: base64Encode(iv.bytes),
      algorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
    );
  }

  /// 解密知识内容
  ///
  /// 实现步骤：
  /// 1. 使用 Base64 解码 IV 和密文数据
  /// 2. 验证密钥长度是否为 32 字节
  /// 3. 创建 AES 解密器，使用 GCM 模式
  /// 4. 执行解密操作（GCM 模式自动验证 MAC 完整性）
  /// 5. 将解密后的 UTF-8 字节转为字符串返回
  ///
  /// 参数说明：
  /// - [encryptedDataBase64]: Base64 编码的密文
  /// - [ivBase64]: Base64 编码的 IV
  /// - [key]: 32 字节解密密钥（用户输入或从 .key 文件解析）
  ///
  /// 返回值：解密后的 Delta JSON 字符串（Quill 编辑器格式）
  ///
  /// 异常处理：
  /// - 密钥错误：AES-GCM 的 MAC 验证失败，抛出 [CryptoException]
  /// - 密文损坏：Base64 解码或解密失败，抛出 [CryptoException]
  /// - 密钥长度错误：抛出 [CryptoException]
  ///
  /// 安全注意事项：
  /// - GCM 模式自动验证 MAC，防止密文被篡改
  /// - 解密完成后，密钥字节引用应尽快置 null
  /// - 建议在返回结果后立即调用 [clearSensitiveData]
  @override
  Future<String> decryptContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  }) async {
    try {
      // 验证密钥长度是否正确
      if (key.length != KEY_LENGTH_BYTES) {
        throw CryptoException(
          '密钥长度不正确：期望 $KEY_LENGTH_BYTES 字节，实际 ${key.length} 字节',
          code: 'INVALID_KEY_LENGTH',
        );
      }

      // Base64 解码 IV 和密文数据
      final ivBytes = base64Decode(ivBase64);
      final encryptedBytes = base64Decode(encryptedDataBase64);

      // 创建 AES-256-GCM 解密器（使用 encrypt 包的高层 API）
      final encrypter = encrypt.Encrypter(
        encrypt.AES(encrypt.Key(key), mode: encrypt.AESMode.gcm),
      );

      // 执行解密操作
      // 使用 decrypt() 直接传入 Encrypted 对象，避免冗余的 Base64 编解码
      // GCM 模式自动验证 MAC，如果密钥错误或密文被篡改，会抛出异常
      final decrypted = encrypter.decrypt(
        encrypt.Encrypted(encryptedBytes),
        iv: encrypt.IV(ivBytes),
      );

      return decrypted;
    } on CryptoException {
      // 已知的加密异常，直接向上抛出
      rethrow;
    } catch (e) {
      // 其他异常（如 Base64 解码失败、解密失败等）统一包装为 CryptoException
      throw CryptoException(
        '解密失败：可能是密钥错误或文件已损坏。详情：$e',
        code: 'DECRYPTION_FAILED',
      );
    }
  }

  /// 从口令派生加密密钥
  ///
  /// 实现步骤：
  /// 1. 验证盐值长度是否为 [SALT_LENGTH_BYTES] 字节
  /// 2. 使用 PBKDF2-HMAC-SHA256 算法派生密钥
  /// 3. 返回派生后的 32 字节密钥
  ///
  /// 参数说明：
  /// - [passphrase]: 用户输入的口令
  /// - [salt]: 16 字节盐值
  /// - [iterations]: PBKDF2 迭代次数，默认 100000
  ///
  /// 异常处理：
  /// - 盐值长度不正确时抛出 [CryptoException]
  /// - 密钥派生过程出错时抛出 [CryptoException]
  @override
  Future<Uint8List> deriveKeyFromPassphrase({
    required String passphrase,
    required Uint8List salt,
    int iterations = KDF_ITERATIONS,
  }) async {
    if (salt.length != SALT_LENGTH_BYTES) {
      throw CryptoException(
        '盐值长度不正确：期望 $SALT_LENGTH_BYTES 字节，实际 ${salt.length} 字节',
        code: 'INVALID_SALT_LENGTH',
      );
    }

    try {
      // Use compute (Isolate) on non-web platforms to avoid blocking the UI thread.
      // PBKDF2 with 100,000 iterations is CPU-intensive, especially on mobile.
      return compute(
        _deriveKeyFromPassphraseIsolate,
        _DeriveKeyParams(
          passphrase: passphrase,
          salt: salt,
          iterations: iterations,
        ),
      );
    } catch (e) {
      throw CryptoException('密钥派生失败：$e', code: 'KEY_DERIVATION_FAILED');
    }
  }

  /// 清理敏感数据
  ///
  /// 实现步骤：
  /// 1. 由于本实现是无状态的，没有内部持有敏感数据引用
  /// 2. 此方法保留为接口一致性，调用方可自行清理持有的密钥引用
  /// 3. 如果未来需要持有状态（如缓存密钥），在此处调用 [MemoryUtils.wipeBytes]
  ///
  /// 安全注意事项：
  /// - Dart 的 GC 机制不可控，无法强制立即回收
  /// - 最佳实践：调用此方法后尽快让敏感引用超出作用域
  /// - 调用方应自行将持有的密钥字节数组调用 [MemoryUtils.wipeBytes] 逐字节置零
  ///
  /// 调用时机：
  /// - 加密发布流程完成后
  /// - 解密读取流程完成后
  /// - 用户取消操作时
  @override
  void clearSensitiveData() {
    // 当前实现为无状态设计，没有内部持有敏感数据引用。
    // 调用方应自行清理持有的密钥引用，例如：
    //   MemoryUtils.wipeBytes(keyBytes);
    //   keyBytes = null;
    //
    // 如果未来扩展为有状态设计（如缓存解密密钥），
    // 需要在此处清理所有内部持有的敏感数据引用。
  }
}

/// Parameters for PBKDF2 key derivation (must be serializable for compute/Isolate).
class _DeriveKeyParams {
  final String passphrase;
  final Uint8List salt;
  final int iterations;

  _DeriveKeyParams({
    required this.passphrase,
    required this.salt,
    required this.iterations,
  });
}

/// Top-level function for PBKDF2 key derivation in a background Isolate.
///
/// Must be a top-level function because [compute] requires functions that are
/// serializable and accessible without capturing any closure context.
Uint8List _deriveKeyFromPassphraseIsolate(_DeriveKeyParams params) {
  final hmac = HMac.withDigest(SHA256Digest());
  final derivator = PBKDF2KeyDerivator(hmac)
    ..init(Pbkdf2Parameters(params.salt, params.iterations, KEY_LENGTH_BYTES));

  return Uint8List.fromList(
    derivator.process(Uint8List.fromList(utf8.encode(params.passphrase))),
  );
}
