import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 文件操作相关异常
///
/// 在文件读取、写入、删除等操作失败时抛出此异常。
///
/// 常见触发场景：
/// - 文件不存在（路径错误或已被删除）
/// - 权限不足（无法读取或写入指定路径）
/// - 磁盘空间不足（写入失败）
/// - 文件扩展名不正确（非 .straw 或 .key）
/// - 文件系统 I/O 错误
///
/// 错误代码建议：
/// - 'FILE_NOT_FOUND': 文件不存在
/// - 'ACCESS_DENIED': 权限不足
/// - 'INVALID_EXTENSION': 文件扩展名不正确
/// - 'DISK_FULL': 磁盘空间不足
///
/// 使用示例：
/// ```dart
/// try {
///   final strawFile = await fileIOService.readStrawFile(path);
/// } on FileException catch (e) {
///   if (e.code == 'FILE_NOT_FOUND') {
///     showDialog('文件不存在');
///   }
/// }
/// ```
class FileException extends StrawHutException {
  /// 创建一个新的 [FileException] 实例
  ///
  /// [message] 为异常描述，[code] 为可选的错误代码。
  const FileException(super.message, {super.code});
}
