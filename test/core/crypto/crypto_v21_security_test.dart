// v2.1 容器认证安全特性测试
//
// 覆盖范围：
// - GCM AAD 绑定（分块序号 + 总数）的加解密往返
// - HMAC 密钥派生（从加密密钥派生 HMAC 密钥）
// - HMAC-SHA256 完整性校验
// - v2.0 与 v2.1 的不兼容性验证（AAD 不匹配应解密失败）
// - 长度字段上限校验（DoS 防护）
// - v2.1 流式加解密往返

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';

/// 辅助函数：创建 CryptoService 测试实例
CryptoService _createCryptoService() => CryptoService(IntegrityService());

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('crypto_v21_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  // ===========================================================================
  // v2.1 AAD 加解密往返
  // ===========================================================================

  group('v2.1 AAD 加解密往返', () {
    test('v2.1 加密后用 useV21Security=true 解密应还原原始数据', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('Hello v2.1 Security!'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      expect(decrypted.payloadBytes, equals(payload));
      expect(decrypted.payloadMetadata.sourceType, equals(SourceType.richText));
    });

    test('v2.1 多分块加解密应正确还原', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i + 10));
      // 使用很小的 chunkSize 强制多分块
      const chunkSize = 100;
      final payload = Uint8List.fromList(
        List.generate(500, (i) => i % 256),
      );
      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
        chunkSize: chunkSize,
      );

      expect(encrypted.totalChunks, greaterThan(1));

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      expect(decrypted.payloadBytes, equals(payload));
    });

    test('v2.1 加密后用 useV21Security=false 解密应失败（AAD 不匹配）', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('AAD mismatch test'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
      );

      // 用 v2.0 模式解密 v2.1 加密的数据，应因 AAD 不匹配而失败
      expect(
        () => cryptoService.decrypt(
          chunks: encrypted.chunks,
          key: key,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('v2.0 加密后用 useV21Security=true 解密应失败（AAD 不匹配）', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('v2.0 data'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
        useV21Security: false,
      );

      // 用 v2.1 模式解密 v2.0 加密的数据，应因 AAD 不匹配而失败
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

    test('v2.1 密文长度与 v2.0 相同（AAD 不影响 GCM 密文长度）', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(utf8.encode('same payload'));
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      // 注意：由于 IV 随机生成，即使同一模式两次加密结果也不同
      // 这里验证的是 v2.1 密文长度与 v2.0 相同（AAD 不影响 GCM 密文长度）
      final v20Encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
        useV21Security: false,
      );

      final v21Encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
      );

      // 密文长度应相同（GCM 的 AAD 不影响密文长度，只影响认证标签）
      expect(
        v21Encrypted.chunks[0].encryptedData.length,
        equals(v20Encrypted.chunks[0].encryptedData.length),
      );
    });

    test('v2.1 空载荷加解密应正确处理', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List(0);
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
      );

      final decrypted = await cryptoService.decrypt(
        chunks: encrypted.chunks,
        key: key,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      expect(decrypted.payloadBytes, equals(payload));
      expect(decrypted.payloadBytes.length, equals(0));
    });
  });

  // ===========================================================================
  // HMAC 密钥派生
  // ===========================================================================

  group('HMAC 密钥派生', () {
    test('deriveHmacKey 应返回 32 字节密钥', () {
      final cryptoService = _createCryptoService();
      final encryptionKey = Uint8List.fromList(List.generate(32, (i) => i));
      final hmacKey = cryptoService.deriveHmacKey(encryptionKey);

      expect(hmacKey.length, equals(32));
    });

    test('相同加密密钥应派生出相同的 HMAC 密钥', () {
      final cryptoService = _createCryptoService();
      final encryptionKey = Uint8List.fromList(List.generate(32, (i) => i));

      final hmacKey1 = cryptoService.deriveHmacKey(encryptionKey);
      final hmacKey2 = cryptoService.deriveHmacKey(encryptionKey);

      expect(hmacKey1, equals(hmacKey2));
    });

    test('不同加密密钥应派生出不同的 HMAC 密钥', () {
      final cryptoService = _createCryptoService();
      final key1 = Uint8List.fromList(List.generate(32, (i) => i));
      final key2 = Uint8List.fromList(List.generate(32, (i) => i + 1));

      final hmacKey1 = cryptoService.deriveHmacKey(key1);
      final hmacKey2 = cryptoService.deriveHmacKey(key2);

      expect(hmacKey1, isNot(equals(hmacKey2)));
    });

    test('HMAC 密钥应与加密密钥不同', () {
      final cryptoService = _createCryptoService();
      final encryptionKey = Uint8List.fromList(List.generate(32, (i) => i));
      final hmacKey = cryptoService.deriveHmacKey(encryptionKey);

      expect(hmacKey, isNot(equals(encryptionKey)));
    });

    test('无效密钥长度应抛出 CryptoException', () {
      final cryptoService = _createCryptoService();
      final shortKey = Uint8List.fromList(List.generate(16, (i) => i));

      expect(
        () => cryptoService.deriveHmacKey(shortKey),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  // ===========================================================================
  // HMAC-SHA256 完整性校验
  // ===========================================================================

  group('HMAC-SHA256 完整性校验', () {
    test('computeHmacFromBytes 应返回带前缀的哈希字符串', () {
      final integrityService = IntegrityService();
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList(utf8.encode('test data'));

      final hash = integrityService.computeHmacFromBytes(data, hmacKey);

      expect(hash, startsWith(HMAC_SHA256_HASH_PREFIX));
      // SHA-256 输出 32 字节 = 64 个十六进制字符
      final hexPart = hash.substring(HMAC_SHA256_HASH_PREFIX.length);
      expect(hexPart.length, equals(64));
      expect(RegExp(r'^[a-f0-9]{64}$').hasMatch(hexPart), isTrue);
    });

    test('相同数据和密钥应产生相同的 HMAC', () {
      final integrityService = IntegrityService();
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList(utf8.encode('consistent data'));

      final hash1 = integrityService.computeHmacFromBytes(data, hmacKey);
      final hash2 = integrityService.computeHmacFromBytes(data, hmacKey);

      expect(hash1, equals(hash2));
    });

    test('不同数据应产生不同的 HMAC', () {
      final integrityService = IntegrityService();
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data1 = Uint8List.fromList(utf8.encode('data1'));
      final data2 = Uint8List.fromList(utf8.encode('data2'));

      final hash1 = integrityService.computeHmacFromBytes(data1, hmacKey);
      final hash2 = integrityService.computeHmacFromBytes(data2, hmacKey);

      expect(hash1, isNot(equals(hash2)));
    });

    test('不同密钥应产生不同的 HMAC', () {
      final integrityService = IntegrityService();
      final key1 = Uint8List.fromList(List.generate(32, (i) => i));
      final key2 = Uint8List.fromList(List.generate(32, (i) => i + 1));
      final data = Uint8List.fromList(utf8.encode('same data'));

      final hash1 = integrityService.computeHmacFromBytes(data, key1);
      final hash2 = integrityService.computeHmacFromBytes(data, key2);

      expect(hash1, isNot(equals(hash2)));
    });

    test('HMAC-SHA256 与无密钥 SHA-256 应产生不同的哈希', () {
      final integrityService = IntegrityService();
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList(utf8.encode('comparison test'));

      final hmacHash = integrityService.computeHmacFromBytes(data, hmacKey);
      final shaHash = integrityService.computeHashFromBytes(data);

      expect(hmacHash, isNot(equals(shaHash)));
      expect(hmacHash, startsWith(HMAC_SHA256_HASH_PREFIX));
      expect(shaHash, startsWith('sha256:'));
    });
  });

  // ===========================================================================
  // 长度字段上限校验（DoS 防护）
  // ===========================================================================

  group('长度字段上限常量', () {
    test('MAX_HEADER_SIZE_BYTES 应为 1 MiB', () {
      expect(MAX_HEADER_SIZE_BYTES, equals(1 << 20));
      expect(MAX_HEADER_SIZE_BYTES, equals(1048576));
    });

    test('MAX_CHUNK_CIPHERTEXT_BYTES 应为 2 MiB', () {
      expect(MAX_CHUNK_CIPHERTEXT_BYTES, equals(2 << 20));
      expect(MAX_CHUNK_CIPHERTEXT_BYTES, equals(2097152));
    });

    test('MAX_TOTAL_CHUNKS_LIMIT 应为 1048576', () {
      expect(MAX_TOTAL_CHUNKS_LIMIT, equals(1 << 20));
    });
  });

  // ===========================================================================
  // v2.1 格式版本常量
  // ===========================================================================

  group('v2.1 格式版本常量', () {
    test('BINARY_FORMAT_MINOR 应为 1', () {
      expect(BINARY_FORMAT_MINOR, equals(1));
    });

    test('BINARY_FORMAT_MINOR_V20 应为 0', () {
      expect(BINARY_FORMAT_MINOR_V20, equals(0));
    });

    test('BINARY_FORMAT_MINOR_V21 应为 1', () {
      expect(BINARY_FORMAT_MINOR_V21, equals(1));
    });

    test('STRAW_FORMAT_VERSION 应为 2.1.0', () {
      expect(STRAW_FORMAT_VERSION, equals('2.1.0'));
    });

    test('KDF_ITERATIONS 应为 600000', () {
      expect(KDF_ITERATIONS, equals(600000));
    });

    test('KDF_ITERATIONS_LEGACY 应为 100000', () {
      expect(KDF_ITERATIONS_LEGACY, equals(100000));
    });

    test('HASH_ALGORITHM_HMAC_SHA256 应为 HMAC-SHA256', () {
      expect(HASH_ALGORITHM_HMAC_SHA256, equals('HMAC-SHA256'));
    });

    test('HMAC_SHA256_HASH_PREFIX 应为 hmac-sha256:', () {
      expect(HMAC_SHA256_HASH_PREFIX, equals('hmac-sha256:'));
    });

    test('STRAWHUT_V21_AAD_DOMAIN_SEPARATOR 应为非空字符串', () {
      expect(STRAWHUT_V21_AAD_DOMAIN_SEPARATOR, isNotEmpty);
    });

    test('STRAWHUT_V21_HMAC_KEY_LABEL 应为非空字符串', () {
      expect(STRAWHUT_V21_HMAC_KEY_LABEL, isNotEmpty);
    });
  });

  // ===========================================================================
  // v2.1 流式加解密往返
  // ===========================================================================

  group('v2.1 流式加解密', () {
    test('v2.1 流式加密后用 useV21Security=true 流式解密应还原', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));

      // 创建测试源文件
      final sourceFile = File('${tempDir.path}/v21_source.bin');
      final payload = Uint8List.fromList(
        List.generate(5000, (i) => i % 256),
      );
      await sourceFile.writeAsBytes(payload);

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
        originalFileName: 'v21_source.bin',
      );

      // 流式加密
      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key,
        chunkSize: 1024,
      );

      expect(encrypted.totalChunks, greaterThan(1));

      // 将加密结果写入 v2.1 格式的 .straw 文件
      final strawFile = File('${tempDir.path}/v21_test.straw');
      await _writeStrawBinaryFileV21(
        strawFile,
        encrypted,
        metadata,
        minorVersion: BINARY_FORMAT_MINOR_V21,
      );

      // 流式解密
      final targetPath = '${tempDir.path}/v21_decrypted.bin';
      final result = await cryptoService.decryptStream(
        strawFilePath: strawFile.path,
        key: key,
        targetPath: targetPath,
        chunkSize: encrypted.chunkSize,
        originalPayloadSize: encrypted.originalPayloadSize,
        useV21Security: true,
      );

      // 验证解密结果
      expect(result.targetPath, targetPath);
      expect(result.payloadMetadata.sourceType, metadata.sourceType);

      // 验证文件内容
      final decryptedFile = File(targetPath);
      expect(await decryptedFile.exists(), true);
      final decryptedBytes = await decryptedFile.readAsBytes();
      expect(decryptedBytes, equals(payload));
    });

    test('v2.1 流式加密的密文不能用 v2.0 模式流式解密', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));

      final sourceFile = File('${tempDir.path}/v21_mismatch.bin');
      final payload = Uint8List.fromList(
        List.generate(1000, (i) => i % 256),
      );
      await sourceFile.writeAsBytes(payload);

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
      );

      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key,
      );

      final strawFile = File('${tempDir.path}/v21_mismatch.straw');
      await _writeStrawBinaryFileV21(
        strawFile,
        encrypted,
        metadata,
        minorVersion: BINARY_FORMAT_MINOR_V21,
      );

      final targetPath = '${tempDir.path}/v21_mismatch_decrypted.bin';
      // 用 v2.0 模式解密 v2.1 加密的数据，应失败
      expect(
        () => cryptoService.decryptStream(
          strawFilePath: strawFile.path,
          key: key,
          targetPath: targetPath,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
        ),
        throwsA(isA<CryptoException>()),
      );
    });

    test('v2.0 流式加密的密文不能用 v2.1 模式流式解密', () async {
      final cryptoService = _createCryptoService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));

      final sourceFile = File('${tempDir.path}/v20_mismatch.bin');
      final payload = Uint8List.fromList(
        List.generate(1000, (i) => i % 256),
      );
      await sourceFile.writeAsBytes(payload);

      const metadata = PayloadMetadata(
        sourceType: SourceType.rawFile,
        originalExtension: 'bin',
      );

      final encrypted = await cryptoService.encryptStream(
        sourcePath: sourceFile.path,
        payloadMetadata: metadata,
        key: key,
        useV21Security: false,
      );

      // 写入 v2.0 格式文件
      final strawFile = File('${tempDir.path}/v20_mismatch.straw');
      await _writeStrawBinaryFileV21(
        strawFile,
        encrypted,
        metadata,
        minorVersion: BINARY_FORMAT_MINOR_V20,
      );

      final targetPath = '${tempDir.path}/v20_mismatch_decrypted.bin';
      // 用 v2.1 模式解密 v2.0 加密的数据，应失败
      expect(
        () => cryptoService.decryptStream(
          strawFilePath: strawFile.path,
          key: key,
          targetPath: targetPath,
          chunkSize: encrypted.chunkSize,
          originalPayloadSize: encrypted.originalPayloadSize,
          useV21Security: true,
        ),
        throwsA(isA<CryptoException>()),
      );
    });
  });

  // ===========================================================================
  // v2.1 端到端完整性校验
  // ===========================================================================

  group('v2.1 端到端完整性校验', () {
    test('v2.1 加密+HMAC 完整性校验流程应通过', () async {
      final cryptoService = _createCryptoService();
      final integrityService = IntegrityService();
      final key = Uint8List.fromList(List.generate(32, (i) => i));
      final payload = Uint8List.fromList(
        utf8.encode('端到端完整性校验测试数据'),
      );
      const metadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      // 1. 加密
      final encrypted = await cryptoService.encrypt(
        payloadBytes: payload,
        payloadMetadata: metadata,
        key: key,
      );

      // 2. 派生 HMAC 密钥
      final hmacKey = cryptoService.deriveHmacKey(key);

      // 3. 构造用于哈希计算的字节（模拟 buildBinaryFileBytes）
      final builder = BytesBuilder();
      builder.add(STRAW_MAGIC_BYTES);
      builder.addByte(BINARY_FORMAT_MAJOR & 0xFF);
      builder.addByte((BINARY_FORMAT_MAJOR >> 8) & 0xFF);
      builder.addByte(BINARY_FORMAT_MINOR_V21 & 0xFF);
      builder.addByte((BINARY_FORMAT_MINOR_V21 >> 8) & 0xFF);

      final headerJson = {
        'format_version': STRAW_FORMAT_VERSION,
        'meta': {
          'publisher_alias': 'Tester',
          'publish_date': '2026-07-30T00:00:00Z',
          'title': 'Test',
          'is_anonymous': false,
          'tags': <String>[],
        },
        'content': {
          'encryption_algorithm': ENCRYPTION_ALGORITHM_AES_256_GCM,
          'chunk_size': encrypted.chunkSize,
          'total_chunks': encrypted.totalChunks,
          'original_payload_size': encrypted.originalPayloadSize,
        },
        'integrity': {
          'hash': '',
          'hash_algorithm': HASH_ALGORITHM_HMAC_SHA256,
        },
      };
      final headerBytes = Uint8List.fromList(utf8.encode(jsonEncode(headerJson)));
      builder.addByte(headerBytes.length & 0xFF);
      builder.addByte((headerBytes.length >> 8) & 0xFF);
      builder.addByte((headerBytes.length >> 16) & 0xFF);
      builder.addByte((headerBytes.length >> 24) & 0xFF);
      builder.add(headerBytes);

      for (final chunk in encrypted.chunks) {
        builder.add(chunk.iv);
        builder.addByte(chunk.encryptedData.length & 0xFF);
        builder.addByte((chunk.encryptedData.length >> 8) & 0xFF);
        builder.addByte((chunk.encryptedData.length >> 16) & 0xFF);
        builder.addByte((chunk.encryptedData.length >> 24) & 0xFF);
        builder.add(chunk.encryptedData);
      }

      final fileBytesWithoutHash = builder.toBytes();

      // 4. 计算 HMAC
      final computedHash = integrityService.computeHmacFromBytes(
        Uint8List.fromList(fileBytesWithoutHash),
        hmacKey,
      );

      // 5. 验证哈希格式
      expect(computedHash, startsWith(HMAC_SHA256_HASH_PREFIX));
      final hexPart = computedHash.substring(HMAC_SHA256_HASH_PREFIX.length);
      expect(hexPart.length, equals(64));

      // 6. 重新计算应得到相同结果（幂等性）
      final recomputedHash = integrityService.computeHmacFromBytes(
        Uint8List.fromList(fileBytesWithoutHash),
        hmacKey,
      );
      expect(recomputedHash, equals(computedHash));
    });

    test('篡改文件内容后 HMAC 校验应失败', () async {
      final integrityService = IntegrityService();
      final hmacKey = Uint8List.fromList(List.generate(32, (i) => i));
      final data = Uint8List.fromList(utf8.encode('original data'));

      final originalHash = integrityService.computeHmacFromBytes(data, hmacKey);

      // 篡改数据
      final tamperedData = Uint8List.fromList(utf8.encode('tampered data'));
      final tamperedHash = integrityService.computeHmacFromBytes(
        tamperedData,
        hmacKey,
      );

      expect(originalHash, isNot(equals(tamperedHash)));
    });
  });
}

