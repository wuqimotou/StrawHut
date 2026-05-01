import 'package:strawhut/core/validation/validation_result.dart';

/// 格式验证器接口
abstract class IFormatValidator {
  ValidationResult validateStrawFormat(Map<String, dynamic> json);
  ValidationResult validateKeyFormat(Map<String, dynamic> json);
}
