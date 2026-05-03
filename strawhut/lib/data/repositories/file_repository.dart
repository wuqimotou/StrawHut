import 'dart:convert';

import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/data/models/key_file.dart';
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
/// - 负责 StrawFile 和 KeyFile 对象与文件系统之间的序列化/反序列化
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
  /// 读取并解析指定路径的 .straw 文件，返回强类型的 StrawFile 对象。
  /// 该方法只负责委托给底层服务，具体的验证和解析逻辑由 FileIOService 完成。
  ///
  /// 内部工作流程：
  /// 1. 将 filePath 参数传递给 _fileIOService.readStrawFile()
  /// 2. FileIOService 内部会执行：
  ///    a. 验证文件扩展名是否为 .straw
  ///    b. 检查文件是否存在
  ///    c. 读取文件内容（JSON 字符串）
  ///    d. 解析 JSON 为 Map 结构
  ///    e. 调用 FormatValidator.validateStrawFormat() 验证格式
  ///    f. 反序列化为 StrawFile 对象并返回
  ///
  /// 参数说明：
  /// - [filePath] - .straw 文件的完整绝对路径。
  ///   路径格式由调用方保证有效，仓库层不做路径合法性校验。
  ///
  /// 返回值：
  /// 解析并验证后的 StrawFile 对象，包含完整的知识卡片数据。
  ///
  /// 异常行为：
  /// - FileException：文件不存在、扩展名不正确、JSON 格式错误、
  ///   格式验证失败或其他 I/O 异常。
  ///   异常会被直接向上抛出，由调用方（通常是 Provider 或 UI 层）处理。
  ///
  /// 安全注意事项：
  /// - 该方法本身不执行任何安全验证，信任 FileIOService 的安全防线。
  /// - FileIOService 会验证加密算法必须为 AES-256-GCM，防止降级攻击。
  /// - 文件路径由调用方提供，仓库层不进行路径遍历攻击防护（应由调用方处理）。
  ///
  /// 使用示例：
  /// ```dart
  /// final repository = FileRepository(FileIOService());
  /// final strawFile = await repository.loadStrawFile('/path/to/card.straw');
  /// print(strawFile.meta.title);
  /// ```
  Future<StrawFile> loadStrawFile(String filePath) async {
    return _fileIOService.readStrawFile(filePath);
  }

  /// 将 StrawFile 对象保存为 .straw 知识卡片文件
  ///
  /// 功能说明：
  /// 将 StrawFile 对象序列化为 JSON 字符串并写入指定路径。
  /// 该方法负责 JSON 组装工作，实际的磁盘写入操作委托给 FileIOService。
  ///
  /// 内部工作流程：
  /// 1. 调用 strawFile.assembleToJson() 将对象序列化为 JSON 字符串。
  ///    该方法会从 formatVersion、meta、content、integrity 四个部分
  ///    构建符合 StrawHut 规范的完整 JSON 结构。
  /// 2. 将 JSON 字符串和目标路径传递给 _fileIOService.writeStrawFile()。
  /// 3. FileIOService 负责创建/覆盖文件并写入内容。
  ///
  /// 参数说明：
  /// - [strawFile] - 要保存的知识卡片对象。
  ///   必须包含完整且有效的数据结构（formatVersion、meta、content、integrity）。
  ///   对象由调用方构造，仓库层信任其内容有效性。
  /// - [targetPath] - 目标文件的完整绝对路径。
  ///   路径格式由调用方保证有效，仓库层不做路径合法性校验。
  ///   如果路径指向已存在的文件，将被覆盖。
  ///
  /// 返回值：
  /// 无返回值（`Future<void>`）。写入成功时正常返回，失败时抛出异常。
  ///
  /// 异常行为：
  /// - FileException：写入失败（权限不足、磁盘空间不足、路径无效等）。
  ///   异常由 FileIOService 包装后抛出，包含系统级错误详情。
  ///
  /// 安全注意事项：
  /// - 写入操作会覆盖目标路径的现有文件，调用方应确保 targetPath 是正确的目标路径。
  /// - 在生产环境中，可考虑先写入临时文件再重命名，实现安全覆盖（当前版本未实现）。
  /// - StrawFile 对象中的加密内容在写入前已经是加密状态，仓库层不接触明文密钥。
  ///
  /// 使用示例：
  /// ```dart
  /// final repository = FileRepository(FileIOService());
  /// await repository.saveStrawFile(
  ///   strawFile: myStrawFile,
  ///   targetPath: '/path/to/output.straw',
  /// );
  /// ```
  Future<void> saveStrawFile({
    required StrawFile strawFile,
    required String targetPath,
  }) async {
    final content = strawFile.assembleToJson();
    await _fileIOService.writeStrawFile(
      content: content,
      targetPath: targetPath,
    );
  }

  /// 从指定路径加载 .key 密钥文件
  ///
  /// 功能说明：
  /// 读取并解析指定路径的 .key 文件，返回强类型的 KeyFile 对象。
  /// 该方法只负责委托给底层服务，具体的验证和解析逻辑由 FileIOService 完成。
  ///
  /// 内部工作流程：
  /// 1. 将 filePath 参数传递给 _fileIOService.readKeyFile()。
  /// 2. FileIOService 内部会执行：
  ///    a. 验证文件扩展名是否为 .key
  ///    b. 检查文件是否存在
  ///    c. 读取文件内容（JSON 字符串）
  ///    d. 解析 JSON 为 Map 结构
  ///    e. 调用 FormatValidator.validateKeyFormat() 验证格式
  ///    f. 反序列化为 KeyFile 对象并返回
  ///
  /// 参数说明：
  /// - [filePath] - .key 密钥文件的完整绝对路径。
  ///   路径格式由调用方保证有效，仓库层不做路径合法性校验。
  ///
  /// 返回值：
  /// 解析并验证后的 KeyFile 对象，包含完整的密钥数据。
  ///
  /// 异常行为：
  /// - FileException：文件不存在、扩展名不正确、JSON 格式错误、
  ///   格式验证失败或其他 I/O 异常。
  ///   异常会被直接向上抛出，由调用方（通常是 Provider 或 UI 层）处理。
  ///
  /// 安全注意事项：
  /// - 密钥文件包含敏感的加密密钥，泄露会导致所有关联卡片可被解密。
  /// - FileIOService 会验证密钥算法必须为 AES-256-GCM、密钥长度为 256 位。
  /// - 完整性校验确保密钥在存储/传输过程中未被篡改。
  /// - 密钥文件路径由调用方提供，仓库层不进行路径遍历攻击防护（应由调用方处理）。
  ///
  /// 使用示例：
  /// ```dart
  /// final repository = FileRepository(FileIOService());
  /// final keyFile = await repository.loadKeyFile('/path/to/secret.key');
  /// print(keyFile.keyData.keyBase64);
  /// ```
  Future<KeyFile> loadKeyFile(String filePath) async {
    return _fileIOService.readKeyFile(filePath);
  }

  /// 将 KeyFile 对象保存为 .key 密钥文件
  ///
  /// 功能说明：
  /// 将 KeyFile 对象序列化为 JSON 字符串并写入指定路径。
  /// 该方法负责 JSON 组装工作，实际的磁盘写入操作委托给 FileIOService。
  ///
  /// 内部工作流程：
  /// 1. 调用 keyFile.toJson() 将对象转换为键值对映射。
  ///    该方法会从 formatVersion、keyMetadata、keyData、integrity 四个部分
  ///    构建符合 StrawHut 规范的密钥文件结构。
  /// 2. 使用 jsonEncode() 将映射转换为 JSON 字符串。
  /// 3. 将 JSON 字符串和目标路径传递给 _fileIOService.writeKeyFile()。
  /// 4. FileIOService 负责创建/覆盖文件并写入内容。
  ///
  /// 参数说明：
  /// - [keyFile] - 要保存的密钥文件对象。
  ///   必须包含完整且有效的数据结构（formatVersion、keyMetadata、keyData、integrity）。
  ///   对象由调用方构造，仓库层信任其内容有效性。
  /// - [targetPath] - 目标密钥文件的完整绝对路径。
  ///   路径格式由调用方保证有效，仓库层不做路径合法性校验。
  ///   如果路径指向已存在的文件，将被覆盖。
  ///
  /// 返回值：
  /// 无返回值（`Future<void>`）。写入成功时正常返回，失败时抛出异常。
  ///
  /// 异常行为：
  /// - FileException：写入失败（权限不足、磁盘空间不足、路径无效等）。
  ///   异常由 FileIOService 包装后抛出，包含系统级错误详情。
  ///
  /// 安全注意事项：
  /// - 密钥文件包含敏感的加密密钥，写入操作应谨慎处理。
  /// - 调用方应确保 targetPath 是安全的存储位置。
  /// - 建议将密钥文件存储在用户指定的安全目录中，而非默认下载目录。
  /// - 写入失败时抛出异常，调用方应妥善处理并通知用户。
  /// - 如果是在密钥生成流程中，写入失败可能需要重新生成密钥（调用方决策）。
  ///
  /// 使用示例：
  /// ```dart
  /// final repository = FileRepository(FileIOService());
  /// await repository.saveKeyFile(
  ///   keyFile: myKeyFile,
  ///   targetPath: '/path/to/secret.key',
  /// );
  /// ```
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
