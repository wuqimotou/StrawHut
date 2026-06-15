import 'dart:io';
import 'dart:typed_data';

import 'platform_crypto_channel.dart';
import 'windows_crypto_ffi.dart';

/// Windows 平台加密通道实现
///
/// 通过 dart:ffi 直接调用 Windows BCrypt (CNG) API，
/// 提供硬件加速的加密操作。
///
/// FFI 绑定位于: lib/core/crypto/native/windows_crypto_ffi.dart
///
/// 运行时版本检测：
/// - BCryptDeriveKeyPBKDF2 要求 Windows 10 19041+
/// - 构造时检测版本，不支持时 deriveKeyPBKDF2 抛出 UnsupportedError
/// - FallbackCryptoService 捕获此异常并回退到纯 Dart 实现
class FfiCryptoChannel implements PlatformCryptoChannel {
  /// 创建 Windows FFI 加密通道
  ///
  /// 构造时检测 Windows 版本是否支持 BCryptDeriveKeyPBKDF2，
  /// 检测结果缓存为 [_supportsNativePbkdf2]。
  FfiCryptoChannel() {
    _supportsNativePbkdf2 =
        Platform.isWindows && WindowsCryptoFfi.supportsPbkdf2;
  }

  /// 当前系统是否支持原生 PBKDF2
  late final bool _supportsNativePbkdf2;

  @override
  Future<Uint8List> generateRandom(int length) async {
    // FFI 同步调用，但 generateRandom 耗时极短（<1ms），不会阻塞 UI
    return WindowsCryptoFfi.generateRandom(length);
  }

  @override
  Future<AesGcmResult> encryptAesGcm(Uint8List plaintext, Uint8List key) async {
    // FFI 同步调用，小内容直接执行
    final result = WindowsCryptoFfi.encryptAesGcm(plaintext, key);
    return AesGcmResult(ciphertext: result.ciphertext, iv: result.iv);
  }

  @override
  Future<Uint8List> decryptAesGcm(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
  ) async {
    // FFI 同步调用，小内容直接执行
    return WindowsCryptoFfi.decryptAesGcm(ciphertext, key, iv);
  }

  @override
  Future<Uint8List> deriveKeyPBKDF2({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) async {
    if (!_supportsNativePbkdf2) {
      throw UnsupportedError(
        'BCryptDeriveKeyPBKDF2 要求 Windows 10 19041+。'
        '当前系统不满足此要求。',
      );
    }
    // FFI 同步调用，PBKDF2 耗时较长但仍在可接受范围内
    return WindowsCryptoFfi.deriveKeyPBKDF2(
      passphrase,
      salt,
      iterations,
      keyLength,
    );
  }
}
