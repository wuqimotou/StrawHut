import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/key_derivators/api.dart';
import 'package:pointycastle/key_derivators/pbkdf2.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';
import 'package:strawhut/core/utils/memory_utils.dart';

/// 加密服务接口
///
/// 定义 StrawHut 核心加密/解密操作的契约。
/// 所有加密功能通过此接口实现，确保：
/// - 使用 AES-256-GCM 对称加密算法
/// - 使用 CSPRNG 生成加密安全的随机密钥
/// - 支持分块加密/解密，适应从小文本到大文件的多种场景
/// - 提供敏感数据内存清理机制
///
/// 架构位置：核心服务层（Core Service Layer）
/// 依赖接口：无
/// 被依赖方：应用层（PublishDialog、DecryptDialog）通过 Riverpod Provider 调用
abstract class ICryptoService {
  /// 生成加密密钥
  ///
  /// 使用 CSPRNG（密码学安全伪随机数生成器）生成 32 字节（256 位）随机密钥。
  /// 返回的 [GeneratedKey] 包含原始字节和 Base64 编码字符串。
  ///
  /// 安全要求：
  /// - 必须使用 [Random.secure()] 而非普通随机数生成器
  /// - 密钥生成后应尽快传递到加密操作，减少内存驻留时间
  Future<GeneratedKey> generateKey();

  /// 清理敏感数据
  ///
  /// 将内存中所有敏感数据引用置 null，降低内存泄露风险。
  ///
  /// 清理内容包括：
  /// - 加密/解密密钥（字节数组）
  /// - 明文内容（如适用）
  /// - 其他临时敏感变量
  ///
  /// 注意事项：
  /// - Dart 的 GC 机制不可控，无法强制立即回收
  /// - 最佳实践：调用此方法后尽快让引用超出作用域
  /// - 使用 [MemoryUtils.wipeBytes] 可将字节数组逐字节置零
  void clearSensitiveData();

  /// 从口令派生加密密钥
  ///
  /// 使用 PBKDF2-HMAC-SHA256 算法从用户口令派生 32 字节加密密钥。
  /// 用于协商密钥加密模式，允许用户通过口令保护知识卡片。
  ///
  /// 参数说明：
  /// - [passphrase]: 用户输入的口令
  /// - [salt]: 16 字节盐值（由 CSPRNG 生成）
  /// - [iterations]: PBKDF2 迭代次数，默认为 [KDF_ITERATIONS]（100000）
  ///
  /// 返回值：派生出的 32 字节密钥
  ///
  /// 安全说明：
  /// - 盐值必须使用 CSPRNG 生成，长度必须为 [SALT_LENGTH_BYTES]
  /// - 迭代次数越高，暴力破解成本越大，但派生耗时也越长
  /// - 派生后的密钥与 [generateKey] 生成的密钥用法一致
  Future<Uint8List> deriveKeyFromPassphrase({
    required String passphrase,
    required Uint8List salt,
    int iterations = KDF_ITERATIONS,
    CancellationToken? cancellationToken,
  });

  /// 加密载荷（统一接口）
  ///
  /// 将载荷字节和元数据加密为分块结构。第一个分块包含元数据前缀：
  /// [MetadataLength(2B uint16 LE)] + [MetadataBytes] + [PayloadData[:剩余空间]]
  /// 后续分块仅包含载荷数据。
  /// 每个分块独立生成 IV，使用 AES-256-GCM 加密。
  ///
  /// 参数说明：
  /// - [payloadBytes]: 待加密的载荷字节数据
  /// - [payloadMetadata]: 载荷元数据（来源类型、原始扩展名等）
  /// - [key]: 32 字节加密密钥
  /// - [chunkSize]: 分块大小（字节），默认 [DEFAULT_CHUNK_SIZE]（1MB）
  /// - [onProgress]: 进度回调，参数为 (当前分块, 总分块数)
  Future<EncryptResult> encrypt({
    required Uint8List payloadBytes,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
  });

  /// 解密载荷（统一接口）
  ///
  /// 解密分块列表，还原为原始载荷字节和元数据。
  /// 首先解密第一个分块提取元数据前缀，然后解密后续分块获取完整载荷。
  ///
  /// 参数说明：
  /// - [chunks]: 加密分块列表
  /// - [key]: 32 字节解密密钥
  /// - [chunkSize]: 分块大小（字节）
  /// - [originalPayloadSize]: 原始载荷大小（字节），用于精确截取
  /// - [onProgress]: 进度回调，参数为 (当前分块, 总分块数)
  Future<DecryptResult> decrypt({
    required List<ChunkInfo> chunks,
    required Uint8List key,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
  });

