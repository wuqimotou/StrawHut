import 'dart:convert';

import 'package:crypto/crypto.dart';

/// 完整性校验服务接口
///
/// 定义文件完整性校验的契约。通过 SHA-256 哈希算法验证文件内容是否被篡改。
///
/// 使用场景：
/// - 发布流程：加密内容写入 .straw 文件前，计算完整 JSON 的 SHA-256 哈希
/// - 解密流程：读取 .straw 文件后，重新计算哈希与文件中存储的哈希比对
/// - 密钥文件：.key 文件同样包含 integrity 字段，使用相同机制校验
///
/// 架构位置：核心服务层（Core Service Layer）
/// 被依赖方：CryptoService（发布流程）、DecryptDialog（解密流程）
abstract class IIntegrityService {
  /// 计算文件内容的 SHA-256 哈希值
  ///
  /// 对输入的完整 JSON 字符串计算 SHA-256 哈希，返回格式为 "sha256:{十六进制哈希值}"。
  ///
  /// 参数：[content] - 完整的 JSON 字符串（.straw 或 .key 文件内容）
  /// 返回：格式为 "sha256:abcdef1234567890..." 的哈希字符串
  String computeHash(String content);

  /// 验证文件完整性
  ///
  /// 重新计算内容的 SHA-256 哈希，与预期哈希进行比对。
  ///
  /// 参数：
  /// - [content] - 当前的文件内容（JSON 字符串）
  /// - [expectedHash] - 预期的哈希值（格式为 "sha256:{hex}"）
  /// 返回：true 表示哈希匹配，文件未被篡改；false 表示文件可能已被修改
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  });
}

/// 完整性校验服务实现
///
/// 实现 [IIntegrityService] 接口，使用 `crypto` 包的 SHA-256 算法。
///
/// 依赖的第三方库：
/// - `crypto` 包：提供 SHA-256 哈希计算（import 'package:crypto/crypto.dart'）
///
/// 哈希计算流程（computeHash）：
/// 1. 将 content 字符串转换为 UTF-8 字节数组
/// 2. 使用 crypto 包的 sha256 转换器计算哈希
/// 3. 将哈希字节转换为十六进制字符串
/// 4. 拼接为 "sha256:{hex}" 格式返回
///
/// 验证流程（verifyIntegrity）：
/// 1. 调用 computeHash(content) 计算当前内容的哈希
/// 2. 将计算结果与 expectedHash 进行字符串比对
/// 3. 返回比对结果
///
/// 使用示例：
/// ```dart
/// final integrityService = IntegrityService();
/// // 发布时计算哈希
/// final hash = integrityService.computeHash(strawFileJson);
/// // 解密时验证
/// final isValid = integrityService.verifyIntegrity(
///   content: currentFileJson,
///   expectedHash: storedHash,
/// );
/// ```
class IntegrityService implements IIntegrityService {
  /// 计算文件内容的 SHA-256 哈希值
  ///
  /// 实现说明（Phase 1）：
  /// 1. 使用 utf8.encode(content) 将字符串转为字节
  /// 2. 使用 sha256.convert(bytes) 计算哈希
  /// 3. 使用 digest.toString() 获取十六进制字符串
  /// 4. 返回 'sha256:$hex' 格式
  ///
  /// 注意：content 必须是完整的 JSON 字符串，包含 integrity 字段本身时
  /// 哈希值会不同。因此应在写入 integrity.hash 之前计算内容哈希。
  @override
  String computeHash(String content) {
    // 使用 crypto 包的 sha256 算法计算哈希
    final digest = sha256.convert(utf8.encode(content));
    return 'sha256:$digest';
  }

  /// 验证文件完整性
  ///
  /// 实现说明（Phase 1）：
  /// 1. 调用 computeHash(content) 重新计算当前内容的哈希
  /// 2. 与 expectedHash 进行字符串比对
  /// 3. 返回 true/false
  ///
  /// 注意：expectedHash 的格式应为 "sha256:{hex}"，
  /// 计算结果也使用相同格式，因此可以直接字符串比较。
  @override
  bool verifyIntegrity({
    required String content,
    required String expectedHash,
  }) {
    final computedHash = computeHash(content);
    return computedHash == expectedHash;
  }
}
