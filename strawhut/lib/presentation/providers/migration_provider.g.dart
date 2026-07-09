// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'migration_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$migrationServiceHash() => r'b24f044736bbf25fd8379cbfdc22024a29939c58';

/// 迁移服务 Provider
///
/// 提供全局单例的 MigrationService 实例，用于将旧版 JSON 格式的 .straw 文件
/// 迁移到新版二进制格式。
///
/// 使用方式：
/// ```dart
/// final migration = ref.watch(migrationServiceProvider);
/// final result = await migration.migrateFromDecryptedContent(...);
/// ```
///
/// Copied from [migrationService].
@ProviderFor(migrationService)
final migrationServiceProvider = AutoDisposeProvider<MigrationService>.internal(
  migrationService,
  name: r'migrationServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$migrationServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef MigrationServiceRef = AutoDisposeProviderRef<MigrationService>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