  /// 流式加密（大文件场景）
  ///
  /// 从源文件逐块读取数据并加密，避免将整个文件加载到内存。
  /// 适用于大文件（视频、PDF 等）的加密场景。
  ///
  /// 参数说明：
  /// - [sourcePath]: 源文件路径
  /// - [payloadMetadata]: 载荷元数据
  /// - [key]: 32 字节加密密钥
  /// - [chunkSize]: 分块大小（字节），默认 [DEFAULT_CHUNK_SIZE]（1MB）
  /// - [onProgress]: 进度回调，参数为 (当前分块, 总分块数)
  Future<EncryptResult> encryptStream({
    required String sourcePath,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
  });

  /// 流式解密（大文件场景）
  ///
  /// 从 .straw 二进制文件逐块读取并解密，将明文写入目标文件，
  /// 避免将整个文件加载到内存。适用于大文件的解密场景。
  ///
  /// .straw 二进制文件格式：
  /// [8B Magic Bytes "STRAWHUT"]
  /// [4B Version (2B major uint16 LE + 2B minor uint16 LE)]
  /// [4B header_json_length (uint32 LE)]
  /// [header_json_length bytes: JSON 头部]
  /// [每个分块: 16B IV + 4B encrypted_data_length (uint32 LE) + encrypted_data]
  ///
  /// 参数说明：
  /// - [strawFilePath]: .straw 二进制文件路径
  /// - [key]: 32 字节解密密钥
  /// - [targetPath]: 解密后写入的目标文件路径
  /// - [chunkSize]: 分块大小（字节）
  /// - [originalPayloadSize]: 原始载荷大小（字节）
  /// - [onProgress]: 进度回调，参数为 (当前分块, 总分块数)
  Future<DecryptStreamResult> decryptStream({
    required String strawFilePath,
    required Uint8List key,
    required String targetPath,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
  });

  /// 解密旧版单块加密内容
  ///
  /// 用于迁移旧版 .straw 文件。旧版使用单块 AES-256-GCM 加密，
  /// Base64 编码的 `encrypted_data` 和 `iv` 存储在 JSON 中。
  ///
  /// 参数说明：
  /// - [encryptedDataBase64]: Base64 编码的密文（含 GCM Tag）
  /// - [ivBase64]: Base64 编码的 IV
  /// - [key]: 32 字节解密密钥
  ///
  /// 返回解密后的明文字节
  Uint8List decryptLegacyContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  });
}

/// 加密服务实现
///
/// 实现 [ICryptoService] 接口，提供完整的分块加密/解密功能。
///
/// 依赖的第三方库：
/// - `encrypt` 包：提供高层 AES-256-GCM 加密 API
/// - `pointycastle` 包（通过 encrypt 间接使用）：底层密码学原语
///
/// 使用示例：
/// ```dart
/// final cryptoService = CryptoService(integrityService);
/// final key = await cryptoService.generateKey();
/// final encryptResult = await cryptoService.encrypt(
///   payloadBytes: utf8.encode('Hello World'),
///   payloadMetadata: PayloadMetadata(
///     sourceType: SourceType.richText,
///     originalExtension: 'delta',
///   ),
///   key: key.bytes,
/// );
/// // ... 发布完成后清理敏感数据
/// cryptoService.clearSensitiveData();
/// ```
class CryptoService implements ICryptoService {
  /// 构造函数
  ///
  /// 创建加密服务实例，需要注入 [IntegrityService] 依赖。
  ///
  /// 参数说明：
  /// - [integrityService]: 完整性校验服务实例，用于哈希计算和验证
  CryptoService(this.integrityService);

  /// 完整性校验服务依赖
  ///
  /// 用于在加密/解密流程中进行数据完整性校验。
  /// 虽然当前加密/解密操作本身不直接使用此服务，
  /// 但在完整的发布/解密流程中，加密后需要计算哈希，
  /// 解密后需要验证完整性，因此作为依赖注入。
  final IntegrityService integrityService;

