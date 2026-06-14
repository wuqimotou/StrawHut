// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passphrase_vault_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$passphraseVaultServiceHash() =>
    r'e344247f731adde30c4afe2d57c0b775e2703529';

/// 暗号保险库服务 Provider
///
/// 提供全局单例的 PassphraseVaultService 实例，用于暗号的增删查操作。
///
/// Copied from [passphraseVaultService].
@ProviderFor(passphraseVaultService)
final passphraseVaultServiceProvider =
    AutoDisposeProvider<PassphraseVaultService>.internal(
  passphraseVaultService,
  name: r'passphraseVaultServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$passphraseVaultServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PassphraseVaultServiceRef
    = AutoDisposeProviderRef<PassphraseVaultService>;
String _$passphraseEntriesHash() => r'd0fc19666c21feaf7d193b022040d7075375ae17';

/// 暗号保险库条目列表 Provider
///
/// 监听保险库数据变化，自动刷新 UI。
/// 返回按创建时间倒序排列的暗号条目列表。
///
/// Copied from [passphraseEntries].
@ProviderFor(passphraseEntries)
final passphraseEntriesProvider =
    AutoDisposeFutureProvider<List<PassphraseEntry>>.internal(
  passphraseEntries,
  name: r'passphraseEntriesProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$passphraseEntriesHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef PassphraseEntriesRef
    = AutoDisposeFutureProviderRef<List<PassphraseEntry>>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
