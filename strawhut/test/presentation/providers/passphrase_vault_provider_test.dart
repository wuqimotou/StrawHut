import 'package:flutter_test/flutter_test.dart';
import 'package:riverpod/riverpod.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_entry.dart';
import 'package:strawhut/core/passphrase_vault/passphrase_vault_service.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';

void main() {
  group('passphraseVaultServiceProvider', () {
    test('应返回 PassphraseVaultService 实例', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final result = container.read(passphraseVaultServiceProvider);

      expect(result, isA<PassphraseVaultService>());
    });

    test('多次读取应返回同一个实例（单例）', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final instance1 = container.read(passphraseVaultServiceProvider);
      final instance2 = container.read(passphraseVaultServiceProvider);

      expect(identical(instance1, instance2), isTrue);
    });
  });

  group('passphraseEntriesProvider', () {
    test('应返回 Future<List<PassphraseEntry>>', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final asyncValue = container.read(passphraseEntriesProvider);

      // 初始状态应该是 AsyncLoading 或 AsyncData
      expect(asyncValue, isA<AsyncValue<List<PassphraseEntry>>>());
    });
  });
}
