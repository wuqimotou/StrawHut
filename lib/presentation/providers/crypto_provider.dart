import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/crypto/native/fallback_crypto_service.dart';
import 'package:strawhut/core/file_io/file_io_service.dart';
import 'package:strawhut/core/file_io/file_selection_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/draft/draft_manager.dart';
part 'crypto_provider.g.dart';

/// 加密服务 Provider
///
/// 提供全局单例的加密服务实例，优先使用原生平台 API。
/// 使用 [FallbackCryptoService] 实现，原生 API 不可用时自动回退到纯 Dart 实现。
///
/// 使用方式：
/// ```dart
/// final crypto = ref.watch(cryptoServiceProvider);
/// final key = await crypto.generateKey();
/// ```
@riverpod
ICryptoService cryptoService(CryptoServiceRef ref) {
  final integrityService = ref.watch(integrityServiceProvider);
  final service = FallbackCryptoService(integrityService);
  // Provider 创建时主动初始化，避免首次加密操作时的冷启动延迟
  // initialize() 是幂等的，重复调用无副作用
  service.initialize();
  return service;
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

/// 文件选择服务 Provider
///
/// 提供全局单例的 FileSelectionService 实例，用于跨平台文件选择操作。
///
/// 使用方式：
/// ```dart
/// final fileSelection = ref.watch(fileSelectionServiceProvider);
/// final bytes = await fileSelection.pickStrawOrPngFile();
/// ```
@riverpod
FileSelectionService fileSelectionService(FileSelectionServiceRef ref) {
  return FileSelectionService();
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
