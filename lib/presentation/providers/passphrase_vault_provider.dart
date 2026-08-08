import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';

part 'passphrase_vault_provider.g.dart';

/// 暗号保险库服务 Provider
///
/// 提供全局单例的 PassphraseVaultService 实例，用于暗号的增删查操作。
@riverpod
PassphraseVaultService passphraseVaultService(PassphraseVaultServiceRef ref) {
  return PassphraseVaultService();
}

/// 暗号保险库条目列表 Provider
///
/// 监听保险库数据变化，自动刷新 UI。
/// 返回按创建时间倒序排列的暗号条目列表。
@riverpod
Future<List<PassphraseEntry>> passphraseEntries(
  PassphraseEntriesRef ref,
) async {
  final vaultService = ref.watch(passphraseVaultServiceProvider);
  return vaultService.getAllEntries();
}
