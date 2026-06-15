import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/native/fallback_crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

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

  group('encryptContent/decryptContent', () {
    test('encrypt then decrypt should return original', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "Fallback test"}]}';

      final encrypted = await service.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      final decrypted = await service.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });

    test('wrong key should throw CryptoException', () async {
      final key1 = await service.generateKey();
      final key2 = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encrypted = await service.encryptContent(
        deltaJson: content,
        key: key1.bytes,
      );

      expect(
        () => service.decryptContent(
          encryptedDataBase64: encrypted.encryptedDataBase64,
          ivBase64: encrypted.ivBase64,
          key: key2.bytes,
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

      final encrypted = await service.encryptContent(
        deltaJson: content,
        key: key,
      );
      final decrypted = await service.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key,
      );
      expect(decrypted, content);
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
