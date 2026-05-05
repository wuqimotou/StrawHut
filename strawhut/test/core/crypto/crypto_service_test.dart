import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：创建 CryptoService 测试实例
CryptoService _createCryptoService() => CryptoService(IntegrityService());

void main() {
  group('CryptoService.generateKey', () {
    test('应生成 32 字节密钥', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      expect(key.bytes.length, 32);
    });

    test('密钥生成的 Base64 应非空', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      expect(key.base64.isNotEmpty, true);
    });

    test('两次生成的密钥应不同', () async {
      final cryptoService = _createCryptoService();
      final key1 = await cryptoService.generateKey();
      final key2 = await cryptoService.generateKey();

      expect(key1.bytes, isNot(equals(key2.bytes)));
    });

    test('Base64 应与字节数组一致', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      final decodedBytes = base64Decode(key.base64);

      expect(decodedBytes, key.bytes);
    });
  });

  group('CryptoService.encryptContent / decryptContent', () {
    test('加密解密可逆测试', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "Hello, World!\\n"}]}';

      final encrypted = await cryptoService.encryptContent(
        deltaJson: originalText,
        key: key.bytes,
      );

      final decrypted = await cryptoService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, originalText);
    });

    test('加密中文内容可逆', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "你好，世界！\\n"}]}';

      final encrypted = await cryptoService.encryptContent(
        deltaJson: originalText,
        key: key.bytes,
      );

      final decrypted = await cryptoService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, originalText);
    });

    test('加密空字符串可逆', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encrypted = await cryptoService.encryptContent(
        deltaJson: '',
        key: key.bytes,
      );

      final decrypted = await cryptoService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, '');
    });

    test('相同明文每次加密产生不同密文', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "test\\n"}]}';

      final encrypted1 = await cryptoService.encryptContent(
        deltaJson: originalText,
        key: key.bytes,
      );
      final encrypted2 = await cryptoService.encryptContent(
        deltaJson: originalText,
        key: key.bytes,
      );

      expect(encrypted1.encryptedDataBase64,
          isNot(equals(encrypted2.encryptedDataBase64)));
      expect(encrypted1.ivBase64, isNot(equals(encrypted2.ivBase64)));
    });

    test('错误密钥解密时抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final correctKey = await cryptoService.generateKey();

      final encrypted = await cryptoService.encryptContent(
        deltaJson: '{"ops": [{"insert": "secret\\n"}]}',
        key: correctKey.bytes,
      );

      final wrongKey = await cryptoService.generateKey();

      expect(
        () async => cryptoService.decryptContent(
          encryptedDataBase64: encrypted.encryptedDataBase64,
          ivBase64: encrypted.ivBase64,
          key: wrongKey.bytes,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('篡改密文后解密抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encrypted = await cryptoService.encryptContent(
        deltaJson: '{"ops": [{"insert": "test\\n"}]}',
        key: key.bytes,
      );

      final tamperedBytes = base64Decode(encrypted.encryptedDataBase64);
      tamperedBytes[0] ^= 0xFF;
      final tamperedDataBase64 = base64Encode(tamperedBytes);

      expect(
        () async => cryptoService.decryptContent(
          encryptedDataBase64: tamperedDataBase64,
          ivBase64: encrypted.ivBase64,
          key: key.bytes,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('无效 Base64 IV 解密时抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encrypted = await cryptoService.encryptContent(
        deltaJson: '{"ops": [{"insert": "test\\n"}]}',
        key: key.bytes,
      );

      expect(
        () async => cryptoService.decryptContent(
          encryptedDataBase64: encrypted.encryptedDataBase64,
          ivBase64: 'invalid-base64!!!',
          key: key.bytes,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('CryptoService 密钥和 IV 长度验证', () {
    test('生成的密钥应为 32 字节', () async {
      final cryptoService = _createCryptoService();

      for (var i = 0; i < 10; i++) {
        final key = await cryptoService.generateKey();
        expect(key.bytes.length, 32);
      }
    });

    test('加密产生的 IV 应为 16 字节', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encrypted = await cryptoService.encryptContent(
        deltaJson: '{"ops": [{"insert": "test\\n"}]}',
        key: key.bytes,
      );

      final ivBytes = base64Decode(encrypted.ivBase64);
      expect(ivBytes.length, 16);
    });

    test('使用非 32 字节密钥解密应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();

      expect(
        () async => cryptoService.decryptContent(
          encryptedDataBase64: 'dGVzdA==',
          ivBase64: 'dGVzdA==',
          key: Uint8List(16),
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'INVALID_KEY_LENGTH',
        )),
      );
    });
  });

  group('CryptoService.clearSensitiveData', () {
    test('调用 clearSensitiveData 不应抛出异常', () {
      final cryptoService = _createCryptoService();

      expect(() => cryptoService.clearSensitiveData(), returnsNormally);
    });
  });

  group('CryptoService.deriveKeyFromPassphrase', () {
    test('should derive 32-byte key', () async {
      final cryptoService = CryptoService(IntegrityService());
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = await cryptoService.deriveKeyFromPassphrase(
        passphrase: 'testPassphrase',
        salt: salt,
      );
      expect(key.length, 32);
    });

    test('same passphrase and salt should derive same key', () async {
      final cryptoService = CryptoService(IntegrityService());
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key1 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'samePassphrase', salt: salt);
      final key2 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'samePassphrase', salt: salt);
      expect(key1, equals(key2));
    });

    test('same passphrase with different salt should derive different key',
        () async {
      final cryptoService = CryptoService(IntegrityService());
      final salt1 = Uint8List.fromList(List.generate(16, (i) => i));
      final salt2 = Uint8List.fromList(List.generate(16, (i) => i + 16));
      final key1 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'samePassphrase', salt: salt1);
      final key2 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'samePassphrase', salt: salt2);
      expect(key1, isNot(equals(key2)));
    });

    test('different passphrase with same salt should derive different key',
        () async {
      final cryptoService = CryptoService(IntegrityService());
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key1 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'passphrase1', salt: salt);
      final key2 = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'passphrase2', salt: salt);
      expect(key1, isNot(equals(key2)));
    });

    test('invalid salt length should throw CryptoException', () async {
      final cryptoService = CryptoService(IntegrityService());
      final invalidSalt = Uint8List(8);
      expect(
        () => cryptoService.deriveKeyFromPassphrase(
            passphrase: 'test', salt: invalidSalt),
        throwsA(isA<CryptoException>()
            .having((e) => e.code, 'code', 'INVALID_SALT_LENGTH')),
      );
    });

    test('derived key can encrypt and decrypt', () async {
      final cryptoService = CryptoService(IntegrityService());
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      const originalText = '{"ops": [{"insert": "PBKDF2 test\\n"}]}';
      final key = await cryptoService.deriveKeyFromPassphrase(
          passphrase: 'testPassphrase123', salt: salt);
      final encrypted =
          await cryptoService.encryptContent(deltaJson: originalText, key: key);
      final decrypted = await cryptoService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key,
      );
      expect(decrypted, originalText);
    });
  });
}
