import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 格式相关异常
///
/// 在文件格式验证、JSON 解析等操作失败时抛出此异常。
/// 使用 [StrawFormatException] 而非 [FormatException] 以避免与 Dart
/// 内置的 [FormatException] 产生名称冲突。
///
/// 常见触发场景：
/// - .straw 文件 JSON 结构不完整
/// - .key 文件缺少必填字段
/// - 版本号不兼容（主版本不同）
/// - 元数据字段长度超限（标题、标签、描述）
/// - JSON 语法错误（非法字符、缺少引号等）
///
/// 错误代码建议：
/// - 'MISSING_FIELD': 缺少必填字段
/// - 'VERSION_MISMATCH': 版本不兼容
/// - 'FIELD_TOO_LONG': 字段长度超限
/// - 'INVALID_JSON': JSON 格式错误
///
/// 使用示例：
/// ```dart
/// final result = formatValidator.validateStrawFormat(json);
/// if (!result.isValid) {
///   throw StrawFormatException(
///     '文件格式验证失败: ${result.errors.join(', ')}',
///     code: 'MISSING_FIELD',
///   );
/// }
/// ```
class StrawFormatException extends StrawHutException {
  /// 创建一个新的 [StrawFormatException] 实例
  ///
  /// [message] 为异常描述，[code] 为可选的错误代码。
  const StrawFormatException(super.message, {super.code});
}
