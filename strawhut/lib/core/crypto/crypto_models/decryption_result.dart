/// 解密结果模型
///
/// 封装 AES-256-GCM 解密操作的结果。
/// 包含解密后的明文内容和完整性校验状态。
///
/// 字段说明：
/// - [deltaJson]: 解密后的 Quill Delta JSON 字符串，用于在阅读器中渲染富文本
/// - [integrityValid]: 完整性校验是否通过，表示文件是否被篡改
///
/// 设计特点：
/// - 不可变对象（所有字段为 final），确保解密结果不被意外修改
/// - const 构造函数，支持编译期常量优化
///
/// 使用场景：
/// 1. DecryptDialog 调用 CryptoService.decryptContent 获取 deltaJson
/// 2. 调用 IntegrityService.verifyIntegrity 校验完整性
/// 3. 组装为 DecryptionResult 返回给 ReaderScreen
/// 4. ReaderScreen 根据 integrityValid 决定是否展示内容和显示警告
///
/// 安全说明：
/// - [deltaJson] 包含敏感的明文内容，阅读完成后应尽快清理引用
/// - integrityValid 为 false 时，不应渲染内容，防止展示被篡改的数据
class DecryptionResult {
  /// 创建解密结果实例
  ///
  /// 参数说明：
  /// - [deltaJson]: 解密后的 Delta JSON 字符串，不能为 null
  /// - [integrityValid]: 完整性校验结果，不能为 null
  const DecryptionResult({
    required this.deltaJson,
    required this.integrityValid,
  });

  /// 从 JSON 映射反序列化为 [DecryptionResult]
  ///
  /// 用于从序列化数据中恢复解密结果（如测试场景、调试日志回放）。
  ///
  /// 输入格式：
  /// ```json
  /// {
  ///   "delta_json": "解密后的 Delta JSON 内容...",
  ///   "integrity_valid": true
  /// }
  /// ```
  ///
  /// 参数：
  /// - [json]: 包含解密结果字段的 JSON Map
  ///
  /// 返回：
  /// - 解析后的 [DecryptionResult] 实例
  ///
  /// 异常：
  /// - 如果缺少必填字段或类型不匹配，抛出类型转换异常
  factory DecryptionResult.fromJson(Map<String, dynamic> json) {
    return DecryptionResult(
      deltaJson: json['delta_json'] as String,
      integrityValid: json['integrity_valid'] as bool,
    );
  }

  /// 解密后的 Delta JSON 字符串
  ///
  /// 这是 Quill 编辑器导出的原始内容格式，包含 ops 数组。
  /// 可直接传递给 QuillEditor（只读模式）进行渲染。
  ///
  /// Delta JSON 示例：
  /// ```json
  /// {
  ///   "ops": [
  ///     { "insert": "标题\n", "attributes": { "header": 1 } },
  ///     { "insert": "正文内容\n" }
  ///   ]
  /// }
  /// ```
  final String deltaJson;

  /// 完整性校验是否有效
  ///
  /// true 表示文件内容的 SHA-256 哈希与 .straw 文件中存储的哈希一致，
  /// 文件未被篡改。
  ///
  /// false 表示哈希不匹配，文件可能已被恶意修改或损坏。
  /// 此时应向用户显示警告，不应渲染内容。
  final bool integrityValid;

  /// 将解密结果序列化为 JSON 映射
  ///
  /// 用于调试日志、测试断言或未来可能的缓存场景。
  ///
  /// 输出格式：
  /// ```json
  /// {
  ///   "delta_json": "解密后的 Delta JSON 内容...",
  ///   "integrity_valid": true
  /// }
  /// ```
  Map<String, dynamic> toJson() => {
        'delta_json': deltaJson,
        'integrity_valid': integrityValid,
      };
}
