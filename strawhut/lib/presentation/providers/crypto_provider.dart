import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/draft/draft_manager.dart';
part 'crypto_provider.g.dart';

/// 加密服务 Provider
///
/// 提供全局单例的 CryptoService 实例，用于加密/解密操作。
/// 依赖 IntegrityService，通过 Riverpod 的依赖注入机制自动获取。
///
/// 使用方式：
/// ```dart
/// final crypto = ref.watch(cryptoServiceProvider);
/// final key = await crypto.generateKey();
/// ```
@riverpod
CryptoService cryptoService(CryptoServiceRef ref) {
  final integrityService = ref.watch(integrityServiceProvider);
  return CryptoService(integrityService);
}

/// 完整性校验服务 Provider
///
/// 提供全局单例的 IntegrityService 实例，用于计算和验证文件哈希。
///
/// 使用方式：
/// ```dart
/// final integrity = ref.watch(integrityServiceProvider);
/// final hash = integrity.computeHash(content);
/// ```
@riverpod
IntegrityService integrityService(IntegrityServiceRef ref) {
  return IntegrityService();
}

/// 文件 I/O 服务 Provider
///
/// 提供全局单例的 FileIOService 实例，用于文件读取和写入操作。
///
/// 使用方式：
/// ```dart
/// final fileIO = ref.watch(fileIOServiceProvider);
/// final strawFile = await fileIO.readStrawFile(filePath);
/// ```
@riverpod
FileIOService fileIOService(FileIOServiceRef ref) {
  return FileIOService();
}

/// 草稿管理器 Provider
///
/// 提供全局单例的 DraftManager 实例，用于内存草稿的保存和加载。
///
/// 使用方式：
/// ```dart
/// final draftManager = ref.watch(draftManagerProvider);
/// draftManager.saveToDraft(deltaJson);
/// ```
@riverpod
DraftManager draftManager(DraftManagerRef ref) {
  return DraftManager();
}
