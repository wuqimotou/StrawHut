import 'dart:typed_data';
import 'package:strawhut/core/crypto/crypto_models.dart';

/// 加密服务接口
abstract class ICryptoService {
  Future<GeneratedKey> generateKey();

  Future<EncryptedContent> encryptContent({
    required String deltaJson,
    required Uint8List key,
  });

  Future<String> decryptContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  });

  void clearSensitiveData();
}

/// 加密服务实现（Phase 0 占位实现）
class CryptoService implements ICryptoService {
  CryptoService();

  @override
  Future<GeneratedKey> generateKey() {
    // TODO: 实现真实的密钥生成
    throw UnimplementedError('CryptoService.generateKey 尚未实现');
  }

  @override
  Future<EncryptedContent> encryptContent({
    required String deltaJson,
    required Uint8List key,
  }) {
    // TODO: 实现真实的内容加密
    throw UnimplementedError('CryptoService.encryptContent 尚未实现');
  }

  @override
  Future<String> decryptContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  }) {
    // TODO: 实现真实的内容解密
    throw UnimplementedError('CryptoService.decryptContent 尚未实现');
  }

  @override
  void clearSensitiveData() {
    // TODO: 实现敏感数据清理
  }
}
