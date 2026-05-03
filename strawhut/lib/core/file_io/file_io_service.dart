import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:strawhut/core/errors/file_exception.dart';
import 'package:strawhut/core/file_io/file_extensions.dart';
import 'package:strawhut/core/validation/format_validator.dart';
import 'package:strawhut/data/models/key_file.dart';
import 'package:strawhut/data/models/straw_file.dart';

/// 文件 I/O 服务接口
///
/// 定义 StrawHut 文件系统操作的契约，负责：
/// - 读取和写入 .straw 知识卡片文件
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
  /// 2. 读取文件内容（JSON 字符串）
  /// 3. 解析 JSON 为 `Map<String, dynamic>`
  /// 4. 调用 FormatValidator.validateStrawFormat() 验证格式
  /// 5. 反序列化为 StrawFile 对象并返回
  ///
  /// 参数：[filePath] - 文件的完整路径
  /// 返回：解析后的 StrawFile 对象
  /// 异常：文件不存在、格式错误、扩展名不正确时抛出异常
  Future<StrawFile> readStrawFile(String filePath);

  /// 写入 .straw 知识卡片文件
  ///
  /// 将完整的 .straw JSON 字符串写入指定路径。
  ///
  /// 参数：
  /// - [content] - 完整的 .straw JSON 字符串
  /// - [targetPath] - 目标文件路径
  Future<void> writeStrawFile({
    required String content,
    required String targetPath,
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
}

/// 文件 I/O 服务实现
///
/// 实现 [IFileIOService] 接口，使用 dart:io 的 File 类执行实际的文件操作。
///
/// 依赖的第三方库：
/// - `path`：跨平台路径操作（提取扩展名、拼接路径等）
/// - `dart:io`：原生文件系统操作
/// - `dart:convert`：JSON 编解码
///
/// 架构职责：
/// - 作为核心服务层，负责文件读写的底层 I/O 操作
/// - 所有读取操作都会自动进行格式验证（安全防线）
/// - 所有写入操作信任调用方传入的内容（格式由调用方保证）
///
/// 使用示例：
/// ```dart
/// final fileIOService = FileIOService();
/// // 读取 .straw 文件
/// final strawFile = await fileIOService.readStrawFile('/path/to/card.straw');
/// // 写入 .straw 文件
/// await fileIOService.writeStrawFile(
///   content: strawFile.assembleToJson(),
///   targetPath: '/path/to/output.straw',
/// );
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
    // 使用 path 包提取文件扩展名，自动处理跨平台路径差异
    // 例如："/path/to/file.straw" -> ".straw"
    //       "C:\\Users\\file.STRaw" -> ".STRaw"（大小写保留）
    final extension = p.extension(filePath);

    // 不区分大小写匹配扩展名
    // 兼容 Windows/macOS 文件系统（不区分大小写）
    // .straw 是我们定义的知识卡片文件标准扩展名
    return extension.toLowerCase() == FileExtensions.straw;
  }

  /// 验证文件路径是否为有效的 .key 文件
  ///
  /// 工作原理：
  /// 1. 使用 path 包的 extension() 方法从完整路径中提取文件扩展名
  /// 2. 将提取的扩展名转为小写后与 FileExtensions.key（'.key'）进行比较
  ///
  /// 安全意义：
  /// - 密钥文件包含敏感的加密密钥，扩展名校验可以防止误读无关文件
  /// - 不区分大小写匹配，兼容各种文件系统
  /// - 与 isValidStrawFile 类似，仅作为初步筛选机制
  /// - 真正的密钥格式验证在 readKeyFile() 中完成
  ///
  /// 参数：[filePath] - 文件的完整路径（包含文件名和扩展名）
  /// 返回：true 表示扩展名为 .key（不区分大小写），false 表示扩展名不匹配
  @override
  bool isValidKeyFile(String filePath) {
    // 使用 path 包提取文件扩展名
    final extension = p.extension(filePath);

    // 不区分大小写匹配 .key 扩展名
    // 兼容 Windows/macOS 文件系统（不区分大小写）
    // .key 是我们定义的密钥文件标准扩展名
    return extension.toLowerCase() == FileExtensions.key;
  }

  /// 读取 .straw 知识卡片文件
  ///
  /// 完整的读取流程（每一步都有安全考量）：
  /// 1. 扩展名校验 —— 防止误读非 .straw 文件
  /// 2. 文件存在性检查 —— 避免无效 I/O 操作，提供清晰的错误信息
  /// 3. 读取文件内容为字符串 —— 将磁盘数据加载到内存
  /// 4. JSON 解析 —— 将字符串反序列化为结构化数据
  /// 5. 格式验证 —— 确保文件结构符合规范，防止恶意/损坏文件进入系统
  /// 6. 模型反序列化 —— 转换为强类型的 StrawFile 对象供业务层使用
  ///
  /// 安全考量：
  /// - 扩展名校验：快速过滤明显不匹配的文件，减少不必要的 I/O 开销
  /// - 存在性检查：在读取前确认文件存在，避免无意义的异常
  /// - 格式验证：这是最核心的安全验证，确保文件结构完整、算法正确
  ///   - 验证加密算法必须为 AES-256-GCM（防止降级攻击）
  ///   - 验证哈希算法必须为 SHA-256（确保完整性校验强度）
  ///   - 验证所有必填字段存在（确保文件结构完整）
  ///   - 验证字段长度限制（防止缓冲区溢出或拒绝服务攻击）
  ///
  /// 参数：[filePath] - .straw 文件的完整路径
  /// 返回：解析并验证后的 StrawFile 对象
  /// 异常：
  /// - FileException（扩展名不正确）
  /// - FileException（文件不存在）
  /// - FileException（JSON 格式错误）
  /// - FileException（格式验证失败，包含详细错误列表）
  /// - FileException（其他 I/O 异常）
  @override
  Future<StrawFile> readStrawFile(String filePath) async {
    // ========== 步骤 1：验证文件扩展名 ==========
    // 在尝试读取文件之前先检查扩展名，这是一种"快速失败"（Fail-Fast）策略
    // 如果扩展名不正确，立即拒绝处理，避免浪费 I/O 资源
    // 这也防止了用户误传其他类型的文件（如图片、文本文件等）
    if (!isValidStrawFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .straw，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 知识卡片文件。',
        code: 'INVALID_EXTENSION',
      );
    }

    // ========== 步骤 2：检查文件是否存在 ==========
    // 在读取前显式检查文件存在性，原因：
    // 1. 提供更清晰的错误信息（"文件不存在" vs "读取失败"）
    // 2. 避免触发底层 FileSystemException，统一使用 FileException
    // 3. 这是防御性编程的体现：在操作前验证前提条件
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    // ========== 步骤 3：读取文件内容 ==========
    // 将整个文件内容读取为字符串。
    // .straw 文件是 JSON 格式的知识卡片，通常体积较小（KB 级别），
    // 因此一次性读取到内存是合理的。
    // 对于超大文件，可能需要流式读取，但本场景不需要。
    String fileContent;
    try {
      fileContent = await file.readAsString();
    } on FileSystemException catch (e) {
      // FileSystemException 可能由以下原因触发：
      // - 权限不足（无读取权限）
      // - 文件被其他进程锁定
      // - 磁盘 I/O 错误
      // 我们将其包装为 FileException，提供更友好的错误信息
      throw FileException(
        '读取文件失败："$filePath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、文件被占用或磁盘故障。',
        code: 'ACCESS_DENIED',
      );
    }

    // 检查文件内容是否为空
    // Windows 上文件选择器可能返回路径但文件尚未完全写入，
    // 导致读取到空内容。添加重试机制。
    if (fileContent.trim().isEmpty) {
      // 等待 100ms 后重试一次
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        fileContent = await file.readAsString();
      } on FileSystemException {
        fileContent = '';
      }
      if (fileContent.trim().isEmpty) {
        throw FileException(
          '文件为空："$filePath"。\n'
          '可能原因：文件尚未写入完成或文件已损坏。',
          code: 'EMPTY_FILE',
        );
      }
    }

    // ========== 步骤 4：解析 JSON ==========
    // 将 JSON 字符串反序列化为 Map<String, dynamic>
    // jsonDecode 会在 JSON 格式错误时抛出 FormatException
    // 捕获并转换为 FileException，确保异常类型统一
    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
    } on FormatException catch (e) {
      // JSON 格式错误意味着文件内容不是有效的 JSON
      // 可能原因：文件被篡改、手动编辑出错、传输过程中损坏
      // 这是安全验证的重要环节：拒绝格式错误的文件
      throw FileException(
        'JSON 解析失败："$filePath"。\n'
        '文件内容不是有效的 JSON 格式。\n'
        '详细信息：${e.message}\n'
        '可能原因：文件已损坏或被篡改。',
        code: 'INVALID_FORMAT',
      );
    }

    // ========== 步骤 5：验证文件格式 ==========
    // 这是最核心的安全验证步骤。FormatValidator 会检查：
    // - 所有必填字段是否存在
    // - 加密算法是否为 AES-256-GCM（防止降级攻击）
    // - 哈希算法是否为 SHA-256（确保完整性校验强度）
    // - 字段长度是否符合限制（防止缓冲区溢出）
    // - 版本号是否兼容（主版本必须为 1）
    //
    // 收集所有验证错误（而非在第一个错误处停止），
    // 这样可以一次性向用户展示所有问题，提升用户体验。
    final validationResult = _formatValidator.validateStrawFormat(jsonData);
    if (!validationResult.isValid) {
      // 格式验证失败，拒绝处理此文件
      // 将所有验证错误拼接成完整的错误信息
      final errorDetails = validationResult.errors.join('\n');
      throw FileException(
        '文件格式验证失败："$filePath"。\n'
        '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
        code: 'VALIDATION_FAILED',
      );
    }

    // ========== 步骤 6：反序列化为 StrawFile 对象 ==========
    // 经过上述所有验证后，可以安全地将 JSON 数据转换为强类型对象
    // StrawFile.fromJson 会进一步解析各子对象（meta、content、integrity）
    // 此时数据已经通过所有安全验证，可以信任其结构
    return StrawFile.fromJson(jsonData);
  }

  /// 写入 .straw 知识卡片文件
  ///
  /// 将完整的 .straw JSON 字符串写入指定文件路径。
  ///
  /// 设计决策 —— 为什么写入时不验证格式？
  /// - content 参数应由调用方通过 StrawFile.assembleToJson() 生成
  /// - StrawFile 对象本身是通过 readStrawFile() 读取或程序内部构造的
  /// - 内部构造的数据已经经过格式验证，无需重复检查
  /// - 这样可以避免不必要的性能开销
  /// - 如果调用方传入非法内容，责任在调用方
  ///
  /// 参数：
  /// - [content] - 完整的 .straw JSON 字符串（由调用方保证格式正确）
  /// - [targetPath] - 目标文件的完整路径
  /// 异常：
  /// - FileException（写入失败，包含系统级错误详情）
  @override
  Future<void> writeStrawFile({
    required String content,
    required String targetPath,
  }) async {
    // ========== 创建/覆盖文件并写入内容 ==========
    // File.writeAsString() 的行为：
    // - 如果文件不存在，会自动创建
    // - 如果文件已存在，会覆盖原有内容
    // - 写入是原子操作（在大多数文件系统上）
    //
    // 安全考量：
    // - 覆盖操作不可逆，调用方应确保 targetPath 是正确的目标路径
    // - 在生产环境中，可考虑先写入临时文件再重命名，实现安全覆盖
    final file = File(targetPath);
    try {
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      // FileSystemException 可能由以下原因触发：
      // - 权限不足（无写入权限到目标目录）
      // - 磁盘空间不足（无法写入新数据）
      // - 目标路径无效（如指向只读目录）
      // - 文件被其他进程锁定
      //
      // 包装为 FileException，保留原始系统错误信息供调试使用
      throw FileException(
        '写入文件失败："$targetPath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、磁盘空间已满或目标路径无效。',
        code: 'WRITE_FAILED',
      );
    }
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
  ///
  /// 安全考量（密钥文件的特殊性）：
  /// - 密钥文件包含敏感的加密密钥，泄露会导致所有关联卡片可被解密
  /// - 格式验证确保密钥算法为 AES-256-GCM、密钥长度为 256 位
  /// - 完整性校验确保密钥在存储/传输过程中未被篡改
  /// - 如果密钥文件格式错误，可能导致：
  ///   1. 解密失败（数据不可用）
  ///   2. 使用错误密钥解密后产生乱码（用户可能误以为数据损坏）
  ///
  /// 参数：[filePath] - .key 密钥文件的完整路径
  /// 返回：解析并验证后的 KeyFile 对象
  /// 异常：
  /// - FileException（扩展名不正确）
  /// - FileException（文件不存在）
  /// - FileException（JSON 格式错误）
  /// - FileException（格式验证失败）
  /// - FileException（其他 I/O 异常）
  @override
  Future<KeyFile> readKeyFile(String filePath) async {
    // ========== 步骤 1：验证文件扩展名 ==========
    // 确保路径指向的是 .key 文件，防止误读其他类型文件
    // 密钥文件包含敏感信息，扩展名校验是基本的安全措施
    if (!isValidKeyFile(filePath)) {
      throw FileException(
        '无效的文件扩展名：期望 .key，'
        '实际为 "${p.extension(filePath)}"。'
        '请确保选择的是 StrawHut 密钥文件。',
        code: 'INVALID_EXTENSION',
      );
    }

    // ========== 步骤 2：检查文件是否存在 ==========
    // 与 readStrawFile 相同，显式检查文件存在性
    final file = File(filePath);
    if (!await file.exists()) {
      throw FileException(
        '文件不存在："$filePath"。\n'
        '可能原因：密钥文件已被删除、移动，或路径输入有误。',
        code: 'FILE_NOT_FOUND',
      );
    }

    // ========== 步骤 3：读取文件内容 ==========
    // 将密钥文件内容读取为字符串
    // 密钥文件通常很小（约几百字节），一次性读取到内存是安全的
    String fileContent;
    try {
      fileContent = await file.readAsString();
    } on FileSystemException catch (e) {
      // 读取失败可能意味着权限问题或文件被占用
      // 对于密钥文件，读取失败也可能是安全事件（如文件被加密勒索软件锁定）
      throw FileException(
        '读取密钥文件失败："$filePath"。\n'
        '系统错误：${e.message}\n'
        '可能原因：权限不足、文件被占用或磁盘故障。',
        code: 'ACCESS_DENIED',
      );
    }

    // ========== 步骤 4：解析 JSON ==========
    // 将 JSON 字符串反序列化为 Map
    Map<String, dynamic> jsonData;
    try {
      jsonData = jsonDecode(fileContent) as Map<String, dynamic>;
    } on FormatException catch (e) {
      // 密钥文件的 JSON 格式错误是非常严重的问题
      // 可能意味着密钥文件被篡改或损坏
      // 被篡改的密钥可能导致安全漏洞
      throw FileException(
        '密钥文件 JSON 解析失败："$filePath"。\n'
        '文件内容不是有效的 JSON 格式。\n'
        '详细信息：${e.message}\n'
        '安全警告：密钥文件可能被篡改，请勿使用此文件进行解密。',
        code: 'INVALID_FORMAT',
      );
    }

    // ========== 步骤 5：验证密钥文件格式 ==========
    // FormatValidator.validateKeyFormat() 会验证：
    // - format_version 存在
    // - key_metadata 包含 key_id、created_at、key_algorithm、key_length_bits
    // - key_algorithm 必须为 AES-256-GCM
    // - key_length_bits 必须为 256
    // - key_data 包含 key_base64 和 encoding
    // - encoding 必须为 "base64"
    // - integrity 包含 hash 和 hash_algorithm
    //
    // 这些验证确保密钥文件的完整性和安全性
    final validationResult = _formatValidator.validateKeyFormat(jsonData);
    if (!validationResult.isValid) {
      // 密钥文件格式验证失败，拒绝处理
      // 使用错误的密钥文件可能导致数据泄露或解密失败
      final errorDetails = validationResult.errors.join('\n');
      throw FileException(
        '密钥文件格式验证失败："$filePath"。\n'
        '以下字段或格式不符合 StrawHut 规范：\n$errorDetails',
        code: 'VALIDATION_FAILED',
      );
    }

    // ========== 步骤 6：反序列化为 KeyFile 对象 ==========
    // 经过所有安全验证后，将 JSON 数据转换为强类型 KeyFile 对象
    // KeyFile 包含密钥数据，后续将用于解密 .straw 文件
    return KeyFile.fromJson(jsonData);
  }

  /// 写入 .key 密钥文件
  ///
  /// 将完整的 .key JSON 字符串写入指定文件路径。
  ///
  /// 安全注意事项：
  /// - 密钥文件包含敏感的加密密钥，写入操作应谨慎处理
  /// - 调用方应确保 targetPath 是安全的存储位置
  /// - 建议将密钥文件存储在用户指定的安全目录中
  /// - 写入失败时抛出异常，调用方应妥善处理并通知用户
  ///
  /// 参数：
  /// - [content] - 完整的 .key JSON 字符串（由调用方保证格式正确）
  /// - [targetPath] - 目标密钥文件的完整路径
  /// 异常：
  /// - FileException（写入失败，包含系统级错误详情）
  @override
  Future<void> writeKeyFile({
    required String content,
    required String targetPath,
  }) async {
    // ========== 创建/覆盖密钥文件并写入内容 ==========
    // 与 writeStrawFile 相同的写入逻辑
    // 但需要更加注意目标路径的安全性，因为这是密钥文件
    final file = File(targetPath);
    try {
      await file.writeAsString(content);
    } on FileSystemException catch (e) {
      // 密钥文件写入失败可能导致：
      // - 用户无法保存密钥，影响后续解密操作
      // - 如果是在密钥生成流程中，可能需要重新生成密钥
      // 保留原始系统错误信息供调试和日志记录使用
      throw FileException(
        '写入密钥文件失败："$targetPath"。\n'
        '系统错误：${e.message}\n'
        '安全警告：密钥文件写入失败，请确保目标路径安全且磁盘空间充足。',
        code: 'WRITE_FAILED',
      );
    }
  }
}
