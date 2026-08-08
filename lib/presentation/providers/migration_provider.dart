import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/core/migration/migration_service.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

part 'migration_provider.g.dart';

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
@riverpod
MigrationService migrationService(MigrationServiceRef ref) {
  final cryptoService = ref.watch(cryptoServiceProvider);
  final integrityService = ref.watch(integrityServiceProvider);
  final fileIOService = ref.watch(fileIOServiceProvider);
  return MigrationService(
    cryptoService: cryptoService,
    integrityService: integrityService,
    fileIOService: fileIOService,
  );
}
