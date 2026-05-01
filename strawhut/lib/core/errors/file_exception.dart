import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 文件相关异常
class FileException extends StrawHutException {
  const FileException(super.message, {super.code});
}