  /// 生成加密密钥
  ///
  /// 实现步骤：
  /// 1. 使用 [Random.secure()]（CSPRNG）生成 32 个安全随机字节
  /// 2. 将字节列表转换为 [Uint8List] 以便加密操作使用
  /// 3. 使用 [base64Encode] 将字节数组编码为 Base64 字符串
  /// 4. 返回包含原始字节和编码字符串的 [GeneratedKey]
  ///
  /// 性能参考：密钥生成耗时 < 1ms
  @override
  Future<GeneratedKey> generateKey() async {
    final random = Random.secure();
    final keyBytes = Uint8List(KEY_LENGTH_BYTES);
    for (var i = 0; i < KEY_LENGTH_BYTES; i++) {
      keyBytes[i] = random.nextInt(256);
    }

    final keyBase64 = base64Encode(keyBytes);

    return GeneratedKey(bytes: keyBytes, base64: keyBase64);
  }

  /// 从口令派生加密密钥
  ///
  /// 实现步骤：
  /// 1. 验证盐值长度是否为 [SALT_LENGTH_BYTES] 字节
  /// 2. 使用 PBKDF2-HMAC-SHA256 算法派生密钥
  /// 3. 返回派生后的 32 字节密钥
  @override
  Future<Uint8List> deriveKeyFromPassphrase({
    required String passphrase,
    required Uint8List salt,
    int iterations = KDF_ITERATIONS,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    if (salt.length != SALT_LENGTH_BYTES) {
      throw CryptoException(
        '盐值长度不正确：期望 $SALT_LENGTH_BYTES 字节，实际 ${salt.length} 字节',
        code: 'INVALID_SALT_LENGTH',
      );
    }

    try {
      final result = await compute(
        _deriveKeyFromPassphraseIsolate,
        _DeriveKeyParams(
          passphrase: passphrase,
          salt: salt,
          iterations: iterations,
        ),
      );
      cancellationToken?.throwIfCancelled();
      return result;
    } on OperationCancelledException {
      rethrow;
    } catch (e) {
      throw CryptoException('密钥派生失败：$e', code: 'KEY_DERIVATION_FAILED');
    }
  }

  /// 清理敏感数据
  ///
  /// 当前实现为无状态设计，没有内部持有敏感数据引用。
  /// 调用方应自行清理持有的密钥引用。
  @override
  void clearSensitiveData() {
    // 当前实现为无状态设计，没有内部持有敏感数据引用。
    // 调用方应自行清理持有的密钥引用，例如：
    //   MemoryUtils.wipeBytes(keyBytes);
    //   keyBytes = null;
  }

  /// 加密载荷（统一接口）
  ///
  /// 实现步骤：
  /// 1. 序列化 PayloadMetadata 为字节
  /// 2. 构造第一个分块明文：[2B 元数据长度(uint16 LE)] + [元数据字节] + [载荷数据]
  /// 3. 为每个分块生成随机 IV → AES-256-GCM 加密 → ChunkInfo
  /// 4. 后续分块：直接加密载荷数据
  /// 5. 返回 EncryptResult
  @override
  Future<EncryptResult> encrypt({
    required Uint8List payloadBytes,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
  }) async {
    _validateKeyLength(key);

    final metadataBytes = payloadMetadata.toBytes();
    final metadataLen = metadataBytes.length;

    // 元数据长度必须能放入 uint16（2 字节，最大 65535）
    if (metadataLen > 0xFFFF) {
      throw CryptoException(
        '元数据过大：$metadataLen 字节，最大支持 65535 字节',
        code: 'METADATA_TOO_LARGE',
      );
    }

    // 第一个分块载荷容量 = chunkSize - 2(长度前缀) - metadataLen
    final firstChunkPayloadCapacity = chunkSize - 2 - metadataLen;
    if (firstChunkPayloadCapacity < 0) {
      throw CryptoException(
        '分块大小不足以容纳元数据：chunkSize=$chunkSize, metadataLen=$metadataLen',
        code: 'CHUNK_SIZE_TOO_SMALL',
      );
    }

    // 计算总分块数
    final totalChunks = _calculateTotalChunks(
      payloadSize: payloadBytes.length,
      firstChunkPayloadCapacity: firstChunkPayloadCapacity,
      chunkSize: chunkSize,
    );

    final chunks = <ChunkInfo>[];
    int payloadOffset = 0;

    // ---- 第一个分块 ----
    final firstPayloadSize = min(
      firstChunkPayloadCapacity,
      payloadBytes.length,
    );
    final firstChunkPlaintext = Uint8List(2 + metadataLen + firstPayloadSize);
    // 写入元数据长度（uint16 LE）
    firstChunkPlaintext[0] = metadataLen & 0xFF;
    firstChunkPlaintext[1] = (metadataLen >> 8) & 0xFF;
    // 写入元数据字节
    firstChunkPlaintext.setRange(2, 2 + metadataLen, metadataBytes);
    // 写入第一部分载荷数据
    firstChunkPlaintext.setRange(
      2 + metadataLen,
      firstChunkPlaintext.length,
      payloadBytes,
    );
    payloadOffset = firstPayloadSize;

    // 使用 compute 在后台 Isolate 中加密第一个分块
    final firstResult = await compute(
      _encryptChunkInIsolate,
      _ChunkEncryptParams(plaintext: firstChunkPlaintext, key: key),
    );
    chunks.add(
      ChunkInfo(iv: firstResult.iv, encryptedData: firstResult.encryptedData),
    );
    onProgress?.call(1, totalChunks);

    // ---- 后续分块 ----
    while (payloadOffset < payloadBytes.length) {
      final chunkPayloadSize = min(
        chunkSize,
        payloadBytes.length - payloadOffset,
      );
      final chunkPlaintext = Uint8List.fromList(
        payloadBytes.sublist(payloadOffset, payloadOffset + chunkPayloadSize),
      );

      // 使用 compute 在后台 Isolate 中加密每个分块
      final chunkResult = await compute(
        _encryptChunkInIsolate,
        _ChunkEncryptParams(plaintext: chunkPlaintext, key: key),
      );
      chunks.add(
        ChunkInfo(iv: chunkResult.iv, encryptedData: chunkResult.encryptedData),
      );

      payloadOffset += chunkPayloadSize;
      onProgress?.call(chunks.length, totalChunks);
    }

    return EncryptResult(
      chunks: chunks,
      chunkSize: chunkSize,
      totalChunks: totalChunks,
      originalPayloadSize: payloadBytes.length,
    );
  }

  /// 解密载荷（统一接口）
  ///
  /// 实现步骤：
  /// 1. 解密第一个分块 → 提取 [MetadataLength(2B)] + [MetadataBytes] + 首段载荷
  /// 2. 解析 PayloadMetadata → 获取 sourceType + originalExtension
  /// 3. 解密第 2..N 个分块 → 拼接载荷数据
  /// 4. 返回 DecryptResult（PayloadMetadata + 完整 PayloadBytes）
  @override
  Future<DecryptResult> decrypt({
    required List<ChunkInfo> chunks,
    required Uint8List key,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

    if (chunks.isEmpty) {
      throw CryptoException('分块列表为空，无法解密', code: 'EMPTY_CHUNKS');
    }

    // ---- 解密第一个分块（在 Isolate 中） ----
    final firstPlaintext = await compute(
      _decryptChunkInIsolate,
      _ChunkDecryptParams(
        ciphertext: chunks[0].encryptedData,
        key: key,
        iv: chunks[0].iv,
      ),
    );
    cancellationToken?.throwIfCancelled();
    onProgress?.call(1, chunks.length);

    // 提取元数据长度（uint16 LE）
    if (firstPlaintext.length < 2) {
      throw CryptoException('第一个分块过小，无法读取元数据长度', code: 'FIRST_CHUNK_TOO_SMALL');
    }
    final metadataLen = firstPlaintext[0] | (firstPlaintext[1] << 8);

    if (firstPlaintext.length < 2 + metadataLen) {
      throw CryptoException('第一个分块过小，元数据被截断', code: 'METADATA_TRUNCATED');
    }

    // 提取元数据字节并反序列化
    final metadataBytes = Uint8List.fromList(
      firstPlaintext.sublist(2, 2 + metadataLen),
    );
    final payloadMetadata = PayloadMetadata.fromBytes(metadataBytes);

    // 提取首段载荷数据
    final firstPayloadPart = firstPlaintext.sublist(2 + metadataLen);

    // ---- 解密后续分块（在 Isolate 中） ----
    final payloadParts = <Uint8List>[Uint8List.fromList(firstPayloadPart)];
    for (var i = 1; i < chunks.length; i++) {
      cancellationToken?.throwIfCancelled();
      final chunkPlaintext = await compute(
        _decryptChunkInIsolate,
        _ChunkDecryptParams(
          ciphertext: chunks[i].encryptedData,
          key: key,
          iv: chunks[i].iv,
        ),
      );
      cancellationToken?.throwIfCancelled();
      payloadParts.add(chunkPlaintext);
      onProgress?.call(i + 1, chunks.length);
    }

    // ---- 拼接完整载荷 ----
    final totalSize = payloadParts.fold<int>(
      0,
      (sum, part) => sum + part.length,
    );
    final payloadBytes = Uint8List(totalSize);
    int offset = 0;
    for (final part in payloadParts) {
      cancellationToken?.throwIfCancelled();
      payloadBytes.setRange(offset, offset + part.length, part);
      offset += part.length;
      await Future<void>.delayed(Duration.zero);
    }

    // 精确截取到 originalPayloadSize（确保与加密前一致）
    final resultBytes = payloadBytes.length == originalPayloadSize
        ? payloadBytes
        : Uint8List.fromList(payloadBytes.sublist(0, originalPayloadSize));

    return DecryptResult(
      payloadMetadata: payloadMetadata,
      payloadBytes: resultBytes,
    );
  }

  /// 流式加密（大文件场景）
  ///
  /// 使用 dart:io File.openRead() 从源文件逐块读取数据并加密，
  /// 避免将整个文件加载到内存。适用于大文件（视频、PDF 等）的加密场景。
  ///
  /// 实现步骤：
  /// 1. 获取文件大小，计算总分块数
  /// 2. 读取第一块数据，构造含元数据前缀的第一个分块明文
  /// 3. 使用 AES-256-GCM 加密每个分块
  /// 4. 返回 EncryptResult
  @override
  Future<EncryptResult> encryptStream({
    required String sourcePath,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
  }) async {
    _validateKeyLength(key);

    final file = File(sourcePath);
    if (!await file.exists()) {
      throw CryptoException('源文件不存在：$sourcePath', code: 'FILE_NOT_FOUND');
    }

    final fileSize = await file.length();
    final metadataBytes = payloadMetadata.toBytes();
    final metadataLen = metadataBytes.length;

    if (metadataLen > 0xFFFF) {
      throw CryptoException(
        '元数据过大：$metadataLen 字节，最大支持 65535 字节',
        code: 'METADATA_TOO_LARGE',
      );
    }

    final firstChunkPayloadCapacity = chunkSize - 2 - metadataLen;
    if (firstChunkPayloadCapacity < 0) {
      throw CryptoException(
        '分块大小不足以容纳元数据：chunkSize=$chunkSize, metadataLen=$metadataLen',
        code: 'CHUNK_SIZE_TOO_SMALL',
      );
    }

    final totalChunks = _calculateTotalChunks(
      payloadSize: fileSize,
      firstChunkPayloadCapacity: firstChunkPayloadCapacity,
      chunkSize: chunkSize,
    );

    final chunks = <ChunkInfo>[];
    final raf = await file.open();

    try {
      // ---- 第一个分块 ----
      final firstPayloadSize = min(firstChunkPayloadCapacity, fileSize);
      final firstPayloadData = await raf.read(firstPayloadSize);

      final firstChunkPlaintext = Uint8List(2 + metadataLen + firstPayloadSize);
      firstChunkPlaintext[0] = metadataLen & 0xFF;
      firstChunkPlaintext[1] = (metadataLen >> 8) & 0xFF;
      firstChunkPlaintext.setRange(2, 2 + metadataLen, metadataBytes);
      firstChunkPlaintext.setRange(
        2 + metadataLen,
        firstChunkPlaintext.length,
        firstPayloadData,
      );

      // 使用 compute 在后台 Isolate 中加密第一个分块
      final firstResult = await compute(
        _encryptChunkInIsolate,
        _ChunkEncryptParams(plaintext: firstChunkPlaintext, key: key),
      );
      chunks.add(
        ChunkInfo(iv: firstResult.iv, encryptedData: firstResult.encryptedData),
      );
      onProgress?.call(1, totalChunks);

      // ---- 后续分块 ----
      int chunkIndex = 1;
      while (await raf.position() < fileSize) {
        final remaining = fileSize - await raf.position();
        final readSize = min(chunkSize, remaining);
        final chunkData = await raf.read(readSize);

        // 使用 compute 在后台 Isolate 中加密每个分块
        final chunkResult = await compute(
          _encryptChunkInIsolate,
          _ChunkEncryptParams(
            plaintext: Uint8List.fromList(chunkData),
            key: key,
          ),
        );
        chunks.add(
          ChunkInfo(
            iv: chunkResult.iv,
            encryptedData: chunkResult.encryptedData,
          ),
        );

        chunkIndex++;
        onProgress?.call(chunkIndex, totalChunks);
      }

      return EncryptResult(
        chunks: chunks,
        chunkSize: chunkSize,
        totalChunks: totalChunks,
        originalPayloadSize: fileSize,
      );
    } finally {
      await raf.close();
    }
  }

  /// 流式解密（大文件场景）
  ///
  /// 从 .straw 二进制文件逐块读取并解密，将明文写入目标文件，
  /// 避免将整个文件加载到内存。适用于大文件的解密场景。
  ///
  /// .straw 二进制文件格式：
  /// [4B header_json_length (uint32 LE)]
  /// [header_json_length bytes: JSON 头部]
  /// [每个分块: 16B IV + 4B encrypted_data_length (uint32 LE) + encrypted_data]
  ///
  /// 实现步骤：
  /// 1. 读取并解析 JSON 头部，获取 totalChunks
  /// 2. 逐块读取 IV + 密文长度 + 密文
  /// 3. 解密每个分块，第一个分块提取元数据前缀
  /// 4. 将载荷数据写入目标文件
  /// 5. 返回 DecryptStreamResult
  @override
  Future<DecryptStreamResult> decryptStream({
    required String strawFilePath,
    required Uint8List key,
    required String targetPath,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

    final file = File(strawFilePath);
    if (!await file.exists()) {
      throw CryptoException('文件不存在：$strawFilePath', code: 'FILE_NOT_FOUND');
    }

    final raf = await file.open();

    try {
      // ---- 跳过 Magic Bytes (8 字节) + Version (4 字节) ----
      await raf.setPosition(MAGIC_BYTES_LENGTH + 4);

      // ---- 读取 JSON 头部长度 ----
      final headerLenBytes = await raf.read(4);
      if (headerLenBytes.length < 4) {
        throw CryptoException('文件头部格式错误：无法读取头部长度', code: 'INVALID_FILE_FORMAT');
      }
      final headerLength =
          headerLenBytes[0] |
          (headerLenBytes[1] << 8) |
          (headerLenBytes[2] << 16) |
          (headerLenBytes[3] << 24);

      // ---- 读取 JSON 头部 ----
      final headerBytes = await raf.read(headerLength);
      if (headerBytes.length < headerLength) {
        throw CryptoException(
          '文件头部不完整：期望 $headerLength 字节，实际 ${headerBytes.length} 字节',
          code: 'INVALID_FILE_FORMAT',
        );
      }

      // 解析头部获取 totalChunks
      Map<String, dynamic> headerJson;
      try {
        headerJson =
            jsonDecode(utf8.decode(headerBytes)) as Map<String, dynamic>;
      } catch (e) {
        throw CryptoException('JSON 头部解析失败：$e', code: 'INVALID_FILE_FORMAT');
      }

      final contentJson = headerJson['content'] as Map<String, dynamic>;
      final totalChunks = contentJson['total_chunks'] as int;

      // ---- 创建目标文件 ----
      final targetFile = File(targetPath);
      final targetRaf = await targetFile.open(mode: FileMode.writeOnly);

      PayloadMetadata? payloadMetadata;
      int bytesWritten = 0;

      try {
        for (var i = 0; i < totalChunks; i++) {
          cancellationToken?.throwIfCancelled();
          // 读取 IV
          final ivBytes = await raf.read(CHUNK_IV_LENGTH_BYTES);
          if (ivBytes.length < CHUNK_IV_LENGTH_BYTES) {
            throw CryptoException(
              '分块 $i IV 数据不完整',
              code: 'INVALID_FILE_FORMAT',
            );
          }

          // 读取加密数据长度
          final encDataLenBytes = await raf.read(4);
          if (encDataLenBytes.length < 4) {
            throw CryptoException(
              '分块 $i 加密数据长度字段不完整',
              code: 'INVALID_FILE_FORMAT',
            );
          }
          final encDataLen =
              encDataLenBytes[0] |
              (encDataLenBytes[1] << 8) |
              (encDataLenBytes[2] << 16) |
              (encDataLenBytes[3] << 24);

          // 读取加密数据
          final encDataBytes = await raf.read(encDataLen);
          if (encDataBytes.length < encDataLen) {
            throw CryptoException(
              '分块 $i 加密数据不完整：期望 $encDataLen 字节，'
              '实际 ${encDataBytes.length} 字节',
              code: 'INVALID_FILE_FORMAT',
            );
          }

          // 使用 compute 在后台 Isolate 中解密分块
          final plaintext = await compute(
            _decryptChunkInIsolate,
            _ChunkDecryptParams(
              ciphertext: Uint8List.fromList(encDataBytes),
              key: key,
              iv: Uint8List.fromList(ivBytes),
            ),
          );
          cancellationToken?.throwIfCancelled();

          if (i == 0) {
            // 第一个分块：提取元数据前缀
            if (plaintext.length < 2) {
              throw CryptoException(
                '第一个分块过小，无法读取元数据长度',
                code: 'FIRST_CHUNK_TOO_SMALL',
              );
            }
            final metadataLen = plaintext[0] | (plaintext[1] << 8);

            if (plaintext.length < 2 + metadataLen) {
              throw CryptoException(
                '第一个分块过小，元数据被截断',
                code: 'METADATA_TRUNCATED',
              );
            }

            final metadataBytes = Uint8List.fromList(
              plaintext.sublist(2, 2 + metadataLen),
            );
            payloadMetadata = PayloadMetadata.fromBytes(metadataBytes);

            // 写入首段载荷数据到目标文件
            final payloadPart = plaintext.sublist(2 + metadataLen);
            if (payloadPart.isNotEmpty) {
              await targetRaf.writeFrom(payloadPart);
              bytesWritten += payloadPart.length;
            }
          } else {
            // 后续分块：直接写入载荷数据
            await targetRaf.writeFrom(plaintext);
            bytesWritten += plaintext.length;
          }

          onProgress?.call(i + 1, totalChunks);
        }
      } finally {
        await targetRaf.close();
      }

      // 截断目标文件到精确的 originalPayloadSize
      if (bytesWritten > originalPayloadSize) {
        cancellationToken?.throwIfCancelled();
        final truncateRaf = await targetFile.open(mode: FileMode.append);
        try {
          await truncateRaf.truncate(originalPayloadSize);
        } finally {
          await truncateRaf.close();
        }
      }

      return DecryptStreamResult(
        payloadMetadata: payloadMetadata!,
        targetPath: targetPath,
      );
    } on OperationCancelledException {
      final partialFile = File(targetPath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    } catch (e) {
      final partialFile = File(targetPath);
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      throw e is CryptoException
          ? e
          : CryptoException('流式解密失败：$e', code: 'DECRYPT_STREAM_FAILED');
    } finally {
      await raf.close();
    }
  }

  // ==========================================================================
  // 私有辅助方法
  // ==========================================================================

  /// 验证密钥长度是否为 32 字节
  void _validateKeyLength(Uint8List key) {
    if (key.length != KEY_LENGTH_BYTES) {
      throw CryptoException(
        '密钥长度不正确：期望 $KEY_LENGTH_BYTES 字节，实际 ${key.length} 字节',
        code: 'INVALID_KEY_LENGTH',
      );
    }
  }

  /// 计算总分块数
  ///
  /// [payloadSize] 载荷总大小
  /// [firstChunkPayloadCapacity] 第一个分块的载荷容量
  /// [chunkSize] 后续分块大小
  int _calculateTotalChunks({
    required int payloadSize,
    required int firstChunkPayloadCapacity,
    required int chunkSize,
  }) {
    if (payloadSize <= firstChunkPayloadCapacity) {
      return 1;
    }
    final remaining = payloadSize - firstChunkPayloadCapacity;
    return 1 + ((remaining + chunkSize - 1) ~/ chunkSize);
  }

  /// 生成密码学安全随机字节
  Uint8List _generateSecureRandomBytes(int length) {
    final random = Random.secure();
    final bytes = Uint8List(length);
    for (var i = 0; i < length; i++) {
      bytes[i] = random.nextInt(256);
    }
    return bytes;
  }

  /// AES-256-GCM 加密单个分块
  ///
  /// 返回密文（含 GCM 16 字节认证标签）。
  Uint8List _encryptAesGcm(Uint8List plaintext, Uint8List key, Uint8List iv) {
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );
    final encrypted = encrypter.encryptBytes(plaintext, iv: enc.IV(iv));
    return encrypted.bytes;
  }

  /// AES-256-GCM 解密单个分块
  ///
  /// [ciphertext] 包含 GCM 16 字节认证标签的密文。
  /// 返回解密后的明文字节。
  Uint8List _decryptAesGcm(Uint8List ciphertext, Uint8List key, Uint8List iv) {
    try {
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv)),
      );
    } catch (e) {
      throw CryptoException(
        '分块解密失败：可能是密钥错误或数据已损坏。详情：$e',
        code: 'CHUNK_DECRYPTION_FAILED',
      );
    }
  }

