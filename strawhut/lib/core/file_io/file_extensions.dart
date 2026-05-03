/// 文件扩展名常量
///
/// 定义 StrawHut 使用的所有文件扩展名。
///
/// 支持的扩展名：
/// - [.straw]: 知识卡片文件，包含加密内容和公开元数据
/// - [.key]: 密钥文件，独立存储的加密密钥
/// - [.json]: 通用 JSON 文件（调试或导出时使用）
///
/// 设计特点：
/// - 私有构造函数，防止实例化（纯工具类）
/// - 所有常量使用 static const，编译期确定
///
/// 使用示例：
/// ```dart
/// if (filePath.endsWith(FileExtensions.straw)) {
///   // 处理知识卡片文件
/// }
/// ```
class FileExtensions {
  /// 私有构造函数，防止实例化
  FileExtensions._();

  /// .straw 知识卡片文件扩展名
  ///
  /// 包含加密后的知识内容、公开元数据和完整性校验信息。
  /// 文件格式为 JSON，结构参见 StrawFile 模型。
  static const String straw = '.straw';

  /// .key 密钥文件扩展名
  ///
  /// 包含 AES-256 密钥的 Base64 编码和关联元信息。
  /// 文件格式为 JSON，结构参见 KeyFile 模型。
  static const String key = '.key';

  /// .json 文件扩展名
  ///
  /// 通用 JSON 文件扩展名，可能用于：
  /// - 调试导出的 Delta JSON
  /// - 备份或迁移数据
  /// - 第三方工具集成
  static const String json = '.json';
}
