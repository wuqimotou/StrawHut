import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/crypto/native/windows_crypto_ffi.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

void main() {
  // Only run on supported platforms
  if (!NativeCryptoService.isNativeSupported) {
    print('Skipping NativeCryptoService tests: platform not supported');
    return;
  }

  // On Windows, verify BCrypt API is actually available in the test environment.
  // flutter test runs in a sandboxed Dart VM that may not have access to
  // Windows BCrypt APIs. In that case, skip all native tests.
  if (Platform.isWindows) {
    try {
      WindowsCryptoFfi.generateRandom(1);
    } catch (e) {
      print(
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

  group('encryptContent/decryptContent', () {
    test(
      'NC-03: encrypt then decrypt should return original content',
      () async {
        final key = await service.generateKey();
        const content = '{"ops": [{"insert": "Hello World"}]}';

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
      },
    );

    test('NC-04: encrypt/decrypt Chinese content', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "你好世界，测试中文内容"}]}';

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

    test('NC-05: encrypt/decrypt empty string', () async {
      final key = await service.generateKey();
      const content = '';

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

    test('NC-06: same plaintext should produce different ciphertext', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encrypted1 = await service.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );
      final encrypted2 = await service.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      // IV should be different (random)
      expect(encrypted1.ivBase64, isNot(equals(encrypted2.ivBase64)));
      // Ciphertext should be different
      expect(
        encrypted1.encryptedDataBase64,
        isNot(equals(encrypted2.encryptedDataBase64)),
      );
    });

    test('NC-07: wrong key should throw CryptoException', () async {
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

    test('NC-08: tampered ciphertext should throw CryptoException', () async {
      final key = await service.generateKey();
      const content = '{"ops": [{"insert": "test"}]}';

      final encrypted = await service.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      // Tamper with ciphertext
      final ciphertextBytes = base64Decode(encrypted.encryptedDataBase64);
      ciphertextBytes[0] ^= 0xFF; // Flip first byte

      expect(
        () => service.decryptContent(
          encryptedDataBase64: base64Encode(ciphertextBytes),
          ivBase64: encrypted.ivBase64,
          key: key.bytes,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('NC-15: invalid key length should throw CryptoException', () async {
      const content = '{"ops": [{"insert": "test"}]}';
      final encrypted = await service.encryptContent(
        deltaJson: content,
        key: (await service.generateKey()).bytes,
      );

      expect(
        () => service.decryptContent(
          encryptedDataBase64: encrypted.encryptedDataBase64,
          ivBase64: encrypted.ivBase64,
          key: Uint8List(16), // Wrong length
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