  @override
  Uint8List decryptLegacyContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  }) {
    final ciphertext = base64Decode(encryptedDataBase64);
    final iv = base64Decode(ivBase64);
    return _decryptAesGcm(
      Uint8List.fromList(ciphertext),
      key,
      Uint8List.fromList(iv),
    );
  }
}

/// Parameters for PBKDF2 key derivation (must be serializable for compute/Isolate).
class _DeriveKeyParams {
  final String passphrase;
  final Uint8List salt;
  final int iterations;

  _DeriveKeyParams({
    required this.passphrase,
    required this.salt,
    required this.iterations,
  });
}

/// Top-level function for PBKDF2 key derivation in a background Isolate.
///
/// Must be a top-level function because [compute] requires functions that are
/// serializable and accessible without capturing any closure context.
Uint8List _deriveKeyFromPassphraseIsolate(_DeriveKeyParams params) {
  final hmac = HMac.withDigest(SHA256Digest());
  final derivator = PBKDF2KeyDerivator(hmac)
    ..init(Pbkdf2Parameters(params.salt, params.iterations, KEY_LENGTH_BYTES));

  return Uint8List.fromList(
    derivator.process(Uint8List.fromList(utf8.encode(params.passphrase))),
  );
}

/// Isolate 参数：单个分块加密所需的数据
class _ChunkEncryptParams {
  const _ChunkEncryptParams({required this.plaintext, required this.key});

