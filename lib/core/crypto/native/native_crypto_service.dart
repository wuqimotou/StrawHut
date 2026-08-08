import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter/foundation.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';
import 'package:pointycastle/block/modes/gcm.dart';
import 'package:pointycastle/digests/sha256.dart';
import 'package:pointycastle/macs/hmac.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/crypto/native/ffi_crypto_channel.dart';
import 'package:strawhut/core/crypto/native/method_channel_crypto_channel.dart';
import 'package:strawhut/core/crypto/native/parallel_chunk_processor.dart';
import 'package:strawhut/core/crypto/native/platform_crypto_channel.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';

/// 原生加密服务实现
///
/// 通过 [PlatformCryptoChannel] 调用平台原生加密 API，
/// 替代基于 pointycastle + encrypt 的纯 Dart 实现。
///
/// 架构设计：
/// - 通过构造函数注入 PlatformCryptoChannel，不直接依赖平台判断
/// - Windows FFI 同步调用对大内容（>64KB）自动移入 Isolate
/// - Android MethodChannel 本身异步，不阻塞 UI
///
/// 分块加密/解密说明：
/// - 当前 [PlatformCryptoChannel.encryptAesGcm] 不支持传入自定义 IV，
///   因此分块加密/解密操作使用 `encrypt` 包（纯 Dart AES-256-GCM）实现，
///   以确保每个分块的 IV 可控。
/// - 密钥生成和 PBKDF2 仍使用平台原生 API 获取硬件加速。
/// - 未来可通过扩展 PlatformCryptoChannel 接口（增加 encryptAesGcmWithIv）
///   来实现分块操作的原生加速。
///
/// 性能提升：
/// - PBKDF2 密钥派生：5-10x 加速（利用平台硬件加速）
/// - AES-GCM 加解密（单块模式）：3-10x 加速（利用 AES-NI 指令集）
class NativeCryptoService implements ICryptoService {
  /// 创建原生加密服务
  ///
  /// [integrityService] 用于加密/解密流程中的完整性校验
  /// [_channel] 平台加密通道（通过 PlatformCryptoChannel 抽象）
  NativeCryptoService(this.integrityService, this._channel)
      : _parallelProcessor = ParallelChunkProcessor();

  /// 完整性校验服务依赖
  final IntegrityService integrityService;

  /// 平台加密通道
  final PlatformCryptoChannel _channel;

  /// 并发分块处理器（多核并行加解密）
  final ParallelChunkProcessor _parallelProcessor;

  /// 当前平台是否支持原生加密
  static bool get isNativeSupported => Platform.isAndroid || Platform.isWindows;

  /// 创建当前平台的 PlatformCryptoChannel 实例
  ///
  /// 根据当前运行平台自动选择合适的通道实现：
  /// - Android: MethodChannelCryptoChannel
  /// - Windows: FfiCryptoChannel
  /// - 其他平台: 抛出 UnsupportedError
  static PlatformCryptoChannel createChannel() {
    if (Platform.isAndroid) {
      return MethodChannelCryptoChannel();
    } else if (Platform.isWindows) {
      return FfiCryptoChannel();
    }
    throw UnsupportedError('不支持的平台: ${Platform.operatingSystem}');
  }

