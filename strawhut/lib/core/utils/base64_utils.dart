import 'dart:convert';
import 'dart:typed_data';

/// Base64 编码/解码工具类
///
/// 提供标准 Base64 和 URL-safe Base64 编码支持。
///
/// 架构位置：核心工具层（Core Utils Layer）
/// 使用场景：
/// - 加密后密文的 Base64 编码
/// - 密钥的 Base64 编码（展示和存储）
/// - 文件名安全的编码（URL-safe）
///
/// 设计特点：
/// - 私有构造函数，防止实例化（纯工具类）
/// - 静态方法，无需创建实例即可调用
///
/// Base64 类型说明：
/// - 标准 Base64（base64）：使用 + 和 / 字符
/// - URL-safe Base64（base64Url）：使用 - 和 _ 替代 + 和 /
///
/// 使用示例：
/// ```dart
/// final encoded = Base64Utils.encodeToBase64(keyBytes);
/// final decoded = Base64Utils.decodeFromBase64(encoded);
/// ```
class Base64Utils {
  /// 私有构造函数，防止实例化
  Base64Utils._();

  /// 将 Uint8List 编码为标准 Base64 字符串
  ///
  /// 使用 dart:convert 的 base64 编码器。
  /// 32 字节密钥编码后约 44 个字符。
  ///
  /// 参数：[data] - 要编码的字节数组
  /// 返回：标准 Base64 编码字符串
  static String encodeToBase64(Uint8List data) {
    return base64.encode(data);
  }

  /// 将 Base64 字符串解码为 Uint8List
  ///
  /// 将 Base64 编码字符串还原为原始字节数组。
  ///
  /// 参数：[encoded] - Base64 编码字符串
  /// 返回：解码后的字节数组
  /// 异常：输入格式不正确时抛出 FormatException
  static Uint8List decodeFromBase64(String encoded) {
    return base64.decode(encoded);
  }

  /// 将字符串编码为 URL-safe Base64 字符串
  ///
  /// 使用 base64Url 编码器，将 '+' 替换为 '-'，'/' 替换为 '_'。
  /// 适用于文件名、URL 参数等场景。
  ///
  /// 参数：[data] - 要编码的原始字符串
  /// 返回：URL-safe Base64 编码字符串
  static String encodeToBase64Url(String data) {
    return base64Url.encode(utf8.encode(data));
  }
}