  final Uint8List plaintext;
  final Uint8List key;
}

/// Isolate 返回值：单个分块加密结果
class _ChunkEncryptResult {
  const _ChunkEncryptResult({required this.iv, required this.encryptedData});

  final Uint8List iv;
  final Uint8List encryptedData;
}

/// Isolate 参数：单个分块解密所需的数据
class _ChunkDecryptParams {
  const _ChunkDecryptParams({
    required this.ciphertext,
    required this.key,
    required this.iv,
  });

  final Uint8List ciphertext;
  final Uint8List key;
  final Uint8List iv;
}

/// 生成密码学安全随机字节（顶层函数，供 Isolate 调用）
Uint8List _generateSecureRandomBytesStatic(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// AES-256-GCM 加密（顶层函数，供 Isolate 调用）
Uint8List _encryptAesGcmStatic(
  Uint8List plaintext,
  Uint8List key,
  Uint8List iv,
) {
  final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
  final encrypted = encrypter.encryptBytes(plaintext, iv: enc.IV(iv));
  return encrypted.bytes;
}

/// 在 Isolate 中执行单个分块的 AES-256-GCM 加密
///
/// 必须是顶层函数，因为 [compute] 要求可序列化的顶层函数。
/// 每次调用生成新的随机 IV 并加密。
_ChunkEncryptResult _encryptChunkInIsolate(_ChunkEncryptParams params) {
  final iv = _generateSecureRandomBytesStatic(16); // CHUNK_IV_LENGTH_BYTES = 16
  final encrypted = _encryptAesGcmStatic(params.plaintext, params.key, iv);
  return _ChunkEncryptResult(iv: iv, encryptedData: encrypted);
}

/// AES-256-GCM 解密（顶层函数，供 Isolate 调用）
Uint8List _decryptAesGcmStatic(
  Uint8List ciphertext,
  Uint8List key,
  Uint8List iv,
) {
  try {
    final encrypter = enc.Encrypter(
      enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
    );
    return Uint8List.fromList(
      encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv)),
    );
  } catch (e) {
    throw CryptoException(
      '分块解密失败：可能是密钥错误或数据已损坏。详情：$e',
      code: 'CHUNK_DECRYPTION_FAILED',
    );
  }
}

/// 在 Isolate 中执行单个分块的 AES-256-GCM 解密
///
/// 必须是顶层函数，因为 [compute] 要求可序列化的顶层函数。
Uint8List _decryptChunkInIsolate(_ChunkDecryptParams params) {
  return _decryptAesGcmStatic(params.ciphertext, params.key, params.iv);
}
