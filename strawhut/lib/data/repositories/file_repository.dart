import 'dart:convert';

import 'package:strawhut/core/crypto/crypto_models/chunk_info.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 文件仓库
///
/// 封装文件系统操作，作为核心服务层和数据层之间的桥梁。
/// 提供高层次的文件读写接口，隐藏底层 FileIOService 的实现细节。
///
/// 架构位置：数据层（Data Layer）
/// 依赖服务：IFileIOService（核心服务层）
/// 被依赖方：应用层 Provider（CardProvider、PublishDialog 等）
///
/// 设计模式：Repository Pattern（仓储模式）
/// - 统一数据访问接口
/// - 屏蔽底层存储细节
/// - 便于测试时替换 mock 实现
///
/// 职责边界：
/// - 负责 StrawFile、ParsedStrawFile 和 KeyFile 对象与文件系统之间的
///   序列化/反序列化
/// - 提供语义化的文件操作方法（load/save），而非底层的 read/write
/// - 在必要时对底层异常进行包装，保持仓库层的抽象一致性
class FileRepository {
  /// 创建文件仓库实例
  ///
  /// 参数：fileIOService - 文件 I/O 服务实现（通过依赖注入传入）
  FileRepository(this._fileIOService);

  /// 文件 I/O 服务实例（通过依赖注入传入）
  ///
  /// 私有字段，对外不可见，确保底层实现细节不会泄漏到仓库层之外。
  final IFileIOService _fileIOService;

  /// 从指定路径加载 .straw 知识卡片文件
  ///
  /// 功能说明：
  /// 读取并解析指定路径的 .straw 文件，返回 ParsedStrawFile 对象。
  /// ParsedStrawFile 包含 JSON Header 解析后的 StrawFile 和二进制分块数据。
  ///
  /// 内部工作流程：
  /// 1. 将 filePath 参数传递给 _fileIOService.readStrawFile()
  /// 2. FileIOService 内部会执行：
  ///    a. 验证文件扩展名是否为 .straw
  ///    b. 检查文件是否存在
  ///    c. 读取文件内容为字节数据
  ///    d. 验证 Magic Bytes（"STRAWHUT"）
  ///    e. 读取二进制格式版本号
  ///    f. 读取 JSON Header 并验证格式
  ///    g. 解析二进制分块数据
  ///    h. 返回 ParsedStrawFile
  ///
  /// 参数说明：
  /// - [filePath] - .straw 文件的完整绝对路径。
  ///
  /// 返回值：
  /// 解析并验证后的 ParsedStrawFile 对象，包含 StrawFile 和分块数据。
  ///
  /// 异常行为：
  /// - FileException：文件不存在、扩展名不正确、格式错误、
  ///   格式验证失败或其他 I/O 异常。
  Future<ParsedStrawFile> loadStrawFile(String filePath) async {
    return _fileIOService.readStrawFile(filePath);
  }

  /// 从指定路径加载内嵌 .straw 数据的 PNG 图片
  ///
  /// 功能说明：
  /// 读取 PNG 图片中嵌入的二进制 .straw 数据，返回 ParsedStrawFile 对象。
  ///
  /// 参数说明：
  /// - [filePath] - PNG 图片的完整绝对路径。
  ///
  /// 返回值：
  /// 解析并验证后的 ParsedStrawFile 对象，包含 StrawFile 和分块数据。
  Future<ParsedStrawFile> loadStrawPng(String filePath) async {
    return _fileIOService.readStrawPng(filePath);
  }

  /// 将 StrawFile 和分块数据保存为 .straw 知识卡片文件
  ///
  /// 功能说明：
  /// 将 StrawFile 和加密分块列表组装为二进制 .straw 格式并写入指定路径。
  /// 支持原子写入模式，防止写入过程中崩溃导致文件损坏。
  ///
  /// 参数说明：
  /// - [strawFile] - StrawFile 对象（包含 JSON Header 信息）
  /// - [chunks] - 加密分块列表
  /// - [targetPath] - 目标文件的完整绝对路径
  /// - [atomic] - 是否使用原子写入，默认为 true
  ///
  /// 异常行为：
  /// - FileException：写入失败（权限不足、磁盘空间不足、路径无效等）。
  Future<void> saveStrawFile({
    required StrawFile strawFile,
    required List<ChunkInfo> chunks,
    required String targetPath,
    bool atomic = true,
  }) async {
    await _fileIOService.writeStrawFile(
      strawFile: strawFile,
      chunks: chunks,
      targetPath: targetPath,
      atomic: atomic,
    );
  }

  /// 从指定路径加载 .key 密钥文件
  ///
  /// 功能说明：
  /// 读取并解析指定路径的 .key 文件，返回强类型的 KeyFile 对象。
  ///
  /// 参数说明：
  /// - [filePath] - .key 密钥文件的完整绝对路径。
  ///
  /// 返回值：
  /// 解析并验证后的 KeyFile 对象，包含完整的密钥数据。
  ///
  /// 异常行为：
  /// - FileException：文件不存在、扩展名不正确、JSON 格式错误、
  ///   格式验证失败或其他 I/O 异常。
  Future<KeyFile> loadKeyFile(String filePath) async {
    return _fileIOService.readKeyFile(filePath);
  }

  /// 将 KeyFile 对象保存为 .key 密钥文件
  ///
  /// 功能说明：
  /// 将 KeyFile 对象序列化为 JSON 字符串并写入指定路径。
  ///
  /// 参数说明：
  /// - [keyFile] - 要保存的密钥文件对象。
  /// - [targetPath] - 目标密钥文件的完整绝对路径。
  ///
  /// 异常行为：
  /// - FileException：写入失败（权限不足、磁盘空间不足、路径无效等）。
  Future<void> saveKeyFile({
    required KeyFile keyFile,
    required String targetPath,
  }) async {
    final content = jsonEncode(keyFile.toJson());
    await _fileIOService.writeKeyFile(
      content: content,
      targetPath: targetPath,
    );
  }
}
