import 'dart:io';
import 'dart:typed_data';

import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/crypto/crypto_service.dart';
import 'package:strawhut/core/crypto/native/native_crypto_service.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';

/// 带回退的加密服务
///
/// 优先使用原生平台 API，如果不可用则回退到纯 Dart 实现。
/// 在 App 启动时主动初始化 delegate，避免首次加密时的冷启动延迟。
///
/// 回退触发条件：
/// - Android: MethodChannel 调用失败
/// - Windows: BCrypt API 不可用（版本低于 19041）或 FFI 通道探测失败
/// - 其他平台: isNativeSupported 为 false，直接使用纯 Dart 实现
class FallbackCryptoService implements ICryptoService {
  /// 创建带回退的加密服务
  ///
  /// [integrityService] 用于完整性校验
  FallbackCryptoService(this.integrityService);

  /// 完整性校验服务依赖
  final IntegrityService integrityService;

  /// 实际执行加密操作的委托服务
  ICryptoService? _delegate;

  /// 是否已完成初始化
  bool _initialized = false;

  /// 主动初始化 delegate，应在 App 启动时调用
  ///
  /// 提前完成平台检测和原生通道初始化，避免首次加密操作时
  /// 的延迟。如不调用此方法，将在首次加密操作时懒初始化。
  ///
  /// 此方法是幂等的，重复调用无副作用。
  Future<void> initialize() async {
    if (_initialized) return;
    _delegate = await _createDelegate();
    _initialized = true;
  }

  /// 获取当前 delegate（懒初始化）
  Future<ICryptoService> _getDelegate() async {
    if (_initialized && _delegate != null) return _delegate!;

    _delegate = await _createDelegate();
    _initialized = true;
    return _delegate!;
  }

  /// 创建 delegate 实例
  ///
  /// 优先尝试创建原生加密服务，失败时回退到纯 Dart 实现。
  Future<ICryptoService> _createDelegate() async {
    if (NativeCryptoService.isNativeSupported) {
      try {
        final channel = NativeCryptoService.createChannel();

        // Windows 版本检测：FfiCryptoChannel 构造时已检测
        // 通过轻量级探测验证通道可用性
        if (Platform.isWindows) {
          // 尝试生成随机数验证 FFI 通道可用
          await channel.generateRandom(1);
        }

        // Android 端探测：尝试生成密钥验证 MethodChannel 可用
        if (Platform.isAndroid) {
          await channel.generateRandom(1);
        }

        return NativeCryptoService(integrityService, channel);
      } on Object catch (_) {
        // 原生 API 初始化失败，回退到纯 Dart 实现
      }
    }

    // 回退到纯 Dart 实现
    return CryptoService(integrityService);
  }

  @override
  Future<GeneratedKey> generateKey() async {
    final delegate = await _getDelegate();
    return delegate.generateKey();
  }

  @override
  void clearSensitiveData() {
    _delegate?.clearSensitiveData();
  }

  @override
  Future<Uint8List> deriveKeyFromPassphrase({
    required String passphrase,
    required Uint8List salt,
    int iterations = KDF_ITERATIONS,
    CancellationToken? cancellationToken,
  }) async {
    // Native PBKDF2 is synchronous on the Android platform thread and through
    // Windows FFI. For user-cancellable decrypt flows, keep derivation in a
    // Dart worker isolate so the UI can process the cancellation request.
    if (cancellationToken != null) {
      final dartService = CryptoService(integrityService);
      return dartService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
        cancellationToken: cancellationToken,
      );
    }

