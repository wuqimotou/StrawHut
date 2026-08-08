// 加密场景测试矩阵 — 补缺测试
//
// 覆盖现有测试中缺失的场景组合：
// - v2.1 + 暗号 + 内存加解密
// - v2.1 + 暗号 + 流式加解密
// - v2.1 + 流式取消
// - v2.1 + 大文件（多分块）流式加解密
// - v2.0 加密 → v2.1 解密尝试（应失败）
// - v2.1 加密 → v2.0 解密尝试（应失败）
// - 暗号 + 流式加解密往返

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';

CryptoService _createCryptoService() => CryptoService(IntegrityService());

Uint8List _saltFromString(String s) {
  final bytes = utf8.encode(s);
  // 截断或填充到 16 字节
  if (bytes.length >= 16) return Uint8List.fromList(bytes.sublist(0, 16));
  return Uint8List.fromList([...bytes, ...List.filled(16 - bytes.length, 0)]);
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crypto_matrix_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ===========================================================================
  // v2.1 + 暗号 + 内存加解密
  // ===========================================================================
  group('v2.1 暗号内存加解密', () {
    test('v2.1 暗号派生密钥加解密往返', () async {
      final cryptoService = _createCryptoService();
      const passphrase = '测试暗号v2.1';
      final salt = _saltFromString('固定盐值矩阵测试');
      final payload = Uint8List.fromList(utf8.encode('v2.1 passphrase payload'));

      final key = await cryptoService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        ),
        key: key,
        useV21Security: true,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      expect(decrypted.payloadBytes, equals(payload));
    });

    test('v2.1 暗号 + 错误暗号应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      const correctPassphrase = '正确暗号';
      const wrongPassphrase = '错误暗号';
      final salt = _saltFromString('矩阵测试盐值');
      final payload = Uint8List.fromList(utf8.encode('secret data'));

      final correctKey = await cryptoService.deriveKeyFromPassphrase(
        passphrase: correctPassphrase,
        salt: salt,
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'txt',
        ),
        key: correctKey,
        useV21Security: true,
      );

      final wrongKey = await cryptoService.deriveKeyFromPassphrase(
        passphrase: wrongPassphrase,
        salt: salt,
      );

      expect(
        () => cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: wrongKey,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: true,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  // ===========================================================================
  // v2.1 + 暗号 + 流式加解密
  // ===========================================================================
  group('v2.1 暗号流式加解密', () {
    test('v2.1 暗号派生密钥流式加解密往返', () async {
      final cryptoService = _createCryptoService();
      const passphrase = '流式暗号测试';
      final salt = _saltFromString('流式盐值');

      final key = await cryptoService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
      );

      final sourceFile = File('${tempDir.path}/v21_passphrase_stream.txt');
      const testContent = 'v2.1 passphrase stream encryption test data';
      await sourceFile.writeAsString(testContent);

      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'txt',
          originalFileName: 'v21_passphrase_stream.txt',
        ),
        key: key,
        useV21Security: true,
      );

      expect(encrypted.totalChunks, 1);

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: const CardMeta(
          publisherAlias: 'tester',
          publishDate: '2026-08-08T00:00:00Z',
          title: 'v2.1 passphrase stream',
          isAnonymous: false,
        ),
        content: StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: encrypted.chunkSize,
          totalChunks: encrypted.totalChunks,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        integrity: const IntegrityInfo(
          hash: 'sha256:test',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final strawPath = '${tempDir.path}/v21_passstream.straw';
      final strawBytes = FileIOService().buildBinaryFileBytes(
        strawFile: strawFile,
        chunks: encrypted.chunks,
      );
      await File(strawPath).writeAsBytes(strawBytes);

      final targetPath = '${tempDir.path}/v21_passstream_decrypted.txt';
      await cryptoService.decryptStream(
        strawFilePath: strawPath,
        key: key,
        targetPath: targetPath,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      final decrypted = await File(targetPath).readAsBytes();
      expect(decrypted, equals(utf8.encode(testContent)));
    });
  });

  // ===========================================================================
  // v2.1 + 流式取消
  // ===========================================================================
  group('v2.1 流式解密取消', () {
    test('v2.1 流式解密中途取消应抛出 OperationCancelledException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payload = Uint8List.fromList(
        List<int>.generate(4096, (i) => i % 256),
      );
      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'bin',
        ),
        key: key.bytes,
        chunkSize: 256,
        useV21Security: true,
      );

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: const CardMeta(
          publisherAlias: 'tester',
          publishDate: '2026-08-08T00:00:00Z',
          title: 'v2.1 cancel test',
          isAnonymous: false,
        ),
        content: StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: encrypted.chunkSize,
          totalChunks: encrypted.totalChunks,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        integrity: const IntegrityInfo(
          hash: 'sha256:test',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final sourcePath = '${tempDir.path}/v21_cancel.straw';
      final targetPath = '${tempDir.path}/v21_cancel_plain.bin';
      final sourceBytes = FileIOService().buildBinaryFileBytes(
        strawFile: strawFile,
        chunks: encrypted.chunks,
      );
      await File(sourcePath).writeAsBytes(sourceBytes);

      final token = CancellationToken();
      await expectLater(
        cryptoService.decryptStream(
          strawFilePath: sourcePath,
          key: key.bytes,
          targetPath: targetPath,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: true,
          cancellationToken: token,
          onProgress: (current, total) {
            if (current == 1) token.cancel();
          },
        ),
        throwsA(isA<OperationCancelledException>()),
      );

      expect(await File(targetPath).exists(), isFalse);
      expect(await File(sourcePath).readAsBytes(), sourceBytes);
    });
  });

  // ===========================================================================
  // v2.1 + 大文件（多分块）流式加解密
  // ===========================================================================
  group('v2.1 大文件流式加解密', () {
    test('v2.1 大文件流式加解密往返应保持数据完整性', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final largeData = Uint8List.fromList(
        List<int>.generate(2 * 1024 * 1024, (i) => i % 256),
      );
      final sourceFile = File('${tempDir.path}/large_v21.bin');
      await sourceFile.writeAsBytes(largeData);

      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'bin',
          originalFileName: 'large_v21.bin',
        ),
        key: key.bytes,
        useV21Security: true,
      );

      expect(encrypted.totalChunks, greaterThan(1));

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: const CardMeta(
          publisherAlias: 'tester',
          publishDate: '2026-08-08T00:00:00Z',
          title: 'large v2.1',
          isAnonymous: false,
        ),
        content: StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: encrypted.chunkSize,
          totalChunks: encrypted.totalChunks,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        integrity: const IntegrityInfo(
          hash: 'sha256:test',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final strawPath = '${tempDir.path}/large_v21.straw';
      final strawBytes = FileIOService().buildBinaryFileBytes(
        strawFile: strawFile,
        chunks: encrypted.chunks,
      );
      await File(strawPath).writeAsBytes(strawBytes);

      final targetPath = '${tempDir.path}/large_v21_decrypted.bin';
      await cryptoService.decryptStream(
        strawFilePath: strawPath,
        key: key.bytes,
        targetPath: targetPath,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      final decrypted = await File(targetPath).readAsBytes();
      expect(decrypted.length, largeData.length);
      expect(decrypted, equals(largeData));
    });
  });

  // ===========================================================================
  // v2.0 / v2.1 跨版本不兼容性
  // ===========================================================================
  group('v2.0 v2.1 跨版本不兼容性', () {
    test('v2.0 加密的数据用 v2.1 解密应失败', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('cross version test'));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        ),
        key: key,
        useV21Security: false,
      );

      expect(
        () => cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: key,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: true,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('v2.1 加密的数据用 v2.0 解密应失败', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('cross version test'));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        ),
        key: key,
        useV21Security: true,
      );

      expect(
        () => cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: key,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: false,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  // ===========================================================================
  // 暗号 + 流式加解密往返（v2.0）
  // ===========================================================================
  group('v2.0 暗号流式加解密', () {
    test('v2.0 暗号派生密钥流式加解密往返', () async {
      final cryptoService = _createCryptoService();
      const passphrase = '流式暗号v2.0';
      final salt = _saltFromString('v2.0流式盐值');

      final key = await cryptoService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
      );

      final sourceFile = File('${tempDir.path}/v20_passstream.txt');
      const testContent = 'v2.0 passphrase stream test';
      await sourceFile.writeAsString(testContent);

      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'txt',
          originalFileName: 'v20_passstream.txt',
        ),
        key: key,
        useV21Security: false,
      );

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 0, 0),
        meta: const CardMeta(
          publisherAlias: 'tester',
          publishDate: '2026-08-08T00:00:00Z',
          title: 'v2.0 passphrase stream',
          isAnonymous: false,
        ),
        content: StrawContent(
          encryptionAlgorithm: 'AES-256-GCM',
          chunkSize: encrypted.chunkSize,
          totalChunks: encrypted.totalChunks,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        integrity: const IntegrityInfo(
          hash: 'sha256:test',
          hashAlgorithm: 'SHA-256',
        ),
      );

      final strawPath = '${tempDir.path}/v20_passstream.straw';
      final strawBytes = FileIOService().buildBinaryFileBytes(
        strawFile: strawFile,
        chunks: encrypted.chunks,
      );
      await File(strawPath).writeAsBytes(strawBytes);

      final targetPath = '${tempDir.path}/v20_passstream_decrypted.txt';
      await cryptoService.decryptStream(
        strawFilePath: strawPath,
        key: key,
        targetPath: targetPath,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: false,
      );

      final decrypted = await File(targetPath).readAsBytes();
      expect(decrypted, equals(utf8.encode(testContent)));
    });
  });

  // ===========================================================================
  // v2.1 多分块内存加解密（小 chunkSize 模拟）
  // ===========================================================================
  group('v2.1 多分块内存加解密', () {
    test('v2.1 多分块加解密往返应保持数据完整性', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payload = Uint8List.fromList(
        List<int>.generate(2048, (i) => i % 256),
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'bin',
        ),
        key: key.bytes,
        chunkSize: 256,
        useV21Security: true,
      );

      expect(encrypted.totalChunks, greaterThan(1));

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      expect(decrypted.payloadBytes, equals(payload));
    });

    test('v2.1 多分块密文篡改应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payload = Uint8List.fromList(
        List<int>.generate(2048, (i) => i % 256),
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: const PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: 'bin',
        ),
        key: key.bytes,
        chunkSize: 256,
        useV21Security: true,
      );

      final tamperedChunks = List<ChunkInfo>.from(encrypted.chunks);
      if (tamperedChunks.length > 1) {
        final originalData = tamperedChunks[1].encryptedData;
        final tamperedData = Uint8List.fromList(originalData);
        tamperedData[0] ^= 0xFF;
        tamperedChunks[1] = ChunkInfo(
          iv: tamperedChunks[1].iv,
          encryptedData: tamperedData,
        );
      }

      expect(
        () => cryptoService.decrypt(
          chunks: tamperedChunks,
          key: key.bytes,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: true,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });
}
