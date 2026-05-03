/// StrawHut 自定义异常基类
///
/// 所有 StrawHut 模块抛出的异常都应继承自此类，
/// 以提供统一的异常处理和错误信息格式。
///
/// 异常层次结构：
/// ```text
/// StrawHutException (抽象基类)
/// ├── CryptoException      - 加密/解密操作失败
/// ├── FileException        - 文件读写操作失败
/// └── StrawFormatException - 文件格式验证失败
/// ```
///
/// 设计特点：
/// - 抽象类，不能直接实例化
/// - 实现 Exception 接口，兼容 Dart 异常机制
/// - 包含可选的错误代码，便于程序化区分错误类型
///
/// 使用示例：
/// ```dart
/// try {
///   await cryptoService.decryptContent(...);
/// } on CryptoException catch (e) {
///   showDialog('解密失败: ${e.message}');
/// }
/// ```
abstract class StrawHutException implements Exception {
  /// 创建一个新的 [StrawHutException] 实例
  ///
  /// [message] 为必填参数，提供异常的人类可读描述。
  /// [code] 为可选参数，用于标识具体的错误类型。
  const StrawHutException(this.message, {this.code});

  /// 异常描述信息
  ///
  /// 人类可读的错误描述，可直接展示给用户或记录到日志。
  /// 示例："密钥格式错误"、"文件不存在"、"标题不能为空"
  final String message;

  /// 可选的错误代码
  ///
  /// 用于程序化区分不同类型的错误，适合 switch 语句或条件判断。
  /// 示例：'INVALID_KEY'、'FILE_NOT_FOUND'、'MISSING_FIELD'
  ///
  /// 注意：此字段为可选，不是所有异常都需要错误代码。
  final String? code;

  /// 返回异常的字符串表示
  ///
  /// 格式：'{runtimeType}({code}): {message}'
  /// 使用 runtimeType 自动显示具体异常类型（如 CryptoException、FileException）。
  @override
  String toString() => '$runtimeType($code): $message';
}
