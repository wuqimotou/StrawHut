import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 迁移结果
class MigrationResult {
  /// 创建迁移结果实例
  ///
  /// 参数：
  /// - [success] - 是否迁移成功
  /// - [outputPath] - 输出文件路径
  /// - [errorMessage] - 错误信息（仅失败时有值）
  const MigrationResult({
    required this.success,
    required this.outputPath,
    this.errorMessage,
  });

  /// 是否迁移成功
  final bool success;

  /// 输出文件路径
  final String outputPath;

  /// 错误信息（仅失败时有值）
  final String? errorMessage;
}

/// 迁移服务
///
/// 将旧版 JSON 格式的 .straw 文件迁移到新版二进制格式。
/// 调用方负责解密旧版文件内容，此服务只负责用新格式重新加密保存。
class MigrationService {
  /// 创建迁移服务实例
  ///
  /// 参数：
  /// - [cryptoService] - 加密服务实例
  /// - [integrityService] - 完整性校验服务实例
  /// - [fileIOService] - 文件 I/O 服务实例
  MigrationService({
    required ICryptoService cryptoService,
    required IntegrityService integrityService,
    required FileIOService fileIOService,
  })  : _cryptoService = cryptoService,
        _integrityService = integrityService,
        _fileIOService = fileIOService;

  final ICryptoService _cryptoService;
  final IntegrityService _integrityService;
  final FileIOService _fileIOService;

  /// 检测字节数据是否为旧版 JSON 格式
  ///
  /// 旧版文件以 `{` 开头（0x7B），新版以 "STRAWHUT" Magic Bytes 开头。
  static bool isOldFormat(Uint8List bytes) {
    if (bytes.length < 8) return false;
    // 先检查是否为新版格式（Magic Bytes "STRAWHUT"）
    var isMagicBytes = true;
    for (var i = 0; i < STRAW_MAGIC_BYTES.length; i++) {
      if (bytes[i] != STRAW_MAGIC_BYTES[i]) {
        isMagicBytes = false;
        break;
      }
    }
    if (isMagicBytes) return false;
    // 检查是否以 { 开头（旧版 JSON 格式）
    return bytes.isNotEmpty && bytes[0] == 0x7B;
  }

  /// 检测文件是否为旧版 JSON 格式
  static Future<bool> isOldFormatFile(String filePath) async {
    final file = File(filePath);
    if (!file.existsSync()) return false;
    final bytes = await file.readAsBytes();
    return isOldFormat(bytes);
  }

  /// 将已解密的旧版内容迁移到新格式
  ///
  /// [deltaJson]: 旧版解密后的 Delta JSON 字符串
  /// [meta]: 旧版的元数据
  /// [key]: 加密密钥（32 字节）
  /// [outputPath]: 新版文件输出路径
  /// [saltBase64]: 旧版协商密钥的盐值（可选）
  /// [kdfAlgorithm]: 旧版协商密钥的算法（可选）
  /// [kdfIterations]: 旧版协商密钥的迭代次数（可选）
  Future<MigrationResult> migrateFromDecryptedContent({
    required String deltaJson,
    required CardMeta meta,
    required Uint8List key,
    required String outputPath,
    String? saltBase64,
    String? kdfAlgorithm,
    int? kdfIterations,
  }) async {
    try {
      // 1. 使用新格式重新加密
      final payloadBytes = Uint8List.fromList(utf8.encode(deltaJson));
      const payloadMetadata = PayloadMetadata(
        sourceType: SourceType.richText,
        originalExtension: 'delta',
      );

      final encryptResult = await _cryptoService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: payloadMetadata,
        key: key,
      );

      // 2. 构建 StrawContent
      final strawContent = StrawContent(
        encryptionAlgorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
        chunkSize: encryptResult.chunkSize,
        totalChunks: encryptResult.totalChunks,
        originalPayloadSize: encryptResult.originalPayloadSize,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
      );

      // 3. 先构建不含 hash 的文件，计算完整性哈希
      final strawFileForHash = StrawFile(
        formatVersion: FormatVersion.fromString(STRAW_FORMAT_VERSION),
        meta: meta,
        content: strawContent,
        integrity: const IntegrityInfo(
          hash: '',
          hashAlgorithm: HASH_ALGORITHM_SHA256,
        ),
      );

      final headerJson = strawFileForHash.assembleHeaderToJson();
      final headerBytes = Uint8List.fromList(utf8.encode(headerJson));
      final fileBytesWithoutHash = _buildBinaryFileBytes(
        headerBytes: headerBytes,
        chunks: encryptResult.chunks,
      );
      final hash = _integrityService.computeHashFromBytes(fileBytesWithoutHash);

      // 4. 构建最终的 StrawFile（含完整性哈希）
      final strawFile = StrawFile(
        formatVersion: FormatVersion.fromString(STRAW_FORMAT_VERSION),
        meta: meta,
        content: strawContent,
        integrity: IntegrityInfo(
          hash: hash,
          hashAlgorithm: HASH_ALGORITHM_SHA256,
        ),
      );

      // 5. 写入新文件
      await _fileIOService.writeStrawFile(
        strawFile: strawFile,
        chunks: encryptResult.chunks,
        targetPath: outputPath,
      );

      return MigrationResult(success: true, outputPath: outputPath);
    } on Exception catch (e) {
      return MigrationResult(
        success: false,
        outputPath: outputPath,
        errorMessage: '迁移失败：$e',
      );
    }
  }

  /// 构建二进制文件字节数据（用于哈希计算）
  ///
  /// 按照 .straw v2.0 二进制格式组装文件字节：
  /// Magic Bytes + Version + Header Size + Header JSON + Chunks
  Uint8List _buildBinaryFileBytes({
    required Uint8List headerBytes,
    required List<ChunkInfo> chunks,
  }) {
    final builder = BytesBuilder()..add(STRAW_MAGIC_BYTES);
    // Version Major (uint16 LE)
    _writeUint16LE(builder, BINARY_FORMAT_MAJOR);
    // Version Minor (uint16 LE)
    _writeUint16LE(builder, BINARY_FORMAT_MINOR);
    // Header Size (uint32 LE)
    _writeUint32LE(builder, headerBytes.length);
    // Header JSON
    builder.add(headerBytes);
    // Chunks
    for (final chunk in chunks) {
      builder.add(chunk.iv);
      _writeUint32LE(builder, chunk.encryptedData.length);
      builder.add(chunk.encryptedData);
    }
    return builder.toBytes();
  }

  void _writeUint16LE(BytesBuilder builder, int value) {
    builder
      ..addByte(value & 0xFF)
      ..addByte((value >> 8) & 0xFF);
  }

  void _writeUint32LE(BytesBuilder builder, int value) {
    builder
      ..addByte(value & 0xFF)
      ..addByte((value >> 8) & 0xFF)
      ..addByte((value >> 16) & 0xFF)
      ..addByte((value >> 24) & 0xFF);
  }
}
