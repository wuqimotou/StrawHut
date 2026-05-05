// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'crypto_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$cryptoServiceHash() => r'f040797ca9c5f7f5724597d3b44fbde6c3049fee';

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
///
/// Copied from [cryptoService].
@ProviderFor(cryptoService)
final cryptoServiceProvider = AutoDisposeProvider<CryptoService>.internal(
  cryptoService,
  name: r'cryptoServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$cryptoServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef CryptoServiceRef = AutoDisposeProviderRef<CryptoService>;
String _$integrityServiceHash() => r'672377d60eb48c2dbe6e4f1cae2914a5b6a0b9a0';

/// 完整性校验服务 Provider
///
/// 提供全局单例的 IntegrityService 实例，用于计算和验证文件哈希。
///
/// 使用方式：
/// ```dart
/// final integrity = ref.watch(integrityServiceProvider);
/// final hash = integrity.computeHash(content);
/// ```
///
/// Copied from [integrityService].
@ProviderFor(integrityService)
final integrityServiceProvider = AutoDisposeProvider<IntegrityService>.internal(
  integrityService,
  name: r'integrityServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$integrityServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef IntegrityServiceRef = AutoDisposeProviderRef<IntegrityService>;
String _$fileIOServiceHash() => r'e42071dad168f29d522e44822b1c06198b0c8d09';

/// 文件 I/O 服务 Provider
///
/// 提供全局单例的 FileIOService 实例，用于文件读取和写入操作。
///
/// 使用方式：
/// ```dart
/// final fileIO = ref.watch(fileIOServiceProvider);
/// final strawFile = await fileIO.readStrawFile(filePath);
/// ```
///
/// Copied from [fileIOService].
@ProviderFor(fileIOService)
final fileIOServiceProvider = AutoDisposeProvider<FileIOService>.internal(
  fileIOService,
  name: r'fileIOServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fileIOServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FileIOServiceRef = AutoDisposeProviderRef<FileIOService>;
String _$fileSelectionServiceHash() =>
    r'd86bdd23d2493e0054870f9d0ad49c4852d3d261';

/// 文件选择服务 Provider
///
/// 提供全局单例的 FileSelectionService 实例，用于跨平台文件选择操作。
///
/// 使用方式：
/// ```dart
/// final fileSelection = ref.watch(fileSelectionServiceProvider);
/// final bytes = await fileSelection.pickStrawOrPngFile();
/// ```
///
/// Copied from [fileSelectionService].
@ProviderFor(fileSelectionService)
final fileSelectionServiceProvider =
    AutoDisposeProvider<FileSelectionService>.internal(
  fileSelectionService,
  name: r'fileSelectionServiceProvider',
  debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
      ? null
      : _$fileSelectionServiceHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef FileSelectionServiceRef = AutoDisposeProviderRef<FileSelectionService>;
String _$draftManagerHash() => r'97df6e51ea03664f201a940df82f78dcf57e76f0';

/// 草稿管理器 Provider
///
/// 提供全局单例的 DraftManager 实例，用于内存草稿的保存和加载。
///
/// 使用方式：
/// ```dart
/// final draftManager = ref.watch(draftManagerProvider);
/// draftManager.saveToDraft(deltaJson);
/// ```
///
/// Copied from [draftManager].
@ProviderFor(draftManager)
final draftManagerProvider = AutoDisposeProvider<DraftManager>.internal(
  draftManager,
  name: r'draftManagerProvider',
  debugGetCreateSourceHash:
      const bool.fromEnvironment('dart.vm.product') ? null : _$draftManagerHash,
  dependencies: null,
  allTransitiveDependencies: null,
);

@Deprecated('Will be removed in 3.0. Use Ref instead')
// ignore: unused_element
typedef DraftManagerRef = AutoDisposeProviderRef<DraftManager>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
