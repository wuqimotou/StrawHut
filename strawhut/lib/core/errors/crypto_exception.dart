import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 加密相关异常
class CryptoException extends StrawHutException {
  const CryptoException(super.message, {super.code});
}
