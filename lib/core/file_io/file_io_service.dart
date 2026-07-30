import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/core/file_io/file_extensions.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cover_image_service.dart';
import 'package:strawhut/core/validation/format_validator.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 文件 I/O 服务接口
///
/// 定义 StrawHut 文件系统操作的契约，负责：
/// - 读取和写入二进制 .straw 知识卡片文件（v2.0 格式）
/// - 读取和写入 .key 密钥文件
/// - 验证文件扩展名的正确性
///
/// 架构位置：核心服务层（Core Service Layer）
/// 被依赖方：数据层的 FileRepository、应用层的 HomeScreen 和 PublishDialog
abstract class IFileIOService {
  /// 读取 .straw 知识卡片文件
  ///
  /// 流程：
  /// 1. 验证文件扩展名是否为 .straw
  /// 2. 读取文件内容为字节数据
  /// 3. 验证 Magic Bytes（"STRAWHUT"）
  /// 4. 读取二进制版本号
  /// 5. 读取 JSON Header 并验证格式
  /// 6. 解析二进制分块数据
  /// 7. 返回 ParsedStrawFile（包含 StrawFile + List<ChunkInfo>）
  ///
  /// 参数：[filePath] - 文件的完整路径
  /// 返回：解析后的 ParsedStrawFile 对象
  /// 异常：文件不存在、格式错误、扩展名不正确时抛出异常
  Future<ParsedStrawFile> readStrawFile(String filePath);

  /// 写入 .straw 知识卡片文件
  ///
  /// 将二进制 .straw 文件写入指定路径，支持原子写入。
  ///
  /// 参数：
  /// - [strawFile] - StrawFile 对象（包含 JSON Header 信息）
  /// - [chunks] - 加密分块列表
  /// - [targetPath] - 目标文件路径
  /// - [atomic] - 是否使用原子写入（先写临时文件再重命名），默认为 true
  Future<void> writeStrawFile({
    required StrawFile strawFile,
    required List<ChunkInfo> chunks,
    required String targetPath,
    bool atomic = true,
  });

  /// 读取 .key 密钥文件
  ///
  /// 流程：
  /// 1. 验证文件扩展名是否为 .key
  /// 2. 读取文件内容（JSON 字符串）
  /// 3. 解析 JSON 为 `Map<String, dynamic>`
  /// 4. 调用 FormatValidator.validateKeyFormat() 验证格式
  /// 5. 反序列化为 KeyFile 对象并返回
  ///
  /// 参数：[filePath] - 文件的完整路径
  /// 返回：解析后的 KeyFile 对象
  /// 异常：文件不存在、格式错误、扩展名不正确时抛出异常
  Future<KeyFile> readKeyFile(String filePath);

  /// 写入 .key 密钥文件
  ///
  /// 将完整的 .key JSON 字符串写入指定路径。
  ///
  /// 参数：
  /// - [content] - 完整的 .key JSON 字符串
  /// - [targetPath] - 目标文件路径
  Future<void> writeKeyFile({
    required String content,
    required String targetPath,
  });

  /// 验证文件是否为有效的 .straw 文件
  ///
  /// 检查文件扩展名是否为 .straw。
  /// 返回 true 表示扩展名正确，但不保证文件格式有效。
  bool isValidStrawFile(String filePath);

  /// 验证文件是否为有效的 .key 文件
  ///
  /// 检查文件扩展名是否为 .key。
  /// 返回 true 表示扩展名正确，但不保证文件格式有效。
  bool isValidKeyFile(String filePath);

  /// 读取内嵌 .straw 数据的 PNG 图片
  ///
  /// 流程：
  /// 1. 验证文件扩展名是否为 .png
  /// 2. 读取文件为字节数据
  /// 3. 调用 CoverImageService.extractStrawData 提取嵌入的二进制数据
  /// 4. 解码 Base64 为字节数据，然后按二进制 .straw 格式解析
  /// 5. 返回 ParsedStrawFile 对象
  Future<ParsedStrawFile> readStrawPng(String filePath);

  /// 验证文件是否为有效的 .png 文件
  ///
  /// 检查文件扩展名是否为 .png。
  /// 返回 true 表示扩展名正确，但不保证文件格式有效。
  bool isValidPngFile(String filePath);

  /// 从文件流式读取 .straw 文件头部信息（不加载分块数据）
  ///
  /// 只读取文件头部（Magic Bytes + Version + Header JSON），
  /// 不解析加密分块数据，适用于大文件场景。
  /// 分块数据为空列表，解密时需使用 decryptStream() 而非 decrypt()。
  ///
  /// 参数：[filePath] - 文件路径
  /// 返回：ParsedStrawFile（chunks 为空列表）
  Future<ParsedStrawFile> readStrawFileHeader(String filePath);