// ===========================================================================
// 辅助函数：构建并写入 .straw 二进制文件（支持 v2.0/v2.1 版本）
// ===========================================================================

/// 按照 StrawHut 二进制格式写入文件，可指定次版本号
///
/// 格式：
/// - Magic Bytes (8B)
/// - Version Major (2B) + Version Minor (2B)
/// - Header Size (4B)
/// - JSON Header (variable)
/// - Chunks (variable)
Future<void> _writeStrawBinaryFileV21(
  File file,
  EncryptResult encryptResult,
  PayloadMetadata metadata, {
  required int minorVersion,
}) async {
  final builder = BytesBuilder();

  // 1. Magic Bytes: "STRAWHUT"
  builder.add(STRAW_MAGIC_BYTES);

  // 2. Format Version Major (2 bytes uint16 LE)
  builder.addByte(BINARY_FORMAT_MAJOR & 0xFF);
  builder.addByte((BINARY_FORMAT_MAJOR >> 8) & 0xFF);

  // 3. Format Version Minor (2 bytes uint16 LE)
  builder.addByte(minorVersion & 0xFF);
  builder.addByte((minorVersion >> 8) & 0xFF);

  // 4. JSON Header
  final hashAlgorithm = minorVersion == BINARY_FORMAT_MINOR_V21
      ? HASH_ALGORITHM_HMAC_SHA256
      : HASH_ALGORITHM_SHA256;
  final formatVersionStr = minorVersion == BINARY_FORMAT_MINOR_V21
      ? STRAW_FORMAT_VERSION
      : '2.0.0';

  final headerJson = {
    'format_version': formatVersionStr,
    'meta': {
      'publisher_alias': 'Test',
      'publish_date': '2026-07-30T00:00:00Z',
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
      'hash_algorithm': hashAlgorithm,
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
