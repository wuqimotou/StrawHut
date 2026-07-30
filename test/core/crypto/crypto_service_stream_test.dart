import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/crypto/crypto_models/encrypt_result.dart';
import 'package:strawhut/core/crypto/crypto_models/payload_metadata.dart';
import 'package:strawhut/core/crypto/crypto_models/source_type.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：创建 CryptoService 测试实例
CryptoService _createCryptoService() => CryptoService(IntegrityService());

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crypto_stream_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('CryptoService.encryptStream', () {
    test('流式加密小文件应产生单个分块', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 创建测试文件
      final sourceFile = File('${tempDir.path}/small.txt');
      final testContent = 'Hello, Stream Encryption!';
      await sourceFile.writeAsString(testContent);

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'txt',
        originalFileName: 'small.txt',
      );

      final result = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 验证加密结果
      expect(result, isA<EncryptResult>());
      expect(result.totalChunks, 1);
      expect(result.chunks.length, 1);
      expect(result.originalPayloadSize, testContent.length);
      expect(result.chunkSize, DEFAULT_CHUNK_SIZE);

      // 验证分块结构
      expect(result.chunks[0].iv.length, CHUNK_IV_LENGTH_BYTES);
      expect(result.chunks[0].encryptedData.isNotEmpty, true);
    });

    test('流式加密大文件应产生多个分块', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 创建较大的测试文件（2MB）
      final sourceFile = File('${tempDir.path}/large.bin');
      final largeData = Uint8List(2 * 1024 * 1024);
      for (var i = 0; i < largeData.length; i++) {
        largeData[i] = i & 0xFF;
      }
      await sourceFile.writeAsBytes(largeData);

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
        originalFileName: 'large.bin',
      );

      final result = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512 * 1024, // 512KB chunks
        useV21Security: false,
      );

      // 验证产生了多个分块
      expect(result.totalChunks, greaterThan(1));
      expect(result.chunks.length, greaterThan(1));
      expect(result.originalPayloadSize, largeData.length);

      // 验证每个分块都有正确的 IV 长度
      for (final chunk in result.chunks) {
        expect(chunk.iv.length, CHUNK_IV_LENGTH_BYTES);
        expect(chunk.encryptedData.isNotEmpty, true);
      }
    });

    test('流式加密不存在的文件应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'txt',
      );

      expect(
        () async => cryptoService.encryptStream(
          sourcePath: '${tempDir.path}/nonexistent.txt',
          payloadMetadata: metadata,
          key: key.bytes,
          useV21Security: false,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'FILE_NOT_FOUND',
        )),
      );
    });

    test('流式加密应支持进度回调', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final sourceFile = File('${tempDir.path}/progress.txt');
      await sourceFile.writeAsString('Test content for progress callback');

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'txt',
      );

      final progressCalls = <(int, int)>[];

      await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key.bytes,
        onProgress: (current, total) {
          progressCalls.add((current, total));
        },
        useV21Security: false,
      );

      // 验证进度回调被调用
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.first.$1, 1);
      expect(progressCalls.last.$1, progressCalls.last.$2);
    });

    test('流式加密与非流式加密应产生相同的结果结构', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final testContent = 'Identical content for both methods';
      final payloadBytes = Uint8List.fromList(utf8.encode(testContent));

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      // 非流式加密
      final nonStreamResult = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 流式加密
      final sourceFile = File('${tempDir.path}/stream.txt');
      await sourceFile.writeAsString(testContent);

      final streamResult = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 验证结果结构相同
      expect(streamResult.totalChunks, nonStreamResult.totalChunks);
      expect(streamResult.chunkSize, nonStreamResult.chunkSize);
      expect(streamResult.originalPayloadSize,
          nonStreamResult.originalPayloadSize);
      expect(streamResult.chunks.length, nonStreamResult.chunks.length);
    });
  });

  group('CryptoService.decryptStream', () {
    test('流式解密应正确还原小文件', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 准备测试数据
      final originalContent = 'Hello, Stream Decryption!';
      final payloadBytes = Uint8List.fromList(utf8.encode(originalContent));

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      // 加密数据
      final encryptResult = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 构建 .straw 二进制文件
      final strawFile = File('${tempDir.path}/test.straw');
      await _writeStrawBinaryFile(
        strawFile,
        encryptResult,
        metadata,
      );

      // 流式解密
      final targetPath = '${tempDir.path}/decrypted.txt';
      final result = await cryptoService.decryptStream(
        strawFilePath: strawFile.path,
        key: key.bytes,
        targetPath: targetPath,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      // 验证解密结果
      expect(result.targetPath, targetPath);
      expect(result.payloadMetadata.sourceType, metadata.sourceType);
      expect(
          result.payloadMetadata.originalExtension, metadata.originalExtension);

      // 验证文件内容
      final decryptedFile = File(targetPath);
      expect(await decryptedFile.exists(), true);
      final decryptedContent = await decryptedFile.readAsString();
      expect(decryptedContent, originalContent);
    });

    test('流式解密应正确还原大文件', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 准备较大的测试数据（1.5MB）
      final largeData = Uint8List(1536 * 1024);
      for (var i = 0; i < largeData.length; i++) {
        largeData[i] = (i * 7 + 13) & 0xFF;
      }

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
        originalFileName: 'large.bin',
      );

      // 加密数据
      final encryptResult = await cryptoService.encrypt(
        payloadBytes: largeData,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512 * 1024,
        useV21Security: false,
      );

      // 构建 .straw 二进制文件
      final strawFile = File('${tempDir.path}/large.straw');
      await _writeStrawBinaryFile(
        strawFile,
        encryptResult,
        metadata,
      );

      // 流式解密
      final targetPath = '${tempDir.path}/large_decrypted.bin';
      final result = await cryptoService.decryptStream(
        strawFilePath: strawFile.path,
        key: key.bytes,
        targetPath: targetPath,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      // 验证文件内容
      final decryptedFile = File(targetPath);
      final decryptedData = await decryptedFile.readAsBytes();

      expect(decryptedData.length, largeData.length);
      for (var i = 0; i < largeData.length; i++) {
        expect(decryptedData[i], largeData[i],
            reason: 'Byte mismatch at index $i');
      }
    });

    test('流式解密不存在的文件应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      expect(
        () async => cryptoService.decryptStream(
          strawFilePath: '${tempDir.path}/nonexistent.straw',
          key: key.bytes,
          targetPath: '${tempDir.path}/output.txt',
          chunkSize: DEFAULT_CHUNK_SIZE,
          originalPayloadSize: 100,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'FILE_NOT_FOUND',
        )),
      );
    });

    test('流式解密应支持进度回调', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final testContent = 'Test content for stream decryption progress';
      final payloadBytes = Uint8List.fromList(utf8.encode(testContent));

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encryptResult = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      final strawFile = File('${tempDir.path}/progress.straw');
      await _writeStrawBinaryFile(
        strawFile,
        encryptResult,
        metadata,
      );

      final progressCalls = <(int, int)>[];

      await cryptoService.decryptStream(
        strawFilePath: strawFile.path,
        key: key.bytes,
        targetPath: '${tempDir.path}/progress_decrypted.txt',
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
        onProgress: (current, total) {
          progressCalls.add((current, total));
        },
      );

      // 验证进度回调被调用
      expect(progressCalls, isNotEmpty);
      expect(progressCalls.first.$1, 1);
      expect(progressCalls.last.$1, progressCalls.last.$2);
    });
  });

  group('CryptoService 流式加密/解密往返测试', () {
    test('流式加密后流式解密应完全还原原始数据', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 准备测试数据
      final originalData = Uint8List(100 * 1024); // 100KB
      for (var i = 0; i < originalData.length; i++) {
        originalData[i] = i & 0xFF;
      }

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
        originalFileName: 'roundtrip.bin',
      );

      // 写入源文件
      final sourceFile = File('${tempDir.path}/roundtrip_source.bin');
      await sourceFile.writeAsBytes(originalData);

      // 流式加密
      final encryptResult = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 构建 .straw 二进制文件
      final strawFile = File('${tempDir.path}/roundtrip.straw');
      await _writeStrawBinaryFile(
        strawFile,
        encryptResult,
        metadata,
      );

      // 流式解密
      final targetPath = '${tempDir.path}/roundtrip_decrypted.bin';
      await cryptoService.decryptStream(
        strawFilePath: strawFile.path,
        key: key.bytes,
        targetPath: targetPath,
        chunkSize: encryptResult.chunkSize,
        originalPayloadSize: encryptResult.originalPayloadSize,
      );

      // 验证数据完全还原
      final decryptedFile = File(targetPath);
      final decryptedData = await decryptedFile.readAsBytes();

      expect(decryptedData.length, originalData.length);
      for (var i = 0; i < originalData.length; i++) {
        expect(decryptedData[i], originalData[i],
            reason: 'Mismatch at byte $i');
      }
    });
  });
}