  /// 从字节数据读取 .straw 知识卡片文件（Android content:// URI 支持）
  ///
  /// 流程：
  /// 1. 验证 Magic Bytes
  /// 2. 读取二进制版本号
  /// 3. 读取 JSON Header 并验证格式
  /// 4. 解析二进制分块数据
  /// 5. 返回 ParsedStrawFile 对象
  ///
  /// 参数：[bytes] - .straw 文件的字节数据
  /// 返回：解析后的 ParsedStrawFile 对象
  /// 异常：格式错误时抛出异常
  Future<ParsedStrawFile> readStrawFileFromBytes(Uint8List bytes);

  /// 从字节数据读取 .key 密钥文件（Android content:// URI 支持）
  ///
  /// 流程：
  /// 1. 将字节数据解码为 JSON 字符串
  /// 2. 解析 JSON 为 `Map<String, dynamic>`
  /// 3. 调用 FormatValidator.validateKeyFormat() 验证格式
  /// 4. 反序列化为 KeyFile 对象并返回
  ///
  /// 参数：[bytes] - .key 文件的字节数据
  /// 返回：解析后的 KeyFile 对象
  /// 异常：格式错误时抛出异常
  Future<KeyFile> readKeyFileFromBytes(Uint8List bytes);

  /// 从字节数据读取内嵌 .straw 数据的 PNG 图片（Android content:// URI 支持）
  ///
  /// 流程：
  /// 1. 将字节数据传给 CoverImageService.extractStrawData 提取嵌入的二进制数据
  /// 2. 按二进制 .straw 格式解析
  /// 3. 返回 ParsedStrawFile 对象
  ///
  /// 参数：[bytes] - PNG 图片的字节数据
  /// 返回：解析后的 ParsedStrawFile 对象
  /// 异常：图片不包含嵌入数据或格式错误时抛出异常
  Future<ParsedStrawFile> readStrawPngFromBytes(Uint8List bytes);

  /// 构建二进制 .straw 文件字节数据（不写入磁盘）
  ///
  /// 将 StrawFile 和加密分块列表组装为完整的二进制 .straw 字节序列。
  /// 用于需要获取字节数据但不写入文件的场景（如嵌入到 PNG 中）。
  ///
  /// 参数：
  /// - [strawFile] - StrawFile 对象（包含 JSON Header 信息）
  /// - [chunks] - 加密分块列表
  /// 返回：完整的二进制 .straw 文件字节数据
  Uint8List buildBinaryFileBytes({
    required StrawFile strawFile,
    required List<ChunkInfo> chunks,
  });

  /// 构建二进制 .straw 文件字节数据并同步计算完整性哈希
  ///
  /// 一次调用同时完成：
  /// 1. 构造 hash='' 版本的完整 bytes
  /// 2. 通过 [integritySink] 边构造边算哈希（避免单独的哈希计算 pass）
  /// 3. 用真实哈希重建 header，复用 chunks 部分
  ///
  /// 相比分别调用 [buildBinaryFileBytes] + `computeHmacFromBytes` + [buildBinaryFileBytes]，
  /// 本方法消除了一次完整 bytes 遍历和一次外部 buildBinaryFileBytes 调用。
  ///
  /// 参数：
  /// - [strawFileForHash]: StrawFile 对象（integrity.hash 应为空字符串）
  /// - [chunks]: 加密分块列表
  /// - [integritySink]: 已创建的 IntegritySink（创建时已更新 header）
  /// 返回：record (bytes: 完整二进制数据含真实哈希, hash: 计算出的哈希字符串)
  ({Uint8List bytes, String hash}) buildBinaryFileBytesWithIntegrity({
    required StrawFile strawFileForHash,
    required List<ChunkInfo> chunks,
    required IntegritySink integritySink,
  });
}

/// 文件 I/O 服务实现
///
/// 实现 [IFileIOService] 接口，使用 dart:io 的 File 类执行实际的文件操作。
/// 支持 .straw v2.0 二进制容器格式的读写。
///
/// 依赖的第三方库：
/// - `path`：跨平台路径操作（提取扩展名、拼接路径等）
/// - `dart:io`：原生文件系统操作
/// - `dart:convert`：JSON 编解码
/// - `dart:typed_data`：二进制数据处理
///
/// 架构职责：
/// - 作为核心服务层，负责文件读写的底层 I/O 操作
/// - 所有读取操作都会自动进行格式验证（安全防线）
/// - 所有写入操作信任调用方传入的内容（格式由调用方保证）
///
/// 二进制 .straw v2.0 文件格式：
/// ```
/// 0x00000000    Magic Bytes            8 bytes    "STRAWHUT" (ASCII)
/// 0x00000008    Format Version Major   2 bytes    uint16 LE, value = 2
/// 0x0000000A    Format Version Minor   2 bytes    uint16 LE, value = 0
/// 0x0000000C    Header Size            4 bytes    uint32 LE, JSON header bytes
/// 0x00000010    JSON Header            variable   UTF-8 JSON metadata
/// 0x00000010+H  Chunk 1..N            variable   encrypted chunks
/// ```
///
/// 每个分块格式：
/// ```
/// 0x00    Chunk IV           16 bytes
/// 0x10    Chunk Data Size    4 bytes    uint32 LE
/// 0x14    Encrypted Data     variable   ciphertext + GCM Tag
/// ```
class FileIOService implements IFileIOService {
  /// 格式验证器实例，用于读取文件后自动验证格式
  final FormatValidator _formatValidator = FormatValidator();

