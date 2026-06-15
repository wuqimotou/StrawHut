import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/crypto/native/windows_crypto_ffi.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

void main() {
  late CryptoService dartService;
  late IntegrityService integrityService;

  /// Whether native crypto APIs are actually available in this test environment.
  /// On Windows, flutter test runs in a sandboxed Dart VM that may not have
  /// access to BCrypt APIs, so we probe at startup.
  late final bool nativeAvailable;

  setUp(() {
    integrityService = IntegrityService();
    dartService = CryptoService(integrityService);
  });

  // One-time probe for native API availability
  nativeAvailable = () {
    if (!NativeCryptoService.isNativeSupported) return false;
    if (Platform.isWindows) {
      try {
        WindowsCryptoFfi.generateRandom(1);
        return true;
      } catch (_) {
        return false;
      }
    }
    // Android: assume available (MethodChannel won't work in test, but
    // the skip logic below handles that)
    return true;
  }();

  group('PBKDF2 output consistency', () {
    test('CC-04: native PBKDF2 should match pure Dart PBKDF2', () async {
      if (!nativeAvailable) {
        print('Skipping PBKDF2 compatibility test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      const passphrase = 'TestPassphrase123';
      final salt = Uint8List.fromList(List.generate(16, (i) => i));
      const iterations = 100000;

      final dartKey = await dartService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
      );

      Uint8List nativeKey;
      try {
        nativeKey = await nativeService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
          iterations: iterations,
        );
      } on UnsupportedError {
        print('Skipping: native PBKDF2 not supported on this platform');
        return;
      }

      expect(
        nativeKey,
        equals(dartKey),
        reason: 'PBKDF2 outputs must be identical',
      );
    });
  });

  group('Cross-implementation encrypt/decrypt', () {
    test('CC-01: pure Dart encrypt -> native decrypt', () async {
      if (!nativeAvailable) {
        print('Skipping cross-implementation test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      final key = await dartService.generateKey();
      const content = '{"ops": [{"insert": "Cross-implementation test"}]}';

      final encrypted = await dartService.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      final decrypted = await nativeService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });

    test('CC-02: native encrypt -> pure Dart decrypt', () async {
      if (!nativeAvailable) {
        print('Skipping cross-implementation test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      final key = await nativeService.generateKey();
      const content = '{"ops": [{"insert": "Cross-implementation test"}]}';

      final encrypted = await nativeService.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      final decrypted = await dartService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });

    test('CC-03: native encrypt -> native decrypt', () async {
      if (!nativeAvailable) {
        print('Skipping native-only test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      final key = await nativeService.generateKey();
      const content = '{"ops": [{"insert": "Native round-trip test"}]}';

      final encrypted = await nativeService.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      final decrypted = await nativeService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });

    test('CC-05: native decrypt supports 16-byte IV (legacy)', () async {
      if (!nativeAvailable) {
        print('Skipping legacy IV test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      // Encrypt with pure Dart (which uses 16-byte IV)
      final key = await dartService.generateKey();
      const content = '{"ops": [{"insert": "Legacy IV test"}]}';

      final encrypted = await dartService.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      // Verify the IV is 16 bytes (from pure Dart implementation)
      final ivBytes = base64Decode(encrypted.ivBase64);
      expect(ivBytes.length, 16, reason: 'Pure Dart should use 16-byte IV');

      // Decrypt with native service
      final decrypted = await nativeService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });

    test('CC-06: pure Dart decrypt supports 12-byte IV (native)', () async {
      if (!nativeAvailable) {
        print('Skipping native IV test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      // Encrypt with native (which uses 12-byte IV)
      final key = await nativeService.generateKey();
      const content = '{"ops": [{"insert": "Native IV test"}]}';

      final encrypted = await nativeService.encryptContent(
        deltaJson: content,
        key: key.bytes,
      );

      // Verify the IV is 12 bytes (from native implementation)
      final ivBytes = base64Decode(encrypted.ivBase64);
      expect(ivBytes.length, 12, reason: 'Native should use 12-byte IV');

      // Decrypt with pure Dart
      final decrypted = await dartService.decryptContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        key: key.bytes,
      );

      expect(decrypted, content);
    });
  });

  group('SHA-256 output consistency', () {
    test('CC-07: integrity service hash is consistent', () {
      const content = '{"test": "data"}';
      final hash1 = integrityService.computeHash(content);
      final hash2 = integrityService.computeHash(content);
      expect(hash1, equals(hash2));
    });
  });
}
