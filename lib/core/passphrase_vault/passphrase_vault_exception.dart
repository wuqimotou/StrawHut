import 'package:strawhut/core/errors/strawhut_exception.dart';

/// 暗号保险库异常
///
/// 在暗号保险库操作失败时抛出此异常。
///
/// 常见触发场景：
/// - 保险库已满，无法保存更多暗号
/// - 尝试保存重复的暗号
/// - 暗号强度不足（veryWeak）
/// - 指定的暗号条目不存在
/// - 存储读写操作失败
///
/// 错误代码规范：
/// - `VAULT_FULL`: 保险库已满，达到最大条目数量限制
/// - `DUPLICATE_PASSPHRASE`: 暗号已存在于保险库中
/// - `INVALID_PASSPHRASE`: 暗号强度不足（veryWeak）
/// - `NOT_FOUND`: 指定的暗号条目不存在
/// - `STORAGE_ERROR`: 存储读写操作失败
///
/// 使用示例：
/// ```dart
/// try {
///   await vaultService.savePassphrase(passphrase: 'MyPass', label: '测试');
/// } on PassphraseVaultException catch (e) {
///   if (e.code == 'VAULT_FULL') {
///     showDialog('保险库已满，请删除旧暗号后再试');
///   }
/// }
/// ```
class PassphraseVaultException extends StrawHutException {
  /// 创建一个新的 [PassphraseVaultException] 实例
  ///
  /// [message] 为异常描述，[code] 为可选的错误代码。
  const PassphraseVaultException(super.message, {super.code});
}
