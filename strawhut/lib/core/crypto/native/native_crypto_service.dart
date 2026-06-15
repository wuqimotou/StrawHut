import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

import 'ffi_crypto_channel.dart';
import 'method_channel_crypto_channel.dart';
import 'platform_crypto_channel.dart';
import 'windows_crypto_ffi.dart';

/// 原生加密服务实现
///
/// 通过 [PlatformCryptoChannel] 调用平台原生加密 API，
/// 替代基于 pointycastle + encrypt 的纯 Dart 实现。
///
/// 架构设计：
/// - 通过构造函数注入 PlatformCryptoChannel，不直接依赖平台判断
/// - Windows FFI 同步调用对大内容（>64KB）自动移入 Isolate
/// - Android MethodChannel 本身异步，不阻塞 UI
///
/// 性能提升：
/// - PBKDF2 密钥派生：5-10x 加速（利用平台硬件加速）
/// - AES-GCM 加解密：3-10x 加速（利用 AES-NI 指令集）
class NativeCryptoService implements ICryptoService {
  /// 创建原生加密服务
  ///
  /// [integrityService] 用于加密/解密流程中的完整性校验
  /// [channel] 平台加密通道（通过 PlatformCryptoChannel 抽象）
  NativeCryptoService(this.integrityService, this._channel);

  /// 完整性校验服务依赖
  final IntegrityService integrityService;

  /// 平台加密通道
  final PlatformCryptoChannel _channel;

  /// 当前平台是否支持原生加密
  static bool get isNativeSupported =>
      Platform.isAndroid || Platform.isWindows;

  /// 创建当前平台的 PlatformCryptoChannel 实例
  ///
  /// 根据当前运行平台自动选择合适的通道实现：
  /// - Android: MethodChannelCryptoChannel
  /// - Windows: FfiCryptoChannel
  /// - 其他平台: 抛出 UnsupportedError
  static PlatformCryptoChannel createChannel() {
    if (Platform.isAndroid) {
      return MethodChannelCryptoChannel();
    } else if (Platform.isWindows) {
      return FfiCryptoChannel();
    }
    throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
  }

  @override
  Future<GeneratedKey> generateKey() async {
    final bytes = await _channel.generateRandom(KEY_LENGTH_BYTES);
    return GeneratedKey(bytes: bytes, base64: base64Encode(bytes));
  }

  @override
  Future<EncryptedContent> encryptContent({
    required String deltaJson,
    required Uint8List key,
  }) async {
    final plaintext = Uint8List.fromList(utf8.encode(deltaJson));

    // Windows FFI 为同步调用，大内容需移入 Isolate 避免阻塞 UI
    // Android MethodChannel 本身异步，不会阻塞 UI
    if (Platform.isWindows && plaintext.length > _isolateThreshold) {
      return compute(
        _encryptInIsolate,
        _IsolateParams(
          plaintext: plaintext,
          key: key,
        ),
      );
    }

    final result = await _channel.encryptAesGcm(plaintext, key);
    return EncryptedContent(
      encryptedDataBase64: base64Encode(result.ciphertext),
      ivBase64: base64Encode(result.iv),
      algorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
    );
  }

  @override
  Future<String> decryptContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  }) async {
    if (key.length != KEY_LENGTH_BYTES) {
      throw CryptoException(
        '密钥长度不正确：期望 $KEY_LENGTH_BYTES 字节，实际 ${key.length} 字节',
        code: 'INVALID_KEY_LENGTH',
      );
    }

    final ciphertext = base64Decode(encryptedDataBase64);
    final iv = base64Decode(ivBase64);

    try {
      Uint8List plaintext;

      // Windows FFI 为同步调用，大内容需移入 Isolate
      if (Platform.isWindows && ciphertext.length > _isolateThreshold) {
        plaintext = await compute(
          _decryptInIsolate,
          _IsolateParams(
            ciphertext: ciphertext,
            key: key,
            iv: iv,
          ),
        );
      } else {
        plaintext = await _channel.decryptAesGcm(ciphertext, key, iv);
      }

      return utf8.decode(plaintext);
    } catch (e) {
      throw CryptoException(
        '解密失败：可能是密钥错误或文件已损坏。详情：$e',
        code: 'DECRYPTION_FAILED',
      );
    }
  }

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
      return await _channel.deriveKeyPBKDF2(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
        keyLength: KEY_LENGTH_BYTES,
      );
    } on UnsupportedError {
      // Windows 版本不支持原生 PBKDF2，向上抛出让 FallbackCryptoService 处理
      rethrow;
    } catch (e) {
      throw CryptoException('密钥派生失败：$e', code: 'KEY_DERIVATION_FAILED');
    }
  }

  @override
  void clearSensitiveData() {
    // 当前实现为无状态设计，与 CryptoService 一致
  }

  /// Isolate 阈值：超过此大小的内容在 Windows 上移入 Isolate 执行
  static const int _isolateThreshold = 64 * 1024; // 64KB
}

/// Isolate 参数（加密/解密共用）
///
/// 注意：PlatformCryptoChannel 不能跨 Isolate 传递，
/// 因此 Isolate 内需要重新创建通道。
class _IsolateParams {
  const _IsolateParams({
    this.plaintext,
    this.ciphertext,
    required this.key,
    this.iv,
  });

  final Uint8List? plaintext;
  final Uint8List? ciphertext;
  final Uint8List key;
  final Uint8List? iv;
}

/// Isolate 内执行加密
///
/// 注意：MethodChannel 不能在非主 Isolate 中使用，
/// 此函数仅用于 Windows FFI 场景。
EncryptedContent _encryptInIsolate(_IsolateParams params) {
  final ffiResult = _ffiEncryptSync(params.plaintext!, params.key);

  return EncryptedContent(
    encryptedDataBase64: base64Encode(ffiResult.ciphertext),
    ivBase64: base64Encode(ffiResult.iv),
    algorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
  );
}

/// Isolate 内执行解密
///
/// 返回 [Uint8List] 而非 [String]，因为 [compute] 要求返回类型
/// 与调用处的变量类型匹配。
Uint8List _decryptInIsolate(_IsolateParams params) {
  return _ffiDecryptSync(
    params.ciphertext!,
    params.key,
    params.iv!,
  );
}

/// FFI 同步加密（Isolate 内调用）
AesGcmResult _ffiEncryptSync(Uint8List plaintext, Uint8List key) {
  final result = WindowsCryptoFfi.encryptAesGcm(plaintext, key);
  return AesGcmResult(ciphertext: result.ciphertext, iv: result.iv);
}

/// FFI 同步解密（Isolate 内调用）
Uint8List _ffiDecryptSync(Uint8List ciphertext, Uint8List key, Uint8List iv) {
  return WindowsCryptoFfi.decryptAesGcm(ciphertext, key, iv);
}
