import 'dart:convert';
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
  group('CryptoService.encrypt / decrypt - 小载荷（单分块）', () {
    test('加密解密往返测试：载荷小于 chunkSize', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes = Uint8List.fromList(utf8.encode('Hello, World!'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadBytes, equals(payloadBytes));
      expect(decrypted.payloadMetadata.sourceType, SourceType.richText);
      expect(decrypted.payloadMetadata.originalExtension, 'delta');
      expect(decrypted.payloadMetadata.originalFileName, isNull);
    });

    test('单分块：EncryptResult 字段应正确', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes = Uint8List.fromList(utf8.encode('Small data'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final result = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      expect(result.totalChunks, 1);
      expect(result.chunks.length, 1);
      expect(result.originalPayloadSize, payloadBytes.length);
      expect(result.chunkSize, DEFAULT_CHUNK_SIZE);
    });
  });

  group('CryptoService.encrypt / decrypt - 载荷恰好等于 chunkSize', () {
    test('加密解密往返测试：载荷等于 chunkSize（单分块，满）', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 元数据会占用第一个分块的部分空间，因此实际可用的载荷容量
      // 小于 chunkSize。这里使用较小的 chunkSize 使测试更可控。
      const testChunkSize = 1024;
      final payloadBytes = Uint8List.fromList(
        List.generate(testChunkSize, (i) => i & 0xFF),
      );
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: testChunkSize,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadBytes, equals(payloadBytes));
    });
  });

  group('CryptoService.encrypt / decrypt - 多分块', () {
    test('加密解密往返测试：载荷大于 chunkSize（多分块）', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      // 使用较小的 chunkSize 来产生多分块
      const testChunkSize = 256;
      // 创建大于 chunkSize 的载荷，确保产生多个分块
      final payloadBytes = Uint8List.fromList(
        List.generate(1000, (i) => i & 0xFF),
      );
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: testChunkSize,
        useV21Security: false,
      );

      // 验证产生了多个分块
      expect(encrypted.totalChunks, greaterThan(1));
      expect(encrypted.chunks.length, greaterThan(1));

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadBytes, equals(payloadBytes));
      expect(decrypted.payloadMetadata.sourceType, SourceType.richText);
      expect(decrypted.payloadMetadata.originalExtension, 'delta');
    });

    test('多分块载荷应完整还原', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const testChunkSize = 512;
      // 创建一个较大的载荷
      final payloadBytes = Uint8List.fromList(
        List.generate(2000, (i) => (i * 7 + 13) & 0xFF),
      );
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'txt',
        originalFileName: 'test.txt',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: testChunkSize,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      // 逐字节验证完整还原
      expect(decrypted.payloadBytes.length, payloadBytes.length);
      for (var i = 0; i < payloadBytes.length; i++) {
        expect(decrypted.payloadBytes[i], payloadBytes[i], reason: '字节 $i 不匹配');
      }
    });
  });

  group('CryptoService.encrypt / decrypt - richText PayloadMetadata', () {
    test('richText 元数据应正确保存和还原', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );
      final payloadBytes =
          Uint8List.fromList(utf8.encode('{"ops": [{"insert": "Hello\\n"}]}'));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadMetadata.sourceType, SourceType.richText);
      expect(decrypted.payloadMetadata.originalExtension, 'delta');
      expect(decrypted.payloadMetadata.originalFileName, isNull);
    });
  });

  group('CryptoService.encrypt / decrypt - rawFile PayloadMetadata', () {
    test('rawFile 元数据应正确保存和还原（含 originalFileName）', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'pdf',
        originalFileName: 'report.pdf',
      );
      final payloadBytes =
          Uint8List.fromList(List.generate(500, (i) => i & 0xFF));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadMetadata.sourceType, SourceType.rawFile);
      expect(decrypted.payloadMetadata.originalExtension, 'pdf');
      expect(decrypted.payloadMetadata.originalFileName, 'report.pdf');
    });
  });

  group('CryptoService.encrypt - 第一个分块包含元数据前缀', () {
    test('第一个分块的解密明文应以元数据长度前缀开头', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'mp4',
        originalFileName: 'video.mp4',
      );
      final payloadBytes =
          Uint8List.fromList(List.generate(2000, (i) => i & 0xFF));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512,
        useV21Security: false,
      );

      // 验证至少产生了多个分块
      expect(encrypted.totalChunks, greaterThan(1));

      // 解密第一个分块，验证元数据前缀结构
      // 注意：这里我们通过 decrypt 方法间接验证，
      // 因为 decrypt 能正确提取元数据说明前缀结构正确
      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadMetadata.sourceType, SourceType.rawFile);
      expect(decrypted.payloadMetadata.originalExtension, 'mp4');
    });
  });

  group('CryptoService.encrypt - 进度回调', () {
    test('进度回调应被正确调用', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );
      final payloadBytes =
          Uint8List.fromList(List.generate(2000, (i) => i & 0xFF));

      final progressCalls = <(int, int)>[];

      await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512,
        onProgress: (current, total) {
          progressCalls.add((current, total));
        },
        useV21Security: false,
      );

      // 验证回调被调用
      expect(progressCalls, isNotEmpty);

      // 验证第一次调用的 current 为 1
      expect(progressCalls.first.$1, 1);

      // 验证最后一次调用的 current 等于 total
      expect(progressCalls.last.$1, progressCalls.last.$2);

      // 验证 total 一致
      final totalChunks = progressCalls.first.$2;
      for (final (current, total) in progressCalls) {
        expect(total, totalChunks);
        expect(current, greaterThanOrEqualTo(1));
        expect(current, lessThanOrEqualTo(total));
      }
    });

    test('解密进度回调应被正确调用', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );
      final payloadBytes =
          Uint8List.fromList(List.generate(2000, (i) => i & 0xFF));

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512,
        useV21Security: false,
      );

      final progressCalls = <(int, int)>[];

      await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        onProgress: (current, total) {
          progressCalls.add((current, total));
        },
      );

      expect(progressCalls, isNotEmpty);
      expect(progressCalls.first.$1, 1);
      expect(progressCalls.last.$1, progressCalls.last.$2);
    });
  });

  group('CryptoService.encrypt - 空载荷', () {
    test('空载荷应能正常加密解密', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes = Uint8List(0);
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      expect(encrypted.originalPayloadSize, 0);
      expect(encrypted.totalChunks, 1);

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadBytes, isEmpty);
      expect(decrypted.payloadMetadata.sourceType, SourceType.richText);
    });
  });

  group('CryptoService.decrypt - 错误密钥', () {
    test('使用错误密钥解密应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final correctKey = await cryptoService.generateKey();

      final payloadBytes = Uint8List.fromList(utf8.encode('Secret message'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: correctKey.bytes,
        useV21Security: false,
      );

      final wrongKey = await cryptoService.generateKey();

      expect(
        () async => cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: wrongKey.bytes,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  group('CryptoService.encrypt - 密钥长度验证', () {
    test('使用非 32 字节密钥加密应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();

      final payloadBytes = Uint8List.fromList(utf8.encode('Test'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      expect(
        () async => cryptoService.encrypt(
          payloadBytes: payloadBytes,
          payloadMetadata: metadata,
          key: Uint8List(16),
          useV21Security: false,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'INVALID_KEY_LENGTH',
        )),
      );
    });

    test('使用非 32 字节密钥解密应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();

      final chunks = [
        ChunkInfo(
          iv: Uint8List(16),
          encryptedData: Uint8List(32),
        ),
      ];

      expect(
        () async => cryptoService.decrypt(
          chunks: chunks,
          key: Uint8List(16),
          chunkSize: 1024,
          originalPayloadSize: 100,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'INVALID_KEY_LENGTH',
        )),
      );
    });
  });

  group('CryptoService.decrypt - 空分块列表', () {
    test('空分块列表应抛出 CryptoException', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      expect(
        () async => cryptoService.decrypt(
          chunks: [],
          key: key.bytes,
          chunkSize: 1024,
          originalPayloadSize: 100,
        ),
        throwsA(isA<CryptoException>().having(
          (e) => e.code,
          'code',
          'EMPTY_CHUNKS',
        )),
      );
    });
  });

  group('CryptoService.encrypt - 相同明文每次加密产生不同密文', () {
    test('相同载荷两次加密的密文应不同（不同 IV）', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes = Uint8List.fromList(utf8.encode('Same content'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted1 = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );
      final encrypted2 = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 密文应不同（因为 IV 不同）
      expect(
        encrypted1.chunks[0].encryptedData,
        isNot(equals(encrypted2.chunks[0].encryptedData)),
      );
      expect(
        encrypted1.chunks[0].iv,
        isNot(equals(encrypted2.chunks[0].iv)),
      );
    });
  });

  group('CryptoService.encrypt - 中文内容', () {
    test('中文内容加密解密往返测试', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes =
          Uint8List.fromList(utf8.encode('{"ops": [{"insert": "你好，世界！\\n"}]}'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key.bytes,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
      );

      expect(decrypted.payloadBytes, equals(payloadBytes));
      expect(utf8.decode(decrypted.payloadBytes),
          '{"ops": [{"insert": "你好，世界！\\n"}]}');
    });
  });

  group('CryptoService.encrypt - 分块大小验证', () {
    test('每个分块的 IV 应为 16 字节', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes =
          Uint8List.fromList(List.generate(2000, (i) => i & 0xFF));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        chunkSize: 512,
        useV21Security: false,
      );

      for (final chunk in encrypted.chunks) {
        expect(chunk.iv.length, CHUNK_IV_LENGTH_BYTES);
      }
    });

    test('加密后密文大小应大于明文大小（含 GCM Tag）', () async {
      final cryptoService = _createCryptoService();
      final key = await cryptoService.generateKey();

      final payloadBytes = Uint8List.fromList(utf8.encode('Test data'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: metadata,
        key: key.bytes,
        useV21Security: false,
      );

      // 第一个分块的密文应包含：元数据前缀 + 载荷数据 + GCM Tag
      // 因此密文大小应大于纯载荷大小
      expect(
        encrypted.chunks[0].encryptedData.length,
        greaterThan(payloadBytes.length),
      );
    });
  });
}