  /// 验证文件路径是否为有效的 .straw 文件
  ///
  /// 工作原理：
  /// 1. 使用 path 包的 extension() 方法从完整路径中提取文件扩展名
  /// 2. 将提取的扩展名转为小写后与 FileExtensions.straw（'.straw'）进行比较
  ///
  /// 安全意义：
  /// - 扩展名校验是文件类型识别的第一道防线，防止误读非预期格式的文件
  /// - 不区分大小写匹配，兼容 Windows/macOS 等不区分大小写的文件系统
  /// - 注意：此方法仅检查扩展名，不验证文件内容是否真正有效
  /// - 真正的格式验证在 readStrawFile() 中通过 FormatValidator 完成
  ///
  /// 参数：[filePath] - 文件的完整路径（包含文件名和扩展名）
  /// 返回：true 表示扩展名为 .straw（不区分大小写），false 表示扩展名不匹配
  @override
  bool isValidStrawFile(String filePath) {
    final extension = p.extension(filePath);
    return extension.toLowerCase() == FileExtensions.straw;
  }

  /// 验证文件路径是否为有效的 .key 文件
  @override
  bool isValidKeyFile(String filePath) {
    final extension = p.extension(filePath);
    return extension.toLowerCase() == FileExtensions.key;
  }

  @override
  bool isValidPngFile(String filePath) {
    final extension = p.extension(filePath);
    return extension.toLowerCase() == FileExtensions.png;
  }

  /// 读取 .straw 知识卡片文件
  ///
  /// 完整的读取流程（每一步都有安全考量）：
  /// 1. 扩展名校验 —— 防止误读非 .straw 文件
  /// 2. 文件存在性检查 —— 避免无效 I/O 操作，提供清晰的错误信息
  /// 3. 读取文件内容为字节数据 —— 将磁盘数据加载到内存
  /// 4. 委托给 readStrawFileFromBytes 完成二进制解析
  @override
  Future<ParsedStrawFile> readStrawFile(String filePath) async {
    // ========== 步骤 1：验证文件扩展名 ==========
    if (!isValidStrawFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .straw，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 知识卡片文件。',
        code: 'INVALID_EXTENSION',
      );
    }

