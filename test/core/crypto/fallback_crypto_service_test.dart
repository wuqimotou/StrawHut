import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';
import 'package:strawhut/core/crypto/native/fallback_crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：构造富文本 PayloadMetadata
PayloadMetadata _richTextMetadata() => PayloadMetadata(
      sourceType: SourceType.richText,
      originalExtension: 'delta',
    );

void main() {
  late FallbackCryptoService service;

  setUp(() async {
    final integrityService = IntegrityService();
    service = FallbackCryptoService(integrityService);
    await service.initialize();
  });

  group('initialization', () {
    test('should initialize successfully', () async {
      final integrityService = IntegrityService();
      final newService = FallbackCryptoService(integrityService);
      await newService.initialize();
      expect(newService.delegateTypeName, isNotEmpty);
    });

    test('should use a valid delegate type', () async {
      // On supported platforms, may use NativeCryptoService or CryptoService
      // (if FFI probe fails, it correctly falls back to CryptoService)
      expect(
        service.delegateTypeName,
        anyOf('NativeCryptoService', 'CryptoService'),
        reason: 'Should use a valid crypto service delegate',
      );
    });

    test('initialize is idempotent', () async {
      final integrityService = IntegrityService();
      final newService = FallbackCryptoService(integrityService);
      await newService.initialize();
      final typeName1 = newService.delegateTypeName;
      await newService.initialize();
      final typeName2 = newService.delegateTypeName;
      expect(typeName1, equals(typeName2));
    });
  });

  group('generateKey', () {
    test('should return 32-byte key', () async {
      final key = await service.generateKey();
      expect(key.bytes.length, KEY_LENGTH_BYTES);
      expect(key.base64, isNotEmpty);
    });
  });

  group('encrypt/decrypt', () {
    test('encrypt then decrypt should return original', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "Fallback test"}]}';

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

    test('wrong key should throw CryptoException', () async {
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
  });

  group('deriveKeyFromPassphrase', () {
    test('should derive 32-byte key', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase',
        salt: salt,
      );
      expect(key.length, KEY_LENGTH_BYTES);
    });

    test('same input should produce same key', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key1 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase',
        salt: salt,
      );
      final key2 = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase',
        salt: salt,
      );
      expect(key1, equals(key2));
    });

    test('derived key can encrypt/decrypt', () async {
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      final key = await service.deriveKeyFromPassphrase(
        passphrase: 'TestPassphrase',
        salt: salt,
      );
      const content = '{"ops": [{"insert": "Derived key test"}]}';

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

    test('invalid salt length should throw CryptoException', () async {
      expect(
        () => service.deriveKeyFromPassphrase(
          passphrase: 'test',
          salt: Uint8List(8),
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
