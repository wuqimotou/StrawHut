/// StrawHut 基础异常类
abstract class StrawHutException implements Exception {
  final String message;
  final String? code;

  const StrawHutException(this.message, {this.code});

  @override
  String toString() => 'StrawHutException($code): $message';
}
