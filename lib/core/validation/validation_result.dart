/// 验证结果模型
///
/// 封装格式验证操作的结果，包含验证是否通过和错误信息列表。
///
/// 设计特点：
/// - 不可变对象（所有字段为 final）
/// - 提供便捷工厂方法：[success] 和 [failure]
/// - const 构造函数，支持编译期常量优化
///
/// 使用场景：
/// 1. FormatValidator.validateStrawFormat 验证 .straw 文件
/// 2. 验证通过 → 返回 ValidationResult.success()
/// 3. 验证失败 → 返回 ValidationResult.failure(['错误1', '错误2'])
/// 4. 调用方根据 isValid 决定是否继续处理
///
/// 使用示例：
/// ```dart
/// final result = formatValidator.validateStrawFormat(json);
/// if (!result.isValid) {
///   print('格式错误: ${result.errors}');
///   return;
/// }
/// ```
class ValidationResult {
  /// 验证是否通过
  ///
  /// true 表示文件格式正确，可以继续处理。
  /// false 表示格式有误，应拒绝处理并向用户展示错误信息。
  final bool isValid;

  /// 错误信息列表
  ///
  /// 当 isValid 为 false 时，此列表包含所有验证失败的详细描述。
  /// 每条错误信息均为人类可读的中文/英文描述，可直接展示给用户。
  ///
  /// 当 isValid 为 true 时，此列表为空（const []）。
  final List<String> errors;

  /// 创建验证结果实例
  ///
  /// 参数说明：
  /// - [isValid]: 验证是否通过，必填
  /// - [errors]: 错误信息列表，默认为空列表
  const ValidationResult({
    required this.isValid,
    this.errors = const [],
  });

  /// 创建成功的验证结果
  ///
  /// 工厂方法，返回 isValid 为 true、errors 为空的结果。
  ///
  /// 使用方式：
  /// ```dart
  /// return ValidationResult.success();
  /// ```
  factory ValidationResult.success() {
    return const ValidationResult(isValid: true);
  }

  /// 创建失败的验证结果
  ///
  /// 工厂方法，返回 isValid 为 false、errors 包含指定错误的结果。
  ///
  /// 参数：[errors] - 错误信息列表，不能为 null
  ///
  /// 使用方式：
  /// ```dart
  /// return ValidationResult.failure([
  ///   '缺少必填字段: meta.title',
  ///   '标签数量超过限制: 最多 10 个',
  /// ]);
  /// ```
  factory ValidationResult.failure(List<String> errors) {
    return ValidationResult(isValid: false, errors: errors);
  }
}
