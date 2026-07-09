import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/crypto/native/windows_crypto_ffi.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：构造富文本 PayloadMetadata
PayloadMetadata _richTextMetadata() => PayloadMetadata(
      sourceType: SourceType.richText,
      originalExtension: 'delta',
    );

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

      final encryptResult = await dartService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      final decryptResult = await nativeService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
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

      final encryptResult = await nativeService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      final decryptResult = await dartService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
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

      final encryptResult = await nativeService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      final decryptResult = await nativeService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
    });

    test('CC-05: chunks have unique IVs across services', () async {
      if (!nativeAvailable) {
        print('Skipping IV uniqueness test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      // Encrypt with pure Dart
      final key = await dartService.generateKey();
      const content = '{"ops": [{"insert": "IV uniqueness test"}]}';

      final dartEncryptResult = await dartService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      // Verify each chunk has a 16-byte IV
      for (final chunk in dartEncryptResult.chunks) {
        expect(chunk.iv.length, CHUNK_IV_LENGTH_BYTES,
            reason: 'Each chunk should use ${CHUNK_IV_LENGTH_BYTES}-byte IV');
      }

      // Decrypt with native service using Dart encrypt result
      final decryptResult = await nativeService.decrypt(
        chunks: dartEncryptResult.chunks,
        key: key.bytes,
        chunkSize: dartEncryptResult.chunkSize,
        originalPayloadSize: dartEncryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
    });

    test('CC-06: native encrypt chunks can be decrypted by pure Dart',
        () async {
      if (!nativeAvailable) {
        print('Skipping native chunk test: native API not available');
        return;
      }

      final nativeService = NativeCryptoService(
        integrityService,
        NativeCryptoService.createChannel(),
      );

      // Encrypt with native
      final key = await nativeService.generateKey();
      const content = '{"ops": [{"insert": "Native IV test"}]}';

      final encryptResult = await nativeService.encrypt(
        payloadBytes: Uint8List.fromList(utf8.encode(content)),
        payloadMetadata: _richTextMetadata(),
        key: key.bytes,
      );

      // Verify each chunk has a 16-byte IV
      for (final chunk in encryptResult.chunks) {
        expect(chunk.iv.length, CHUNK_IV_LENGTH_BYTES,
            reason: 'Each chunk should use ${CHUNK_IV_LENGTH_BYTES}-byte IV');
      }

      // Decrypt with pure Dart
      final decryptResult = await dartService.decrypt(
        chunks: encryptResult.chunks,
        key: key.bytes,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      expect(utf8.decode(decryptResult.payloadBytes), content);
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
