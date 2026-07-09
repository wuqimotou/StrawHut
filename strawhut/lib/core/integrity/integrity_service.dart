import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 完整性校验服务接口
///
/// 定义文件完整性校验的契约。通过 SHA-256 哈希算法验证文件内容是否被篡改。
///
/// 使用场景：
/// - 发布流程：加密内容写入 .straw 文件前，计算完整 JSON 的 SHA-256 哈希
/// - 解密流程：读取 .straw 文件后，重新计算哈希与文件中存储的哈希比对
/// - 密钥文件：.key 文件同样包含 integrity 字段，使用相同机制校验
/// - 迁移流程：二进制 .straw 文件的完整性哈希计算
///
/// 架构位置：核心服务层（Core Service Layer）
/// 被依赖方：CryptoService（发布流程）、DecryptDialog（解密流程）、MigrationService（迁移流程）
abstract class IIntegrityService {
  /// 计算文件内容的 SHA-256 哈希值
  ///
  /// 对输入的完整 JSON 字符串计算 SHA-256 哈希，返回格式为 "sha256:{十六进制哈希值}"。
  ///
  /// 参数：[content] - 完整的 JSON 字符串（.straw 或 .key 文件内容）
  /// 返回：格式为 "sha256:abcdef1234567890..." 的哈希字符串
  String computeHash(String content);

  /// 计算二进制字节数据的 SHA-256 哈希值
  ///
  /// 对输入的字节数据计算 SHA-256 哈希，用于二进制 .straw 文件的完整性校验。
  /// 与 [computeHash] 不同，此方法直接处理字节数据而非字符串，
  /// 避免不必要的编码/解码开销，适用于二进制容器格式的哈希计算。
  ///
  /// 参数：[bytes] - 二进制文件字节数据
  /// 返回：格式为 "sha256:abcdef1234567890..." 的哈希字符串
  String computeHashFromBytes(Uint8List bytes);

  /// 从 .straw 文件流式计算 SHA-256 哈希值
  ///
  /// 逐块读取文件并更新哈希，避免将整个文件加载到内存。
  /// 适用于大文件场景，与 [computeHashFromBytes] 产生完全相同的结果，
  /// 但内存占用仅为常数级。
  ///
  /// 计算的哈希覆盖整个 .straw 二进制文件内容，格式与 [FileIOService.buildBinaryFileBytes]
  /// 产生的字节序列完全一致：
  /// [Magic Bytes (8B)] + [Version Major (2B)] + [Version Minor (2B)] +
  /// [Header Size (4B)] + [JSON Header (variable)] + [Chunks (variable)]
  ///
  /// 参数：
  /// - [strawFile] - StrawFile 对象（JSON Header 部分，integrity.hash 应为空字符串）
  /// - [filePath] - .straw 二进制文件路径
  /// 返回：格式为 "sha256:abcdef1234567890..." 的哈希字符串
  Future<String> computeHashFromStrawFile({
    required StrawFile strawFile,
    required String filePath,
  });

  /// 验证文件完整性
  ///
  /// 重新计算内容的 SHA-256 哈希，与预期哈希进行比对。
  ///
  /// 参数：
  /// - [content] - 当前的文件内容（JSON 字符串）
  /// - [expectedHash] - 预期的哈希值（格式为 "sha256:{hex}"）
  /// 返回：true 表示哈希匹配，文件未被篡改；false 表示文件可能已被修改
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  });
}