    final delegate = await _getDelegate();
    try {
      return delegate.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
        cancellationToken: cancellationToken,
      );
    } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
      // 原生 PBKDF2 不支持（Windows 版本过低），回退到纯 Dart 实现
      final dartService = CryptoService(integrityService);
      return dartService.deriveKeyFromPassphrase(
        passphrase: passphrase,
        salt: salt,
        iterations: iterations,
        cancellationToken: cancellationToken,
      );
    }
  }

  /// 加密载荷（统一接口）
  ///
  /// 委托给 delegate 执行。如果 delegate 抛出 UnsupportedError，
  /// 回退到纯 Dart 实现。
  @override
  Future<EncryptResult> encrypt({
    required Uint8List payloadBytes,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
    bool useV21Security = true,
    CancellationToken? cancellationToken,
  }) async {
    final delegate = await _getDelegate();
    try {
      return delegate.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: payloadMetadata,
        key: key,
        chunkSize: chunkSize,
        onProgress: onProgress,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
      );
    } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
      final dartService = CryptoService(integrityService);
      return dartService.encrypt(
        payloadBytes: payloadBytes,
        payloadMetadata: payloadMetadata,
        key: key,
        chunkSize: chunkSize,
        onProgress: onProgress,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
      );
    }
  }

  /// 解密载荷（统一接口）
  ///
  /// 委托给 delegate 执行。如果 delegate 抛出 UnsupportedError，
  /// 回退到纯 Dart 实现。
  @override
  Future<DecryptResult> decrypt({
    required List<ChunkInfo> chunks,
    required Uint8List key,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
    bool useV21Security = false,
  }) async {
    final delegate = await _getDelegate();
    try {
      return delegate.decrypt(
        chunks: chunks,
        key: key,
        chunkSize: chunkSize,
        originalPayloadSize: originalPayloadSize,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        useV21Security: useV21Security,
      );
    } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
      final dartService = CryptoService(integrityService);
      return dartService.decrypt(
        chunks: chunks,
        key: key,
        chunkSize: chunkSize,
        originalPayloadSize: originalPayloadSize,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        useV21Security: useV21Security,
      );
    }
  }

  /// 流式加密（大文件场景）
  ///
  /// 委托给 delegate 执行。如果 delegate 抛出 UnsupportedError，
  /// 回退到纯 Dart 实现。
  @override
  Future<EncryptResult> encryptStream({
    required String sourcePath,
    required PayloadMetadata payloadMetadata,
    required Uint8List key,
    int chunkSize = DEFAULT_CHUNK_SIZE,
    void Function(int current, int total)? onProgress,
    bool useV21Security = true,
    CancellationToken? cancellationToken,
  }) async {
    final delegate = await _getDelegate();
    try {
      return delegate.encryptStream(
        sourcePath: sourcePath,
        payloadMetadata: payloadMetadata,
        key: key,
        chunkSize: chunkSize,
        onProgress: onProgress,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
      );
    } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
      final dartService = CryptoService(integrityService);
      return dartService.encryptStream(
        sourcePath: sourcePath,
        payloadMetadata: payloadMetadata,
        key: key,
        chunkSize: chunkSize,
        onProgress: onProgress,
        useV21Security: useV21Security,
        cancellationToken: cancellationToken,
      );
    }
  }

  /// 流式解密（大文件场景）
  ///
  /// 委托给 delegate 执行。如果 delegate 抛出 UnsupportedError，
  /// 回退到纯 Dart 实现。
  @override
  Future<DecryptStreamResult> decryptStream({
    required String strawFilePath,
    required Uint8List key,
    required String targetPath,
    required int chunkSize,
    required int originalPayloadSize,
    void Function(int current, int total)? onProgress,
    CancellationToken? cancellationToken,
    bool useV21Security = false,
    IntegritySink? integritySink,
  }) async {
    final delegate = await _getDelegate();
    try {
      return delegate.decryptStream(
        strawFilePath: strawFilePath,
        key: key,
        targetPath: targetPath,
        chunkSize: chunkSize,
        originalPayloadSize: originalPayloadSize,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        useV21Security: useV21Security,
        integritySink: integritySink,
      );
    } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
      final dartService = CryptoService(integrityService);
      return dartService.decryptStream(
        strawFilePath: strawFilePath,
        key: key,
        targetPath: targetPath,
        chunkSize: chunkSize,
        originalPayloadSize: originalPayloadSize,
        onProgress: onProgress,
        cancellationToken: cancellationToken,
        useV21Security: useV21Security,
        integritySink: integritySink,
      );
    }
  }

  @override
  Uint8List decryptLegacyContent({
    required String encryptedDataBase64,
    required String ivBase64,
    required Uint8List key,
  }) {
    if (_delegate != null) {
      try {
        return _delegate!.decryptLegacyContent(
          encryptedDataBase64: encryptedDataBase64,
          ivBase64: ivBase64,
          key: key,
        );
      } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
        final dartService = CryptoService(integrityService);
        return dartService.decryptLegacyContent(
          encryptedDataBase64: encryptedDataBase64,
          ivBase64: ivBase64,
          key: key,
        );
      }
    }
    final dartService = CryptoService(integrityService);
    return dartService.decryptLegacyContent(
      encryptedDataBase64: encryptedDataBase64,
      ivBase64: ivBase64,
      key: key,
    );
  }

  @override
  Uint8List deriveHmacKey(Uint8List encryptionKey) {
    if (_delegate != null) {
      try {
        return _delegate!.deriveHmacKey(encryptionKey);
      } on UnsupportedError { // ignore: avoid_catching_errors, Windows 平台不支持原生 PBKDF2 需要捕获 UnsupportedError 向上抛出
        final dartService = CryptoService(integrityService);
        return dartService.deriveHmacKey(encryptionKey);
      }
    }
    final dartService = CryptoService(integrityService);
    return dartService.deriveHmacKey(encryptionKey);
  }

  /// 获取当前使用的 delegate 类型（用于调试和测试）
  String get delegateTypeName {
    if (!_initialized || _delegate == null) return 'NotInitialized';
    return _delegate!.runtimeType.toString();
  }
}