    // ========== 步骤 2：检查文件是否存在 ==========
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    // ========== 步骤 3：读取为字节并委托给 bytes-based 方法 ==========
    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw FileException(
        '读取文件失败："$filePath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、文件被占用或磁盘故障。',
        code: 'ACCESS_DENIED',
      );
    }

    return readStrawFileFromBytes(bytes);
  }

  /// 从文件流式读取 .straw 文件头部信息（不加载分块数据）
  ///
  /// 使用 RandomAccessFile 只读取文件头部（Magic Bytes + Version + Header JSON），
  /// 不将整个文件加载到内存，适用于大文件场景。
  /// 分块数据为空列表，解密时需使用 decryptStream() 而非 decrypt()。
  @override
  Future<ParsedStrawFile> readStrawFileHeader(String filePath) async {
    // ========== 步骤 1：验证文件扩展名 ==========
    if (!isValidStrawFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .straw，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 知识卡片文件。',
        code: 'INVALID_EXTENSION',
      );
    }

    // ========== 步骤 2：检查文件是否存在 ==========
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    // ========== 步骤 3：使用 RandomAccessFile 只读取头部 ==========
    final raf = await file.open();
    try {
      // 读取 Magic Bytes (8 bytes)
      final magicData = await raf.read(MAGIC_BYTES_LENGTH);
      final magicString = String.fromCharCodes(magicData);
      if (magicString != 'STRAWHUT') {
        throw FileException(
          'Magic Bytes 不匹配：期望 "STRAWHUT"，实际为 "$magicString"。\n'
          '该文件不是有效的 StrawHut 二进制格式文件。',
          code: 'INVALID_FORMAT',
        );
      }

      // 读取版本号 (4 bytes: major 2B + minor 2B)
      final versionData = await raf.read(4);
      final majorVersion = _readUint16LEFromBytes(versionData, 0);
      final minorVersion = _readUint16LEFromBytes(versionData, 2);
      if (majorVersion != BINARY_FORMAT_MAJOR) {
        throw FileException(
          '不兼容的二进制格式版本: v$majorVersion.$minorVersion，'
          '仅支持 v$BINARY_FORMAT_MAJOR.$BINARY_FORMAT_MINOR',
          code: 'INCOMPATIBLE_VERSION',
        );
      }
      // minor 版本允许 0（v2.0 旧文件）或 1（v2.1 新文件）
      if (minorVersion != BINARY_FORMAT_MINOR_V20 &&
          minorVersion != BINARY_FORMAT_MINOR_V21) {
        throw FileException(
          '不兼容的二进制格式次版本: v$majorVersion.$minorVersion，'
          '仅支持 v$majorVersion.$BINARY_FORMAT_MINOR_V20 或 '
          'v$majorVersion.$BINARY_FORMAT_MINOR_V21',
          code: 'INCOMPATIBLE_VERSION',
        );
      }

      // 读取 Header Size (4 bytes)
      final headerSizeData = await raf.read(4);
      final headerSize = _readUint32LEFromBytes(headerSizeData, 0);

      // 长度上限校验：防止恶意文件触发超大内存分配
      if (headerSize > MAX_HEADER_SIZE_BYTES) {
        throw FileException(
          'Header Size 超过上限: $headerSize 字节，'
          '最大允许 $MAX_HEADER_SIZE_BYTES 字节。\n'
          '可能原因：文件已损坏或被恶意构造。',
          code: 'INVALID_FORMAT',
        );
      }

      // 读取 JSON Header
      final headerJsonData = await raf.read(headerSize);
      String headerJson;
      try {
        headerJson = utf8.decode(headerJsonData);
      } on FormatException catch (e) {
        throw FileException(
          'JSON Header 不是有效的 UTF-8 编码。\n'
          '详细信息：${e.message}\n'
          '可能原因：文件已损坏或被篡改。',
          code: 'INVALID_FORMAT',
        );
      }

      Map<String, dynamic> jsonData;
      try {
        jsonData = jsonDecode(headerJson) as Map<String, dynamic>;
      } on FormatException catch (e) {
        throw FileException(
          'JSON Header 解析失败。\n'
          '文件内容不是有效的 JSON 格式。\n'
          '详细信息：${e.message}\n'
          '可能原因：文件已损坏或被篡改。',
          code: 'INVALID_FORMAT',
        );
      }

      // ========== 步骤 4：验证 JSON Header 格式 ==========
      final validationResult = _formatValidator.validateStrawFormat(jsonData);
      if (!validationResult.isValid) {
        final errorDetails = validationResult.errors.join('\n');
        throw FileException(
          '文件格式验证失败。\n'
          '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
          code: 'VALIDATION_FAILED',
        );
      }

      final strawFile = StrawFile.fromJson(jsonData);
      // 分块数据为空列表 - 解密时需使用 decryptStream()
      return ParsedStrawFile(strawFile: strawFile, chunks: []);
    } finally {
      await raf.close();
    }
  }

  /// 从字节数据读取 .straw 知识卡片文件
  ///
  /// 完整的二进制解析流程：
  /// 1. 验证 Magic Bytes（"STRAWHUT"）
  /// 2. 读取二进制格式版本号
  /// 3. 读取 Header Size，提取 JSON Header 字节
  /// 4. 解析 JSON Header 并验证格式
  /// 5. 解析二进制分块数据
  /// 6. 返回 ParsedStrawFile
  @override
  Future<ParsedStrawFile> readStrawFileFromBytes(Uint8List bytes) async {
    // ========== 步骤 1：验证 Magic Bytes ==========
    final binaryValidation = _formatValidator.validateBinaryFormat(bytes);
    if (!binaryValidation.isValid) {
      final errorDetails = binaryValidation.errors.join('\n');
      throw FileException(
        '文件格式验证失败。\n'
        '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
        code: 'VALIDATION_FAILED',
      );
    }

    // ========== 步骤 2：读取二进制格式版本号 ==========
    if (bytes.length < MAGIC_BYTES_LENGTH + 4) {
      throw FileException(
        '文件数据过短，无法读取格式版本号。\n'
        '至少需要 ${MAGIC_BYTES_LENGTH + 4} 字节。',
        code: 'INVALID_FORMAT',
      );
    }
    final majorVersion = _readUint16LE(bytes, MAGIC_BYTES_LENGTH);
    final minorVersion = _readUint16LE(bytes, MAGIC_BYTES_LENGTH + 2);

    if (majorVersion != BINARY_FORMAT_MAJOR) {
      throw FileException(
        '不兼容的二进制格式版本: v$majorVersion.$minorVersion，'
        '仅支持 v$BINARY_FORMAT_MAJOR.$BINARY_FORMAT_MINOR',
        code: 'INCOMPATIBLE_VERSION',
      );
    }
    // minor 版本允许 0（v2.0 旧文件）或 1（v2.1 新文件）
    if (minorVersion != BINARY_FORMAT_MINOR_V20 &&
        minorVersion != BINARY_FORMAT_MINOR_V21) {
      throw FileException(
        '不兼容的二进制格式次版本: v$majorVersion.$minorVersion，'
        '仅支持 v$majorVersion.$BINARY_FORMAT_MINOR_V20 或 '
        'v$majorVersion.$BINARY_FORMAT_MINOR_V21',
        code: 'INCOMPATIBLE_VERSION',
      );
    }

    // ========== 步骤 3：读取 Header Size 和 JSON Header ==========
    if (bytes.length < MAGIC_BYTES_LENGTH + 4 + 4) {
      throw FileException(
        '文件数据过短，无法读取 Header Size。\n'
        '至少需要 ${MAGIC_BYTES_LENGTH + 4 + 4} 字节。',
        code: 'INVALID_FORMAT',
      );
    }
    final headerSize = _readUint32LE(bytes, MAGIC_BYTES_LENGTH + 4);

    // 长度上限校验：防止恶意文件触发超大内存分配
    if (headerSize > MAX_HEADER_SIZE_BYTES) {
      throw FileException(
        'Header Size 超过上限: $headerSize 字节，'
        '最大允许 $MAX_HEADER_SIZE_BYTES 字节。\n'
        '可能原因：文件已损坏或被恶意构造。',
        code: 'INVALID_FORMAT',
      );
    }

    const headerOffset = MAGIC_BYTES_LENGTH + 4 + 4; // 16
    if (bytes.length < headerOffset + headerSize) {
      throw FileException(
        '文件数据过短，无法读取完整的 JSON Header。\n'
        'Header Size: $headerSize 字节，但文件仅剩 ${bytes.length - headerOffset} 字节。',
        code: 'INVALID_FORMAT',
      );
    }

    // ========== 步骤 4：解析 JSON Header ==========
    String headerJson;
    try {
      headerJson = utf8.decode(
        bytes.sublist(headerOffset, headerOffset + headerSize),
      );
    } on FormatException catch (e) {
      throw FileException(
        'JSON Header 不是有效的 UTF-8 编码。\n'
        '详细信息：${e.message}\n'
        '可能原因：文件已损坏或被篡改。',
        code: 'INVALID_FORMAT',
      );
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(headerJson) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FileException(
        'JSON Header 解析失败。\n'
        '文件内容不是有效的 JSON 格式。\n'
        '详细信息：${e.message}\n'
        '可能原因：文件已损坏或被篡改。',
        code: 'INVALID_FORMAT',
      );
    }

    // ========== 步骤 5：验证 JSON Header 格式 ==========
    final validationResult = _formatValidator.validateStrawFormat(jsonData);
    if (!validationResult.isValid) {
      final errorDetails = validationResult.errors.join('\n');
      throw FileException(
        '文件格式验证失败。\n'
        '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
        code: 'VALIDATION_FAILED',
      );
    }

    // ========== 步骤 6：解析二进制分块数据 ==========
    final chunksDataStart = headerOffset + headerSize;
    final chunks = _parseChunks(bytes, chunksDataStart);

    // ========== 步骤 7：组装 ParsedStrawFile ==========
    final strawFile = StrawFile.fromJson(jsonData);
    return ParsedStrawFile(strawFile: strawFile, chunks: chunks);
  }

  /// 写入 .straw 知识卡片文件
  ///
  /// 将 StrawFile 和加密分块组装为二进制 .straw 格式并写入指定路径。
  /// 支持原子写入模式：先写入临时文件，再重命名为目标文件，
  /// 防止写入过程中崩溃导致文件损坏。
  ///
  /// 参数：
  /// - [strawFile] - StrawFile 对象（包含 JSON Header 信息）
  /// - [chunks] - 加密分块列表
  /// - [targetPath] - 目标文件路径
  /// - [atomic] - 是否使用原子写入，默认为 true
  @override
  Future<void> writeStrawFile({
    required StrawFile strawFile,
    required List<ChunkInfo> chunks,
    required String targetPath,
    bool atomic = true,
  }) async {
    final binaryData = _buildBinaryFile(strawFile, chunks);

    if (atomic) {
      // 原子写入：先写入临时文件，再重命名
      // 临时文件名格式：目标文件名 + .tmp + 时间戳
      final tempPath =
          '$targetPath.tmp.${DateTime.now().millisecondsSinceEpoch}';
      final tempFile = File(tempPath);

      try {
        await tempFile.writeAsBytes(binaryData);
        await tempFile.rename(targetPath);
      } on FileSystemException catch (e) {
        // 清理临时文件
        try {
          if (await tempFile.exists()) {
            await tempFile.delete();
          }
        } on FileSystemException {
          // 忽略清理失败
        }
        throw FileException(
          '写入文件失败："$targetPath"。\n'
          '系统错误：${e.message}\n'
          '可能原因：权限不足、磁盘空间已满或目标路径无效。',
          code: 'WRITE_FAILED',
        );
      }
    } else {
      // 非原子写入：直接写入目标文件
      final file = File(targetPath);
      try {
        await file.writeAsBytes(binaryData);
      } on FileSystemException catch (e) {
        throw FileException(
          '写入文件失败："$targetPath"。\n'
          '系统错误：${e.message}\n'
          '可能原因：权限不足、磁盘空间已满或目标路径无效。',
          code: 'WRITE_FAILED',
        );
      }
    }
  }

  @override
  Uint8List buildBinaryFileBytes({
    required StrawFile strawFile,
    required List<ChunkInfo> chunks,
  }) {
    return _buildBinaryFile(strawFile, chunks);
  }

  @override
  ({Uint8List bytes, String hash}) buildBinaryFileBytesWithIntegrity({
    required StrawFile strawFileForHash,
    required List<ChunkInfo> chunks,
    required IntegritySink integritySink,
  }) {
    // IntegritySink 已在创建时更新了 header（hash='' 版本）
    // 这里构造 bytes 时同步更新 chunks 部分

    final builder = BytesBuilder();

    // 1. Magic + Version + HeaderSize + HeaderJson（hash='' 版本）
    builder.add(STRAW_MAGIC_BYTES);
    _writeUint16LE(builder, BINARY_FORMAT_MAJOR);
    _writeUint16LE(builder, BINARY_FORMAT_MINOR);
    final headerJson = strawFileForHash.assembleHeaderToJson();
    final headerBytes = Uint8List.fromList(utf8.encode(headerJson));
    _writeUint32LE(builder, headerBytes.length);
    builder.add(headerBytes);

    // 2. Chunks（同时更新 integritySink）
    for (final chunk in chunks) {
      builder.add(chunk.iv);
      integritySink.updateChunkIv(chunk.iv);

      final lenBytes = [
        chunk.encryptedData.length & 0xFF,
        (chunk.encryptedData.length >> 8) & 0xFF,
        (chunk.encryptedData.length >> 16) & 0xFF,
        (chunk.encryptedData.length >> 24) & 0xFF,
      ];
      builder.add(lenBytes);
      integritySink.updateChunkLength(lenBytes);

      builder.add(chunk.encryptedData);
      integritySink.updateChunkCipher(chunk.encryptedData);
    }

    final bytesWithoutHash = builder.toBytes();

    // 3. Finalize 得到 hash
    final hash = integritySink.finalize();

    // 4. 用真实 hash 重建 header，复用 chunks 部分（避免重新遍历所有 chunks）
    final strawFileWithHash = StrawFile(
      formatVersion: strawFileForHash.formatVersion,
      meta: strawFileForHash.meta,
      content: strawFileForHash.content,
      integrity: IntegrityInfo(
        hash: hash,
        hashAlgorithm: strawFileForHash.integrity.hashAlgorithm,
      ),
    );
    final headerJsonReal = strawFileWithHash.assembleHeaderToJson();
    final headerBytesReal = Uint8List.fromList(utf8.encode(headerJsonReal));

    final chunksOffset = STRAW_MAGIC_BYTES.length + 4 + 4 + headerBytes.length;
    final finalBuilder = BytesBuilder();
    finalBuilder.add(STRAW_MAGIC_BYTES);
    _writeUint16LE(finalBuilder, BINARY_FORMAT_MAJOR);
    _writeUint16LE(finalBuilder, BINARY_FORMAT_MINOR);
    _writeUint32LE(finalBuilder, headerBytesReal.length);
    finalBuilder.add(headerBytesReal);
    finalBuilder.add(bytesWithoutHash.sublist(chunksOffset));

    return (bytes: finalBuilder.toBytes(), hash: hash);
  }

  @override
  Future<ParsedStrawFile> readStrawPng(String filePath) async {
    if (!isValidPngFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .png，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 知识卡片图片。',
        code: 'INVALID_EXTENSION',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    Uint8List fileBytes;
    try {
      fileBytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw FileException(
        '读取文件失败："$filePath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、文件被占用或磁盘故障。',
        code: 'ACCESS_DENIED',
      );
    }

    return readStrawPngFromBytes(fileBytes);
  }

  @override
  Future<ParsedStrawFile> readStrawPngFromBytes(Uint8List bytes) async {
    final strawBinaryData = await CoverImageService.extractStrawData(bytes);
    if (strawBinaryData == null) {
      throw FileException(
        '该图片不是知识卡片或传输的不是原图，请确认文件来源后重试',
        code: 'NOT_STRAWHUT_PNG',
      );
    }

    // 提取的是 Base64 编码的二进制 .straw 数据，直接按二进制格式解析
    return readStrawFileFromBytes(strawBinaryData);
  }

  /// 读取 .key 密钥文件
  ///
  /// 完整的读取流程（与 readStrawFile 类似，但针对密钥文件）：
  /// 1. 扩展名校验 —— 确保是 .key 文件
  /// 2. 文件存在性检查 —— 确认文件存在于磁盘
  /// 3. 读取文件内容 —— 加载 JSON 字符串到内存
  /// 4. JSON 解析 —— 反序列化为结构化数据
  /// 5. 格式验证 —— 确保密钥文件结构符合规范
  /// 6. 模型反序列化 —— 转换为强类型的 KeyFile 对象
  @override
  Future<KeyFile> readKeyFile(String filePath) async {
    if (!isValidKeyFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .key，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 密钥文件。',
        code: 'INVALID_EXTENSION',
      );
    }

    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：密钥文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } on FileSystemException catch (e) {
      throw FileException(
        '读取密钥文件失败："$filePath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、文件被占用或磁盘故障。',
        code: 'ACCESS_DENIED',
      );
    }

    return readKeyFileFromBytes(bytes);
  }

  @override
  Future<KeyFile> readKeyFileFromBytes(Uint8List bytes) async {
    String fileContent;
    try {
      fileContent = utf8.decode(bytes);
    } on FormatException catch (e) {
      throw FileException(
        '密钥文件内容不是有效的 UTF-8 编码。\n'
        '详细信息：${e.message}\n'
        '安全警告：密钥文件可能被篡改，请勿使用此文件进行解密。',
        code: 'INVALID_FORMAT',
      );
    }

    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
    } on FormatException catch (e) {
      throw FileException(
        '密钥文件 JSON 解析失败。\n'
        '文件内容不是有效的 JSON 格式。\n'
        '详细信息：${e.message}\n'
        '安全警告：密钥文件可能被篡改，请勿使用此文件进行解密。',
        code: 'INVALID_FORMAT',
      );
    }

    final validationResult = _formatValidator.validateKeyFormat(jsonData);
    if (!validationResult.isValid) {
      final errorDetails = validationResult.errors.join('\n');
      throw FileException(
        '密钥文件格式验证失败。\n'
        '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
        code: 'VALIDATION_FAILED',
      );
    }

    return KeyFile.fromJson(jsonData);
  }

  /// 写入 .key 密钥文件
  @override
  Future<void> writeKeyFile({
    required String content,
    required String targetPath,
  }) async {
    final file = File(targetPath);
    try {
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      throw FileException(
        '写入密钥文件失败："$targetPath"。\n'
        '系统错误：${e.message}\n'
        '安全警告：密钥文件写入失败，请确保目标路径安全且磁盘空间充足。',
        code: 'WRITE_FAILED',
      );
    }
  }

  // =========================================================================
  // 二进制格式辅助方法
  // =========================================================================

  /// 组装二进制 .straw 文件
  ///
  /// 将 StrawFile 和加密分块列表组装为完整的二进制 .straw 文件字节数据。
  ///
  /// 文件结构：
  /// ```
  /// Magic Bytes (8B) + Version Major (2B) + Version Minor (2B) +
  /// Header Size (4B) + JSON Header (variable) + Chunks (variable)
  /// ```
  Uint8List _buildBinaryFile(StrawFile strawFile, List<ChunkInfo> chunks) {
    final builder = BytesBuilder();

    // 1. Magic Bytes: "STRAWHUT" (8 bytes)
    builder.add(STRAW_MAGIC_BYTES);

    // 2. Format Version Major (2 bytes uint16 LE)
    _writeUint16LE(builder, BINARY_FORMAT_MAJOR);

    // 3. Format Version Minor (2 bytes uint16 LE)
    // 新文件写入 v2.1（minor=1），启用 AAD + HMAC-SHA256 容器认证
    _writeUint16LE(builder, BINARY_FORMAT_MINOR);

    // 4. JSON Header
    final headerJson = strawFile.assembleHeaderToJson();
    final headerBytes = Uint8List.fromList(utf8.encode(headerJson));

    // 5. Header Size (4 bytes uint32 LE)
    _writeUint32LE(builder, headerBytes.length);

    // 6. JSON Header bytes
    builder.add(headerBytes);

    // 7. 分块数据
    for (final chunk in chunks) {
      // Chunk IV (16 bytes)
      builder.add(chunk.iv);

      // Chunk Data Size (4 bytes uint32 LE)
      _writeUint32LE(builder, chunk.encryptedData.length);

      // Encrypted Data (variable)
      builder.add(chunk.encryptedData);
    }

    return builder.toBytes();
  }

  /// 解析二进制分块数据
  ///
  /// 从 JSON Header 之后的字节偏移开始，逐个解析加密分块。
  /// 每个分块格式：
  /// - IV: 16 字节
  /// - Data Size: 4 字节 uint32 LE
  /// - Encrypted Data: Data Size 字节
  List<ChunkInfo> _parseChunks(Uint8List bytes, int startOffset) {
    final chunks = <ChunkInfo>[];
    var offset = startOffset;

    while (offset + CHUNK_IV_LENGTH_BYTES + 4 <= bytes.length) {
      // 读取 Chunk IV (16 bytes)
      final iv = Uint8List.fromList(
        bytes.sublist(offset, offset + CHUNK_IV_LENGTH_BYTES),
      );
      offset += CHUNK_IV_LENGTH_BYTES;

      // 读取 Chunk Data Size (4 bytes uint32 LE)
      final dataSize = _readUint32LE(bytes, offset);
      offset += 4;

      // 长度上限校验：防止恶意文件触发超大内存分配
      if (dataSize > MAX_CHUNK_CIPHERTEXT_BYTES) {
        throw FileException(
          '分块密文长度超过上限: $dataSize 字节，'
          '最大允许 $MAX_CHUNK_CIPHERTEXT_BYTES 字节。\n'
          '可能原因：文件已损坏或被恶意构造。',
          code: 'INVALID_FORMAT',
        );
      }

      // 读取 Encrypted Data (dataSize bytes)
      if (offset + dataSize > bytes.length) {
        throw FileException(
          '分块数据不完整：期望 $dataSize 字节加密数据，'
          '但仅剩 ${bytes.length - offset} 字节。\n'
          '可能原因：文件已损坏或被截断。',
          code: 'INVALID_FORMAT',
        );
      }

      final encryptedData = Uint8List.fromList(
        bytes.sublist(offset, offset + dataSize),
      );
      offset += dataSize;

      chunks.add(ChunkInfo(iv: iv, encryptedData: encryptedData));
    }

    return chunks;
  }

  /// 读取 2 字节小端序 uint16
  ///
  /// 从 [data] 的 [offset] 位置读取 2 字节，按小端序解析为 uint16。
  int _readUint16LE(Uint8List data, int offset) {
    return data[offset] | (data[offset + 1] << 8);
  }

  /// 从字节列表读取 2 字节小端序 uint16
  ///
  /// 与 [_readUint16LE] 功能相同，但接受 List<int> 而非 Uint8List，
  /// 用于 RandomAccessFile.read() 返回的 List<int> 数据。
  int _readUint16LEFromBytes(List<int> bytes, int offset) {
    return bytes[offset] | (bytes[offset + 1] << 8);
  }

  /// 读取 4 字节小端序 uint32
  ///
  /// 从 [data] 的 [offset] 位置读取 4 字节，按小端序解析为 uint32。
  int _readUint32LE(Uint8List data, int offset) {
    return data[offset] |
        (data[offset + 1] << 8) |
        (data[offset + 2] << 16) |
        (data[offset + 3] << 24);
  }

  /// 从字节列表读取 4 字节小端序 uint32
  ///
  /// 与 [_readUint32LE] 功能相同，但接受 List<int> 而非 Uint8List，
  /// 用于 RandomAccessFile.read() 返回的 List<int> 数据。
  int _readUint32LEFromBytes(List<int> bytes, int offset) {
    return bytes[offset] |
        (bytes[offset + 1] << 8) |
        (bytes[offset + 2] << 16) |
        (bytes[offset + 3] << 24);
  }

  /// 写入 4 字节小端序 uint32
  ///
  /// 将 [value] 以 4 字节小端序格式写入 [builder]。
  void _writeUint32LE(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
    builder.addByte((value >> 16) & 0xFF);
    builder.addByte((value >> 24) & 0xFF);
  }

  /// 写入 2 字节小端序 uint16
  ///
  /// 将 [value] 以 2 字节小端序格式写入 [builder]。
  void _writeUint16LE(BytesBuilder builder, int value) {
    builder.addByte(value & 0xFF);
    builder.addByte((value >> 8) & 0xFF);
  }
}
