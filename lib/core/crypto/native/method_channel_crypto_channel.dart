
import 'package:flutter/services.dart';

import 'package:strawhut/core/crypto/native/platform_crypto_channel.dart';

/// Android 平台加密通道实现
///
/// 通过 MethodChannel (com.strawhut.crypto) 与 Android 原生层通信，
/// 调用 javax.crypto.* 提供的加密 API。
///
/// 原生实现位于: android/app/src/main/kotlin/com/strawhut/strawhut/CryptoPlugin.kt
class MethodChannelCryptoChannel implements PlatformCryptoChannel {
  /// MethodChannel 通道名称
  static const String _channelName = 'com.strawhut.crypto';

  /// MethodChannel 实例（懒加载单例）
  static const MethodChannel _channel = MethodChannel(_channelName);

  @override
  Future<Uint8List> generateRandom(int length) async {
    final result = await _channel.invokeMethod<Uint8List>('generateKey');
    // Android 端固定返回 32 字节密钥，如需指定长度可扩展
    return result!;
  }

  @override
  Future<AesGcmResult> encryptAesGcm(Uint8List plaintext, Uint8List key) async {
    final result =
        await _channel.invokeMethod<Map<String, dynamic>>('encrypt', {
      'plaintext': plaintext,
      'key': key,
    });

    return AesGcmResult(
      ciphertext: result!['ciphertext'] as Uint8List,
      iv: result['iv'] as Uint8List,
    );
  }

  @override
  Future<Uint8List> decryptAesGcm(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
  ) async {
    final result = await _channel.invokeMethod<Uint8List>('decrypt', {
      'ciphertext': ciphertext,
      'key': key,
      'iv': iv,
    });
    return result!;
  }

  @override
  Future<Uint8List> deriveKeyPBKDF2({
    required String passphrase,
    required Uint8List salt,
    required int iterations,
    required int keyLength,
  }) async {
    final result = await _channel.invokeMethod<Uint8List>('deriveKey', {
      'passphrase': passphrase,
      'salt': salt,
      'iterations': iterations,
    });
    return result!;
  }
}
