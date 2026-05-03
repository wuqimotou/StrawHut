/// 完整性校验常量
///
/// 定义完整性校验模块使用的常量值。
///
/// 设计特点：
/// - 私有构造函数，防止实例化（纯工具类）
/// - 所有常量使用 static const，编译期确定
///
/// 使用场景：
/// ```dart
/// final algorithm = IntegrityConstants.hashAlgorithm; // 'SHA-256'
/// ```
class IntegrityConstants {
  /// 私有构造函数，防止实例化
  IntegrityConstants._();

  /// 哈希算法标识
  ///
  /// 固定为 'SHA-256'，用于 .straw 和 .key 文件的 integrity.hash_algorithm 字段。
  /// 与 crypto_constants.dart 中的 HASH_ALGORITHM_SHA256 保持一致。
  static const String hashAlgorithm = 'SHA-256';

  /// 哈希值长度（字节）
  ///
  /// SHA-256 输出 32 字节（256 位）的哈希值。
  /// 转换为十六进制字符串后长度为 64 个字符。
  static const int hashLengthBytes = 32;
}
