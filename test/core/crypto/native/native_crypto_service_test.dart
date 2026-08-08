import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';
import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/crypto/native/windows_crypto_ffi.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：构造富文本 PayloadMetadata
PayloadMetadata _richTextMetadata() => const PayloadMetadata(
      sourceType: SourceType.richText,
      originalExtension: 'delta',
    );

void main() {
  // Only run on supported platforms
  if (!NativeCryptoService.isNativeSupported) {
    debugPrint('Skipping NativeCryptoService tests: platform not supported');
    return;
  }

  // On Windows, verify BCrypt API is actually available in the test environment.
  // flutter test runs in a sandboxed Dart VM that may not have access to
  // Windows BCrypt APIs. In that case, skip all native tests.
  if (Platform.isWindows) {
    try {
      WindowsCryptoFfi.generateRandom(1);
    } on Object catch (e) {
      debugPrint(
        'Skipping NativeCryptoService tests: '
        'BCrypt API not available in test environment ($e)',
      );
      return;
    }
  }

  late NativeCryptoService service;

  setUp(() async {
    final integrityService = IntegrityService();
    final channel = NativeCryptoService.createChannel();
    service = NativeCryptoService(integrityService, channel);
  });

  group('generateKey', () {
    test('NC-01: should return 32-byte key with non-empty Base64', () async {
      final key = await service.generateKey();
      expect(key.bytes.length, KEY_LENGTH_BYTES);
      expect(key.base64, isNotEmpty);
    });

    test('NC-02: two generated keys should differ', () async {
      final key1 = await service.generateKey();
      final key2 = await service.generateKey();
      expect(key1.bytes, isNot(equals(key2.bytes)));
    });
  });

  group('encrypt/decrypt', () {
    test(
      'NC-03: encrypt then decrypt should return original content',
      () async {
        final key = await service.generateKey();
        const content = '{"ops": [{"insert": "Hello World"}]}';

        final encryptResult = await service.encrypt(
          payloadBytes: Uint8List.fromList(utf8.encode(content)),
          payloadMetadata: _richTextMetadata(),
          key: key.bytes,
        );

        final decryptResult = await service.decrypt(
          chunks: encryptResult.chunks,
          key: key.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        );

        expect(utf8.decode(decryptResult.payloadBytes), content);
      },
    );

    test('NC-04: encrypt/decrypt Chinese content', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "你好世界，测试中文内容"}]}';

      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      final decryptResult = await service.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
    });

    test('NC-05: encrypt/decrypt empty string', () async {
      final key = await service.generateKey();
      const content = '';

      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      final decryptResult = await service.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
    });

    test('NC-06: same plaintext should produce different ciphertext', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encryptResult1 = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );
      final encryptResult2 = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      // IV should be different (random)
      expect(encryptResult1.chunks[0].iv,
          isNot(equals(encryptResult2.chunks[0].iv)),);
      // Ciphertext should be different
      expect(
        encryptResult1.chunks[0].encryptedData,
        isNot(equals(encryptResult2.chunks[0].encryptedData)),
      );
    });

    test('NC-07: wrong key should throw CryptoException', () async {
      final key1 = await service.generateKey();
      final key2 = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key1.bytes,
      );

      expect(
        () => service.decrypt(
          chunks: encryptResult.chunks,
          key: key2.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('NC-08: tampered ciphertext should throw CryptoException', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      // Tamper with first chunk's ciphertext
      final tamperedData =
          Uint8List.fromList(encryptResult.chunks[0].encryptedData);
      tamperedData[0] ^= 0xFF; // Flip first byte
      final tamperedChunks = List<ChunkInfo>.from(encryptResult.chunks);
      tamperedChunks[0] = ChunkInfo(
        iv: encryptResult.chunks[0].iv,
        encryptedData: tamperedData,
      );

      expect(
        () => service.decrypt(
          chunks: tamperedChunks,
          key: key.bytes,
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('NC-15: invalid key length should throw CryptoException', () async {
      const content = '{"ops": [{"insert": "test"}]}';
      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: (await service.generateKey()).bytes,
      );

      expect(
        () => service.decrypt(
          chunks: encryptResult.chunks,
          key: Uint8List(16), // Wrong length
          chunkSize: encryptResult.chunkSize,
          originalPayloadSize: encryptResult.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('deriveKeyFromPassphrase', () {
    test('NC-09: should derive 32-byte key', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt,
      );
      expect(key.length, KEY_LENGTH_BYTES);
    });

    test('NC-10: same passphrase + salt should derive same key', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key1 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt,
      );
      final key2 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt,
      );
      expect(key1, equals(key2));
    });

    test('NC-11: different salt should derive different key', () async {
      final salt1 = Uint8List.fromList(List.generate(16, (i) => i));
      final salt2 = Uint8List.fromList(List.generate(16, (i) => i + 100));
      final key1 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt1,
      );
      final key2 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt2,
      );
      expect(key1, isNot(equals(key2)));
    });

    test('NC-12: different passphrase should derive different key', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key1 = await service.deriveKeyFromPassphrase(
        passphrase: 'Passphrase1',
        salt: salt,
      );
      final key2 = await service.deriveKeyFromPassphrase(
        passphrase: 'Passphrase2',
        salt: salt,
      );
      expect(key1, isNot(equals(key2)));
    });

    test('NC-13: derived key can encrypt/decrypt', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase123',
        salt: salt,
      );
      const content = '{"ops": [{"insert": "test with derived key"}]}';

      final encryptResult = await service.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key,
      );
      final decryptResult = await service.decrypt(
        chunks: encryptResult.chunks,
        key: key,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );
      expect(utf8.decode(decryptResult.payloadBytes), content);
    });

    test('NC-14: invalid salt length should throw CryptoException', () async {
      expect(
        () => service.deriveKeyFromPassphrase(
          passphrase: 'test',
          salt: Uint8List(8), // Wrong length
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('clearSensitiveData', () {
    test('should not throw', () {
      expect(() => service.clearSensitiveData(), returnsNormally);
    });
  });
}
