/// 加密内容模型
///
/// 封装 AES-256-GCM 加密后的知识卡片内容。
/// 此模型对应 .straw 文件中 `content` 对象的结构。
///
/// 字段说明：
/// - [encryptedDataBase64]: Base64 编码的密文数据（URL-safe Base64）
/// - [ivBase64]: Base64 编码的初始化向量（IV），16 字节
/// - [algorithm]: 加密算法标识，当前固定为 "AES-256-GCM"
///
/// 设计特点：
/// - 不可变对象（所有字段为 final），确保加密内容不被意外修改
/// - 提供 [toJson] 方法，便于序列化到 .straw 文件
///
/// .straw 文件中 content 对象示例：
/// ```json
/// {
///   "encrypted_data": "Base64EncodedEncryptedContent...",
///   "encryption_algorithm": "AES-256-GCM",
///   "iv": "Base64EncodedIV..."
/// }
/// ```
///
/// 安全说明：
/// - IV 不需要保密，可随密文一起存储
/// - GCM 模式内置消息认证码（MAC），可检测密文篡改
/// - 加密内容只有使用正确的 256 位密钥才能解密
class EncryptedContent {
  /// 创建加密内容实例
  ///
  /// 参数说明：
  /// - [encryptedDataBase64]: Base64 编码的密文，不能为 null
  /// - [ivBase64]: Base64 编码的 IV，不能为 null
  /// - [algorithm]: 加密算法标识，不能为 null
  const EncryptedContent({
    required this.encryptedDataBase64,
    required this.ivBase64,
    required this.algorithm,
    this.saltBase64,
    this.kdfAlgorithm,
    this.kdfIterations,
  });

  /// 从 JSON 映射反序列化为 [EncryptedContent]
  ///
  /// 用于从 .straw 文件中读取 `content` 对象并解析。
  ///
  /// 输入格式：
  /// ```json
  /// {
  ///   "encrypted_data": "Base64EncodedEncryptedContent...",
  ///   "encryption_algorithm": "AES-256-GCM",
  ///   "iv": "Base64EncodedIV..."
  /// }
  /// ```
  ///
  /// 参数：
  /// - [json]: 包含加密内容字段的 JSON Map
  ///
  /// 返回：
  /// - 解析后的 [EncryptedContent] 实例
  ///
  /// 异常：
  /// - 如果缺少必填字段或类型不匹配，抛出类型转换异常
  factory EncryptedContent.fromJson(Map<String, dynamic> json) {
    return EncryptedContent(
      encryptedDataBase64: json['encrypted_data'] as String,
      ivBase64: json['iv'] as String,
      algorithm: json['encryption_algorithm'] as String,
      saltBase64: json['salt'] as String?,
      kdfAlgorithm: json['kdf_algorithm'] as String?,
      kdfIterations: json['kdf_iterations'] as int?,
    );
  }

  /// Base64 编码的加密数据
  ///
  /// 原始 Delta JSON 字符串经 AES-256-GCM 加密后的密文，再进行 Base64 编码。
  /// 对应 .straw 文件中的 `encrypted_data` 字段。
  final String encryptedDataBase64;

  /// Base64 编码的初始化向量（IV）
  ///
  /// 加密时生成的 16 字节随机 IV，Base64 编码后存储。
  /// 解密时需要使用相同的 IV 才能正确还原明文。
  /// 对应 .straw 文件中的 `iv` 字段。
  ///
  /// 注意：IV 不需要保密，但必须保证同一密钥下 IV 不重复。
  final String ivBase64;

  /// 加密算法标识
  ///
  /// 固定为 "AES-256-GCM"，用于未来支持多种加密算法时的版本识别。
  /// 对应 .straw 文件中的 `encryption_algorithm` 字段。
  final String algorithm;

  /// Base64 编码的盐值
  ///
  /// 用于密钥派生函数（KDF）的盐值，Base64 编码后存储。
  /// 仅在协商密钥加密模式下使用。
  /// 对应 .straw 文件中的 `salt` 字段。
  final String? saltBase64;

  /// 密钥派生算法标识
  ///
  /// 标识使用的密钥派生算法，如 "PBKDF2-HMAC-SHA256"。
  /// 仅在协商密钥加密模式下使用。
  /// 对应 .straw 文件中的 `kdf_algorithm` 字段。
  final String? kdfAlgorithm;

  /// KDF 迭代次数
  ///
  /// 密钥派生函数的迭代次数，如 100000。
  /// 仅在协商密钥加密模式下使用。
  /// 对应 .straw 文件中的 `kdf_iterations` 字段。
  final int? kdfIterations;

  /// 将加密内容序列化为 JSON 映射
  ///
  /// 返回的 Map 可直接嵌入 .straw 文件的 `content` 字段。
  ///
  /// 输出格式：
  /// ```json
  /// {
  ///   "encrypted_data": "Base64EncodedEncryptedContent...",
  ///   "encryption_algorithm": "AES-256-GCM",
  ///   "iv": "Base64EncodedIV..."
  /// }
  /// ```
  ///
  /// 注意：字段名使用下划线命名（如 `encryption_algorithm`），
  /// 与 .straw 文件格式规范保持一致。
  Map<String, dynamic> toJson() => {
        'encrypted_data': encryptedDataBase64,
        'encryption_algorithm': algorithm,
        'iv': ivBase64,
        'salt': saltBase64,
        'kdf_algorithm': kdfAlgorithm,
        'kdf_iterations': kdfIterations,
      };
}
