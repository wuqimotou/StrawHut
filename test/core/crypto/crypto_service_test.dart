import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';

/// 辅助函数：创建 CryptoService 测试实例
CryptoService _createCryptoService() => CryptoService(IntegrityService());

/// 辅助函数：构造富文本 PayloadMetadata
PayloadMetadata _richTextMetadata() => PayloadMetadata(
      sourceType: SourceType.richText,
      originalExtension: 'delta',
    );

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

  group('CryptoService.encrypt / decrypt', () {
    test('加密解密可逆测试', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "Hello, World!\\n"}]}';

      final encryptResult = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(originalText)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      final decryptResult = await cryptoService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), originalText);
    });

    test('加密中文内容可逆', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "你好，世界！\\n"}]}';

      final encryptResult = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(originalText)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      final decryptResult = await cryptoService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), originalText);
    });

    test('加密空字符串可逆', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encryptResult = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode('')),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      final decryptResult = await cryptoService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), '');
    });

    test('相同明文每次加密产生不同密文', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      const originalText = '{"ops": [{"insert": "test\\n"}]}';

      final encryptResult1 = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(originalText)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );
      final encryptResult2 = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(originalText)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      // 每个分块的加密数据应不同（因为 IV 随机）
      expect(
        encryptResult1.chunks[0].encryptedData,
        isNot(equals(encryptResult2.chunks[0].encryptedData)),
      );
      // 每个分块的 IV 应不同
      expect(
        encryptResult1.chunks[0].iv,
        isNot(equals(encryptResult2.chunks[0].iv)),
      );
    });

    test('错误密钥解密时抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final correctKey = await cryptoService.generateKey();

      final encryptResult = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(
            utf8.encode('{"ops": [{"insert": "secret\\n"}]}')),
        payloadMetadata: _richTextMetadata(),
        key: correctKey.bytes,
        useV21Security: false,
      );

      final wrongKey = await cryptoService.generateKey();

      expect(
        () async => cryptoService.decrypt(
          chunks: encryptResult.chunks,
          key: wrongKey.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('篡改密文后解密抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encryptResult = await cryptoService.encrypt(
        payloadBytes:
            Uint8List.fromList(utf8.encode('{"ops": [{"insert": "test\\n"}]}')),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      // 篡改第一个分块的密文
      final tamperedData =
          Uint8List.fromList(encryptResult.chunks[0].encryptedData);
      tamperedData[0] ^= 0xFF;
      final tamperedChunks = List<ChunkInfo>.from(encryptResult.chunks);
      tamperedChunks[0] = ChunkInfo(
        iv: encryptResult.chunks[0].iv,
        encryptedData: tamperedData,
      );

      expect(
        () async => cryptoService.decrypt(
          chunks: tamperedChunks,
          key: key.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('篡改 IV 后解密抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encryptResult = await cryptoService.encrypt(
        payloadBytes:
            Uint8List.fromList(utf8.encode('{"ops": [{"insert": "test\\n"}]}')),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      // 篡改第一个分块的 IV
      final tamperedIv = Uint8List.fromList(encryptResult.chunks[0].iv);
      tamperedIv[0] ^= 0xFF;
      final tamperedChunks = List<ChunkInfo>.from(encryptResult.chunks);
      tamperedChunks[0] = ChunkInfo(
        iv: tamperedIv,
        encryptedData: encryptResult.chunks[0].encryptedData,
      );

      expect(
        () async => cryptoService.decrypt(
          chunks: tamperedChunks,
          key: key.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
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

    test('加密产生的每个分块 IV 应为 16 字节', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final encryptResult = await cryptoService.encrypt(
        payloadBytes:
            Uint8List.fromList(utf8.encode('{"ops": [{"insert": "test\\n"}]}')),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        useV21Security: false,
      );

      for (final chunk in encryptResult.chunks) {
        expect(chunk.iv.length, CHUNK_IV_LENGTH_BYTES);
      }
    });

    test('使用非 32 字节密钥解密应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();

      expect(
        () async => cryptoService.decrypt(
          chunks: [
            ChunkInfo(
              iv: Uint8List(CHUNK_IV_LENGTH_BYTES),
              encryptedData: Uint8List.fromList(utf8.encode('test')),
            ),
          ],
          key: Uint8List(16),
          chunkSize: DEFAULT_CHUNK_SIZE,
          originalPayloadSize: 4,
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
      final encryptResult = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(originalText)),
        payloadMetadata: _richTextMetadata(),
        key: key,
        useV21Security: false,
      );
      final decryptResult = await cryptoService.decrypt(
        chunks: encryptResult.chunks,
        key: key,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );
      expect(utf8.decode(decryptResult.payloadBytes), originalText);
    });
  });

  group('CryptoService cancellation', () {
    test('cancel before decrypt prevents all work', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      final encrypted = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(
          List<int>.generate(512, (i) => i % 256),
        ),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        chunkSize: 128,
        useV21Security: false,
      );
      final token = CancellationToken()..cancel();

      await expectLater(
        cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: key.bytes,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          cancellationToken: token,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
    });

    test('cancel after first chunk prevents subsequent progress', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();
      final encrypted = await cryptoService.encrypt(
        payloadBytes: Uint8List.fromList(
          List<int>.generate(2048, (i) => i % 256),
        ),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
        chunkSize: 128,
        useV21Security: false,
      );
      final token = CancellationToken();
      final progress = <int>[];

      await expectLater(
        cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: key.bytes,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          cancellationToken: token,
          onProgress: (current, total) {
            progress.add(current);
            if (current == 1) token.cancel();
          },
        ),
        throwsA(isA<OperationCancelledException>()),
      );
      expect(progress, [1]);
    });

    test('cancelled passphrase derivation does not return a key', () async {
      final cryptoService = _createCryptoService();
      final token = CancellationToken()..cancel();

      await expectLater(
        cryptoService.deriveKeyFromPassphrase(
          passphrase: 'cancel-me',
          salt: Uint8List(16),
          cancellationToken: token,
        ),
        throwsA(isA<OperationCancelledException>()),
      );
    });
  });
}