/// 完整性校验服务实现
///
/// 实现 [IIntegrityService] 接口，使用 `crypto` 包的 SHA-256 算法。
///
/// 依赖的第三方库：
/// - `crypto` 包：提供 SHA-256 哈希计算（import 'package:crypto/crypto.dart'）
///
/// 哈希计算流程（computeHash）：
/// 1. 将 content 字符串转换为 UTF-8 字节数组
/// 2. 使用 crypto 包的 sha256 转换器计算哈希
/// 3. 将哈希字节转换为十六进制字符串
/// 4. 拼接为 "sha256:{hex}" 格式返回
///
/// 验证流程（verifyIntegrity）：
/// 1. 调用 computeHash(content) 计算当前内容的哈希
/// 2. 将计算结果与 expectedHash 进行字符串比对
/// 3. 返回比对结果
///
/// 使用示例：
/// ```dart
/// final integrityService = IntegrityService();
/// // 发布时计算哈希
/// final hash = integrityService.computeHash(strawFileJson);
/// // 解密时验证
/// final isValid = integrityService.verifyIntegrity(
///   content: currentFileJson,
///   expectedHash: storedHash,
/// );
/// ```
class IntegrityService implements IIntegrityService {
  /// 计算文件内容的 SHA-256 哈希值
  ///
  /// 实现说明（Phase 1）：
  /// 1. 使用 utf8.encode(content) 将字符串转为字节
  /// 2. 使用 sha256.convert(bytes) 计算哈希
  /// 3. 使用 digest.toString() 获取十六进制字符串
  /// 4. 返回 'sha256:$hex' 格式
  ///
  /// 注意：content 必须是完整的 JSON 字符串，包含 integrity 字段本身时
  /// 哈希值会不同。因此应在写入 integrity.hash 之前计算内容哈希。
  @override
  String computeHash(String content) {
    // 使用 crypto 包的 sha256 算法计算哈希
    final digest = sha256.convert(utf8.encode(content));
    return 'sha256:$digest';
  }

  /// 计算二进制字节数据的 SHA-256 哈希值
  ///
  /// 实现说明：
  /// 1. 直接对字节数据使用 sha256.convert() 计算哈希
  /// 2. 将哈希字节转换为十六进制字符串
  /// 3. 返回 'sha256:$hex' 格式
  ///
  /// 适用于二进制 .straw 容器格式的完整性校验，
  /// 直接处理字节数据避免 UTF-8 编解码开销。
  @override
  String computeHashFromBytes(Uint8List bytes) {
    final digest = sha256.convert(bytes);
    return 'sha256:$digest';
  }