/// 辅助函数：构建并写入 .straw 二进制文件
///
/// 按照 StrawHut 二进制格式写入：
/// - Magic Bytes (8B)
/// - Version Major (2B) + Version Minor (2B)
/// - Header Size (4B)
/// - JSON Header (variable)
/// - Chunks (variable)
Future<void> _writeStrawBinaryFile(
  File file,
  EncryptResult encryptResult,
  PayloadMetadata metadata,
) async {
  final builder = BytesBuilder();

  // 1. Magic Bytes: "STRAWHUT"
  builder.add(STRAW_MAGIC_BYTES);

  // 2. Format Version Major (2 bytes uint16 LE)
  builder.addByte(BINARY_FORMAT_MAJOR & 0xFF);
  builder.addByte((BINARY_FORMAT_MAJOR >> 8) & 0xFF);

  // 3. Format Version Minor (2 bytes uint16 LE)
  builder.addByte(BINARY_FORMAT_MINOR & 0xFF);
  builder.addByte((BINARY_FORMAT_MINOR >> 8) & 0xFF);

  // 4. JSON Header
  final headerJson = {
    'format_version': '2.0.0',
    'meta': {
      'publisher_alias': 'Test',
      'publish_date': '2026-01-01T00:00:00Z',
      'title': 'Test',
      'is_anonymous': true,
      'tags': ['test'],
    },
    'content': {
      'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
      'chunk_size': encryptResult.chunkSize,
      'total_chunks': encryptResult.totalChunks,
      'original_payload_size': encryptResult.originalPayloadSize,
    },
    'integrity': {
      'hash': '',
      'hash_algorithm': HASH_ALGORITHM_SHA256,
    },
  };

  final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerJson)));

  // 5. Header Size (4 bytes uint32 LE)
  builder.addByte(headerBytes.length & 0xFF);
  builder.addByte((headerBytes.length >> 8) & 0xFF);
  builder.addByte((headerBytes.length >> 16) & 0xFF);
  builder.addByte((headerBytes.length >> 24) & 0xFF);

  // 6. JSON Header bytes
  builder.add(headerBytes);

  // 7. Chunks
  for (final chunk in encryptResult.chunks) {
    // Chunk IV (16 bytes)
    builder.add(chunk.iv);

    // Chunk Data Size (4 bytes uint32 LE)
    builder.addByte(chunk.encryptedData.length & 0xFF);
    builder.addByte((chunk.encryptedData.length >> 8) & 0xFF);
    builder.addByte((chunk.encryptedData.length >> 16) & 0xFF);
    builder.addByte((chunk.encryptedData.length >> 24) & 0xFF);

    // Encrypted Data
    builder.add(chunk.encryptedData);
  }

  await file.writeAsBytes(builder.toBytes());
}