  @override
  Future<GeneratedKey> generateKey() async {
    final bytes = await _channel.generateRandom(KEY_LENGTH_BYTES);
    return GeneratedKey(bytes: bytes, base64: base64Encode(bytes));
  }

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
      final result = await _channel.deriveKeyPBKDF2(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
        keyLength: KEY_LENGTH_BYTES,
      );
      cancellationToken?.throwIfCancelled();
      return result;
    }
    // Windows 版本不支持原生 PBKDF2，需捕获 UnsupportedError 向上抛出
    // ignore: avoid_catching_errors
    on UnsupportedError {
      rethrow;
    } on OperationCancelledException {
      rethrow;
    } catch (e) {
      throw CryptoException('密钥派生失败：$e', code: 'KEY_DERIVATION_FAILED');
    }
  }

  @override
  void clearSensitiveData() {
    // 当前实现为无状态设计，与 CryptoService 一致
  }

  /// 加密载荷（统一接口）
  ///
  /// 使用 `encrypt` 包实现分块加密，确保每个分块的 IV 可控。
  /// 未来可扩展 PlatformCryptoChannel 接口以支持原生加速。
  @override
  Future<EncryptResult> encrypt({
    required Uint8List payloadBytes,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
    bool useV21Security = true,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

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
      payloadSize: payloadBytes.length,
      firstChunkPayloadCapacity: firstChunkPayloadCapacity,
      chunkSize: chunkSize,
    );

    final chunks = <ChunkInfo>[];
    var payloadOffset = 0;

    // ---- 第一个分块 ----
    final firstPayloadSize = min(
      firstChunkPayloadCapacity,
      payloadBytes.length,
    );
    final firstChunkPlaintext = Uint8List(2 + metadataLen + firstPayloadSize)
      ..[0] = metadataLen & 0xFF
      ..[1] = (metadataLen >> 8) & 0xFF
      ..setRange(2, 2 + metadataLen, metadataBytes)
      ..setRange(
        2 + metadataLen,
        2 + metadataLen + firstPayloadSize,
        payloadBytes,
      );
    payloadOffset = firstPayloadSize;

    // 使用 compute 在后台 Isolate 中加密第一个分块
    final firstResult = await compute(
      nativeEncryptChunkInIsolate,
      NativeChunkEncryptParams(
        plaintext: firstChunkPlaintext,
        key: key,
        chunkIndex: 0,
        totalChunks: totalChunks,
        useV21Security: useV21Security,
      ),
    );
    cancellationToken?.throwIfCancelled();
    chunks.add(
      ChunkInfo(iv: firstResult.iv, encryptedData: firstResult.encryptedData),
    );
    onProgress?.call(1, totalChunks);

    // ---- 后续分块：预切分后并行加密 ----
    final remainingPlaintextChunks = <Uint8List>[];
    while (payloadOffset < payloadBytes.length) {
      final chunkPayloadSize = min(
        chunkSize,
        payloadBytes.length - payloadOffset,
      );
      remainingPlaintextChunks.add(
        Uint8List.fromList(
          payloadBytes.sublist(payloadOffset, payloadOffset + chunkPayloadSize),
        ),
      );
      payloadOffset += chunkPayloadSize;
    }

    if (remainingPlaintextChunks.isNotEmpty) {
      final parallelResults = await _parallelProcessor.encryptChunks(
        plaintextChunks: remainingPlaintextChunks,
        startIndex: 1,
        totalChunks: totalChunks,
        key: key,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
        onProgress: (completed, total) {
          // completed 是后续分块完成数，加上第一块已完成的 1
          onProgress?.call(completed + 1, total);
        },
      );
      for (final result in parallelResults) {
        chunks.add(
          ChunkInfo(iv: result.iv, encryptedData: result.encryptedData),
        );
      }
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
  /// 使用 `encrypt` 包实现分块解密。
  @override
  Future<DecryptResult> decrypt({
    required List<ChunkInfo> chunks,
    required Uint8List key,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
    bool useV21Security = false,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

    if (chunks.isEmpty) {
      throw const CryptoException('分块列表为空，无法解密', code: 'EMPTY_CHUNKS');
    }

    final totalChunks = chunks.length;

    // ---- 解密第一个分块（在 Isolate 中） ----
    final firstPlaintext = await compute(
      nativeDecryptChunkInIsolate,
      NativeChunkDecryptParams(
        ciphertext: chunks[0].encryptedData,
        key: key,
        iv: chunks[0].iv,
        chunkIndex: 0,
        totalChunks: totalChunks,
        useV21Security: useV21Security,
      ),
    );
    cancellationToken?.throwIfCancelled();
    onProgress?.call(1, chunks.length);

    // 提取元数据长度（uint16 LE）
    if (firstPlaintext.length < 2) {
      throw const CryptoException(
        '第一个分块过小，无法读取元数据长度',
        code: 'FIRST_CHUNK_TOO_SMALL',
      );
    }
    final metadataLen = firstPlaintext[0] | (firstPlaintext[1] << 8);

    if (firstPlaintext.length < 2 + metadataLen) {
      throw const CryptoException('第一个分块过小，元数据被截断', code: 'METADATA_TRUNCATED');
    }

    final metadataBytes = Uint8List.fromList(
      firstPlaintext.sublist(2, 2 + metadataLen),
    );
    final payloadMetadata = PayloadMetadata.fromBytes(metadataBytes);

    final firstPayloadPart = firstPlaintext.sublist(2 + metadataLen);

    // ---- 解密后续分块：并行处理 ----
    final payloadParts = <Uint8List>[Uint8List.fromList(firstPayloadPart)];
    if (chunks.length > 1) {
      final remainingCiphertext = <Uint8List>[];
      final remainingIv = <Uint8List>[];
      for (var i = 1; i < chunks.length; i++) {
        remainingCiphertext.add(chunks[i].encryptedData);
        remainingIv.add(chunks[i].iv);
      }

      final parallelResults = await _parallelProcessor.decryptChunks(
        ciphertextList: remainingCiphertext,
        ivList: remainingIv,
        startIndex: 1,
        totalChunks: totalChunks,
        key: key,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
        onProgress: (completed, total) {
          // completed 是后续分块完成数，加上第一块已完成的 1
          onProgress?.call(completed + 1, chunks.length);
        },
      );
      payloadParts.addAll(parallelResults);
    }

    // ---- 拼接完整载荷 ----
    final totalSize = payloadParts.fold<int>(
      0,
      (sum, part) => sum + part.length,
    );
    final payloadBytes = Uint8List(totalSize);
    var offset = 0;
    for (final part in payloadParts) {
      cancellationToken?.throwIfCancelled();
      payloadBytes.setRange(offset, offset + part.length, part);
      offset += part.length;
      await Future<void>.delayed(Duration.zero);
    }

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
  /// 使用平台通道的 generateRandom 生成 IV，encrypt 包执行 AES-GCM 加密。
  @override
  Future<EncryptResult> encryptStream({
    required String sourcePath,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
    bool useV21Security = true,
    CancellationToken? cancellationToken,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

    final file = File(sourcePath);
    // 检查源文件是否存在
    // ignore: avoid_slow_async_io
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

      final firstChunkPlaintext = Uint8List(2 + metadataLen + firstPayloadSize)
        ..[0] = metadataLen & 0xFF
        ..[1] = (metadataLen >> 8) & 0xFF
        ..setRange(2, 2 + metadataLen, metadataBytes)
        ..setRange(
          2 + metadataLen,
          2 + metadataLen + firstPayloadSize,
          firstPayloadData,
        );

      // 使用 compute 在后台 Isolate 中加密第一个分块
      final firstResult = await compute(
        nativeEncryptChunkInIsolate,
        NativeChunkEncryptParams(
          plaintext: firstChunkPlaintext,
          key: key,
          chunkIndex: 0,
          totalChunks: totalChunks,
          useV21Security: useV21Security,
        ),
      );
      cancellationToken?.throwIfCancelled();
      chunks.add(
        ChunkInfo(iv: firstResult.iv, encryptedData: firstResult.encryptedData),
      );
      onProgress?.call(1, totalChunks);

      // ---- 后续分块：分批预读 + 并行加密 ----
      // 策略：每批预读 concurrency 个分块到内存，并行加密后追加到 chunks，
      // 再读下一批。避免预读所有分块导致大文件 OOM，同时利用多核加速。
      var chunkIndex = 1;
      final batchSize = _parallelProcessor.concurrency;
      while (await raf.position() < fileSize) {
        cancellationToken?.throwIfCancelled();
        // 预读一批分块（最多 batchSize 个）
        final batchPlaintexts = <Uint8List>[];
        while (batchPlaintexts.length < batchSize &&
            await raf.position() < fileSize) {
          final remaining = fileSize - await raf.position();
          final readSize = min(chunkSize, remaining);
          final chunkData = await raf.read(readSize);
          batchPlaintexts.add(Uint8List.fromList(chunkData));
        }

        // 并行加密本批分块
        final batchResults = await _parallelProcessor.encryptChunks(
          plaintextChunks: batchPlaintexts,
          startIndex: chunkIndex,
          totalChunks: totalChunks,
          key: key,
          useV21Security: useV21Security,
          cancellationToken: cancellationToken,
          onProgress: (completed, total) {
            // completed 是本批已完成数，需要加上之前已完成的 chunkIndex
            onProgress?.call(chunkIndex + completed, total);
          },
        );

        for (final result in batchResults) {
          chunks.add(
            ChunkInfo(
              iv: result.iv,
              encryptedData: result.encryptedData,
            ),
          );
        }
        chunkIndex += batchPlaintexts.length;
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
  /// 使用 encrypt 包执行 AES-GCM 解密，逐块写入目标文件。
  @override
  Future<DecryptStreamResult> decryptStream({
    required String strawFilePath,
    required Uint8List key,
    required String targetPath,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
    bool useV21Security = false,
    IntegritySink? integritySink,
  }) async {
    cancellationToken?.throwIfCancelled();
    _validateKeyLength(key);

    final file = File(strawFilePath);
    // 检查文件是否存在
    // ignore: avoid_slow_async_io
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
        throw const CryptoException(
          '文件头部格式错误：无法读取头部长度',
          code: 'INVALID_FILE_FORMAT',
        );
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
      var bytesWritten = 0;

      // 读取单个分块的辅助函数（含校验 + IntegritySink 更新）
      Future<({Uint8List iv, Uint8List ciphertext})> readOneChunk(
        int chunkIndex,
      ) async {
        final chunkHeader = await raf.read(CHUNK_IV_LENGTH_BYTES + 4);
        if (chunkHeader.length < CHUNK_IV_LENGTH_BYTES + 4) {
          throw CryptoException(
            '分块 $chunkIndex 头部数据不完整：期望 ${CHUNK_IV_LENGTH_BYTES + 4} 字节， '
            '实际 ${chunkHeader.length} 字节',
            code: 'INVALID_FILE_FORMAT',
          );
        }
        final ivBytes =
            Uint8List.fromList(chunkHeader.sublist(0, CHUNK_IV_LENGTH_BYTES));
        final encDataLen =
            chunkHeader[CHUNK_IV_LENGTH_BYTES] |
            (chunkHeader[CHUNK_IV_LENGTH_BYTES + 1] << 8) |
            (chunkHeader[CHUNK_IV_LENGTH_BYTES + 2] << 16) |
            (chunkHeader[CHUNK_IV_LENGTH_BYTES + 3] << 24);

        final encDataBytes = await raf.read(encDataLen);
        if (encDataBytes.length < encDataLen) {
          throw CryptoException(
            '分块 $chunkIndex 加密数据不完整：期望 $encDataLen 字节， '
            '实际 ${encDataBytes.length} 字节',
            code: 'INVALID_FILE_FORMAT',
          );
        }

        // 边读边算：IntegritySink 在预读阶段同步更新（与解密并行）
        if (integritySink != null) {
          integritySink
            ..updateChunkIv(ivBytes)
            ..updateChunkLength(
              chunkHeader.sublist(
                CHUNK_IV_LENGTH_BYTES,
                CHUNK_IV_LENGTH_BYTES + 4,
              ),
            )
            ..updateChunkCipher(encDataBytes);
        }

        return (iv: ivBytes, ciphertext: encDataBytes);
      }

      try {
        // ---- 第一块：串行处理（含 metadata 提取） ----
        cancellationToken?.throwIfCancelled();
        final firstChunk = await readOneChunk(0);
        final firstPlaintext = await compute(
          nativeDecryptChunkInIsolate,
          NativeChunkDecryptParams(
            ciphertext: firstChunk.ciphertext,
            key: key,
            iv: firstChunk.iv,
            chunkIndex: 0,
            totalChunks: totalChunks,
            useV21Security: useV21Security,
          ),
        );
        cancellationToken?.throwIfCancelled();

        if (firstPlaintext.length < 2) {
          throw const CryptoException(
            '第一个分块过小，无法读取元数据长度',
            code: 'FIRST_CHUNK_TOO_SMALL',
          );
        }
        final metadataLen = firstPlaintext[0] | (firstPlaintext[1] << 8);
        if (firstPlaintext.length < 2 + metadataLen) {
          throw const CryptoException(
            '第一个分块过小，元数据被截断',
            code: 'METADATA_TRUNCATED',
          );
        }
        final metadataBytes = Uint8List.fromList(
          firstPlaintext.sublist(2, 2 + metadataLen),
        );
        payloadMetadata = PayloadMetadata.fromBytes(metadataBytes);
        final firstPayloadPart = firstPlaintext.sublist(2 + metadataLen);
        if (firstPayloadPart.isNotEmpty) {
          await targetRaf.writeFrom(firstPayloadPart);
          bytesWritten += firstPayloadPart.length;
        }
        onProgress?.call(1, totalChunks);

        // ---- 后续分块：分批预读 + 并行解密 + 按顺序写出 ----
        if (totalChunks > 1) {
          var processedCount = 1; // 已处理分块数（含第一块）
          final batchSize = _parallelProcessor.concurrency;

          while (processedCount < totalChunks) {
            cancellationToken?.throwIfCancelled();

            // 预读一批分块（同时更新 IntegritySink）
            final batchIv = <Uint8List>[];
            final batchCiphertext = <Uint8List>[];
            final batchStartIndex = processedCount;
            while (batchCiphertext.length < batchSize &&
                processedCount < totalChunks) {
              final chunk = await readOneChunk(processedCount);
              batchIv.add(chunk.iv);
              batchCiphertext.add(chunk.ciphertext);
              processedCount++;
            }

            // 并行解密本批分块
            final batchPlaintexts = await _parallelProcessor.decryptChunks(
              ciphertextList: batchCiphertext,
              ivList: batchIv,
              startIndex: batchStartIndex,
              totalChunks: totalChunks,
              key: key,
              useV21Security: useV21Security,
              cancellationToken: cancellationToken,
              onProgress: (completed, total) {
                // completed 是本批已完成数，加上之前已完成的 batchStartIndex
                onProgress?.call(batchStartIndex + completed, total);
              },
            );

            // 按顺序写出明文
            for (final plaintext in batchPlaintexts) {
              await targetRaf.writeFrom(plaintext);
              bytesWritten += plaintext.length;
            }
          }
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
        payloadMetadata: payloadMetadata,
        targetPath: targetPath,
      );
    } on OperationCancelledException {
      final partialFile = File(targetPath);
      // 删除可能已部分写入的目标文件
      // ignore: avoid_slow_async_io
      if (await partialFile.exists()) {
        await partialFile.delete();
      }
      rethrow;
    } catch (e) {
      final partialFile = File(targetPath);
      // 删除可能已部分写入的目标文件
      // ignore: avoid_slow_async_io
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

  /// AES-256-GCM 解密单个分块（使用 encrypt 包）
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

  /// 从加密密钥派生 HMAC 密钥（v2.1 容器认证）
  ///
  /// 与 [CryptoService.deriveHmacKey] 实现一致：
  /// `hmacKey = HMAC-SHA256(encryptionKey, UTF8(STRAWHUT_V21_HMAC_KEY_LABEL))`
  @override
  Uint8List deriveHmacKey(Uint8List encryptionKey) {
    _validateKeyLength(encryptionKey);
    return _nativeDeriveHmacKeyStatic(encryptionKey);
  }
}

/// Isolate 参数：单个分块加密所需的数据
class NativeChunkEncryptParams {
  const NativeChunkEncryptParams({
    required this.plaintext,
    required this.key,
    required this.chunkIndex,
    required this.totalChunks,
    required this.useV21Security,
  });

  final Uint8List plaintext;
  final Uint8List key;
  final int chunkIndex;
  final int totalChunks;
  final bool useV21Security;
}

/// Isolate 返回值：单个分块加密结果
class NativeChunkEncryptResult {
  const NativeChunkEncryptResult({
    required this.iv,
    required this.encryptedData,
  });

  final Uint8List iv;
  final Uint8List encryptedData;
}

/// Isolate 参数：单个分块解密所需的数据
class NativeChunkDecryptParams {
  const NativeChunkDecryptParams({
    required this.ciphertext,
    required this.key,
    required this.iv,
    required this.chunkIndex,
    required this.totalChunks,
    required this.useV21Security,
  });

  final Uint8List ciphertext;
  final Uint8List key;
  final Uint8List iv;
  final int chunkIndex;
  final int totalChunks;
  final bool useV21Security;
}

/// 生成密码学安全随机字节（顶层函数，供 Isolate 调用）
///
/// 注意：PlatformCryptoChannel 不能跨 Isolate 传递，
/// 因此在 Isolate 中使用 Dart 内置的 Random.secure() 生成随机字节。
Uint8List _nativeGenerateSecureRandomBytesStatic(int length) {
  final random = Random.secure();
  final bytes = Uint8List(length);
  for (var i = 0; i < length; i++) {
    bytes[i] = random.nextInt(256);
  }
  return bytes;
}

/// 构建 v2.1 容器认证的 AAD（顶层函数，供 Isolate 调用）
///
/// AAD = UTF8(STRAWHUT_V21_AAD_DOMAIN_SEPARATOR) +
/// u32LE(chunkIndex) + u32LE(totalChunks)
Uint8List _nativeBuildAadV21Static(int chunkIndex, int totalChunks) {
  final domainBytes = utf8.encode(STRAWHUT_V21_AAD_DOMAIN_SEPARATOR);
  final aad = Uint8List(domainBytes.length + 8)
    ..setRange(0, domainBytes.length, domainBytes)
    ..[domainBytes.length] = chunkIndex & 0xFF
    ..[domainBytes.length + 1] = (chunkIndex >> 8) & 0xFF
    ..[domainBytes.length + 2] = (chunkIndex >> 16) & 0xFF
    ..[domainBytes.length + 3] = (chunkIndex >> 24) & 0xFF
    ..[domainBytes.length + 4] = totalChunks & 0xFF
    ..[domainBytes.length + 5] = (totalChunks >> 8) & 0xFF
    ..[domainBytes.length + 6] = (totalChunks >> 16) & 0xFF
    ..[domainBytes.length + 7] = (totalChunks >> 24) & 0xFF;
  return aad;
}

/// 从加密密钥派生 HMAC 密钥（顶层函数，供 Isolate 调用）
///
/// `hmacKey = HMAC-SHA256(encryptionKey, UTF8(STRAWHUT_V21_HMAC_KEY_LABEL))`
Uint8List _nativeDeriveHmacKeyStatic(Uint8List encryptionKey) {
  final hmac = HMac.withDigest(SHA256Digest())
    ..init(KeyParameter(encryptionKey));
  final labelBytes = utf8.encode(STRAWHUT_V21_HMAC_KEY_LABEL);
  return hmac.process(Uint8List.fromList(labelBytes));
}

/// AES-256-GCM 加密（顶层函数，供 Isolate 调用）
///
/// v2.0 模式：不使用 AAD（[aad] 为 null）
/// v2.1 模式：使用 AAD 绑定分块上下文（[aad] 非空）
Uint8List _nativeEncryptAesGcmStatic(
  Uint8List plaintext,
  Uint8List key,
  Uint8List iv, {
  Uint8List? aad,
}) {
  if (aad == null) {
    // v2.0 兼容路径：使用 encrypt 包的 GCM（不暴露 AAD）
    final encrypter =
        enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.gcm));
    final encrypted = encrypter.encryptBytes(plaintext, iv: enc.IV(iv));
    return encrypted.bytes;
  }

  // v2.1 路径：直接使用 pointycastle 的 GCMBlockCipher 以支持 AAD
  final cipher = GCMBlockCipher(AESEngine())
    ..init(
      true,
      AEADParameters(KeyParameter(key), GCM_TAG_LENGTH_BYTES * 8, iv, aad),
    );
  // GCM 加密输出 = 明文长度 + 认证标签长度
  final output = Uint8List(plaintext.length + GCM_TAG_LENGTH_BYTES);
  var offset = cipher.processBytes(plaintext, 0, plaintext.length, output, 0);
  offset += cipher.doFinal(output, offset);
  return Uint8List.fromList(output.sublist(0, offset));
}

/// 在 Isolate 中执行单个分块的 AES-256-GCM 加密
///
/// 必须是顶层函数，因为 [compute] 要求可序列化的顶层函数。
/// 每次调用生成新的随机 IV 并加密。
/// 根据 params.useV21Security 决定是否绑定 AAD。
NativeChunkEncryptResult nativeEncryptChunkInIsolate(
  NativeChunkEncryptParams params,
) {
  final iv = _nativeGenerateSecureRandomBytesStatic(16);
  final aad = params.useV21Security
      ? _nativeBuildAadV21Static(params.chunkIndex, params.totalChunks)
      : null;
  final encrypted = _nativeEncryptAesGcmStatic(
    params.plaintext,
    params.key,
    iv,
    aad: aad,
  );
  return NativeChunkEncryptResult(iv: iv, encryptedData: encrypted);
}

/// AES-256-GCM 解密（顶层函数，供 Isolate 调用）
///
/// v2.0 模式：不使用 AAD（[aad] 为 null）
/// v2.1 模式：使用 AAD 绑定分块上下文（[aad] 非空）
Uint8List _nativeDecryptAesGcmStatic(
  Uint8List ciphertext,
  Uint8List key,
  Uint8List iv, {
  Uint8List? aad,
}) {
  try {
    if (aad == null) {
      // v2.0 兼容路径：使用 encrypt 包的 GCM
      final encrypter = enc.Encrypter(
        enc.AES(enc.Key(key), mode: enc.AESMode.gcm),
      );
      return Uint8List.fromList(
        encrypter.decryptBytes(enc.Encrypted(ciphertext), iv: enc.IV(iv)),
      );
    }

    // v2.1 路径：直接使用 pointycastle 的 GCMBlockCipher
    final cipher = GCMBlockCipher(AESEngine())
      ..init(
        false,
        AEADParameters(KeyParameter(key), GCM_TAG_LENGTH_BYTES * 8, iv, aad),
      );
    // GCM 解密输出 = 密文长度 - 认证标签长度（分配密文长度足够安全）
    final output = Uint8List(ciphertext.length);
    var offset =
        cipher.processBytes(ciphertext, 0, ciphertext.length, output, 0);
    offset += cipher.doFinal(output, offset);
    return Uint8List.fromList(output.sublist(0, offset));
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
/// 根据 params.useV21Security 决定是否绑定 AAD。
Uint8List nativeDecryptChunkInIsolate(NativeChunkDecryptParams params) {
  final aad = params.useV21Security
      ? _nativeBuildAadV21Static(params.chunkIndex, params.totalChunks)
      : null;
  return _nativeDecryptAesGcmStatic(
    params.ciphertext,
    params.key,
    params.iv,
    aad: aad,
  );
}