  /// 从 .straw 文件流式计算 SHA-256 哈希值
  ///
  /// 逐块读取文件并更新哈希，避免将整个文件加载到内存。
  /// 适用于大文件场景，与 [computeHashFromBytes] 产生完全相同的结果，
  /// 但内存占用仅为常数级。
  ///
  /// 实现说明：
  /// 1. 构造文件头部的字节序列并更新哈希（Magic + Version + HeaderSize + JSON Header）
  /// 2. 逐块读取文件的加密分块数据并更新哈希（IV + DataSize + EncryptedData）
  /// 3. 生成最终哈希值
  ///
  /// 格式必须与 [FileIOService.buildBinaryFileBytes] 产生的字节序列完全一致。
  @override
  Future<String> computeHashFromStrawFile({
    required StrawFile strawFile,
    required String filePath,
  }) async {
    // 完整性校验需要计算 hash='' 版本的二进制文件哈希，
    // 与加密时 computeHashFromBytes(buildBinaryFileBytes(strawFileForHash, chunks)) 一致。
    //
    // 最安全的做法：直接用 StrawFile 对象的 assembleHeaderToJson() 生成 JSON 头部
    // （与 buildBinaryFileBytes 中使用的完全相同），然后从文件流式读取分块数据。
    final digestCollector = <Digest>[];
    final outputSink = _SimpleSink<Digest>(digestCollector);
    final input = sha256.startChunkedConversion(outputSink);

    // ========== 1. 构造头部字节（与 buildBinaryFileBytes 逻辑一致） ==========
    // Magic Bytes: "STRAWHUT" (8 bytes)
    input.add(STRAW_MAGIC_BYTES);

    // Format Version Major (2 bytes uint16 LE)
    input.add([BINARY_FORMAT_MAJOR & 0xFF, (BINARY_FORMAT_MAJOR >> 8) & 0xFF]);

    // Format Version Minor (2 bytes uint16 LE)
    input.add([BINARY_FORMAT_MINOR & 0xFF, (BINARY_FORMAT_MINOR >> 8) & 0xFF]);

    // JSON Header（strawFile 中的 integrity.hash 应为空字符串）
    final headerJson = strawFile.assembleHeaderToJson();
    final headerBytes = utf8.encode(headerJson);

    // Header Size (4 bytes uint32 LE)
    final headerSize = headerBytes.length;
    input.add([
      headerSize & 0xFF,
      (headerSize >> 8) & 0xFF,
      (headerSize >> 16) & 0xFF,
      (headerSize >> 24) & 0xFF,
    ]);

    // JSON Header bytes
    input.add(headerBytes);

    // ========== 2. 从文件中流式读取分块数据 ==========
    final file = File(filePath);
    final raf = await file.open();

    try {
      // 跳过头部：Magic(8) + Version(4) + HeaderSize(4) + HeaderJson(文件中的实际大小)
      // 注意：文件中的 headerJson 包含实际哈希值（比 hash='' 版本更大），
      // 所以需要读取文件中的 headerSize 来正确定位分块数据
      await raf.setPosition(MAGIC_BYTES_LENGTH + 4); // 跳过 Magic + Version

      // 读取文件中的 Header Size
      final headerSizeData = await raf.read(4);
      final fileHeaderSize = headerSizeData[0] |
          (headerSizeData[1] << 8) |
          (headerSizeData[2] << 16) |
          (headerSizeData[3] << 24);

      // 跳过 JSON Header 字节
      await raf.setPosition(MAGIC_BYTES_LENGTH + 4 + 4 + fileHeaderSize);

      // 逐块读取分块数据
      final totalChunks = strawFile.content.totalChunks;

      for (int i = 0; i < totalChunks; i++) {
        // 读取 IV (16 bytes)
        final ivData = await raf.read(CHUNK_IV_LENGTH_BYTES);
        if (ivData.length < CHUNK_IV_LENGTH_BYTES) break;
        input.add(ivData);

        // 读取 encrypted_data_length (4 bytes uint32 LE)
        final lenData = await raf.read(4);
        if (lenData.length < 4) break;
        input.add(lenData);

        // 读取加密数据
        final encLen = lenData[0] |
            (lenData[1] << 8) |
            (lenData[2] << 16) |
            (lenData[3] << 24);
        final encData = await raf.read(encLen);
        if (encData.length < encLen) break;
        input.add(encData);
      }
    } finally {
      await raf.close();
    }

    // 完成哈希计算
    input.close();
    final digest = digestCollector.single;
    return 'sha256:$digest';
  }

  /// 验证文件完整性
  ///
  /// 实现说明（Phase 1）：
  /// 1. 调用 computeHash(content) 重新计算当前内容的哈希
  /// 2. 与 expectedHash 进行字符串比对
  /// 3. 返回 true/false
  ///
  /// 注意：expectedHash 的格式应为 "sha256:{hex}"，
  /// 计算结果也使用相同格式，因此可以直接字符串比较。
  @override
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  }) {
    final computedHash = computeHash(content);
    return computedHash == expectedHash;
  }
}

/// 简单的 Sink 实现，用于收集 chunked conversion 的输出结果。
///
/// 替代 `package:convert` 中的 `AccumulatorSink`，避免额外依赖。
/// 仅用于 [IntegrityService.computeHashFromStrawFile] 方法中收集
/// 单个 [Digest] 结果。
class _SimpleSink<T> implements Sink<T> {
  _SimpleSink(this._collector);

  final List<T> _collector;

  @override
  void add(T data) {
    _collector.add(data);
  }

  @override
  void close() {
    // 无操作，结果已添加到 collector 中
  }
}
