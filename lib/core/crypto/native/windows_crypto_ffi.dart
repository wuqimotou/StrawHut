/// Windows BCrypt (CNG) API FFI 绑定
///
/// 通过 dart:ffi 直接调用 Windows CNG (Cryptography Next Generation) API，
/// 提供以下密码学操作的原生实现：
///
/// - CSPRNG 随机数生成 (`BCryptGenRandom`)
/// - AES-256-GCM 加密/解密 (`BCryptEncrypt`/`BCryptDecrypt`)
/// - PBKDF2-HMAC-SHA256 密钥派生 (`BCryptDeriveKeyPBKDF2`)
/// - Windows 版本检测 (`RtlGetVersion`)
///
/// 架构位置：核心加密层 / 原生通道 (Core Crypto / Native Channel)
/// 依赖：dart:ffi, package:ffi, dart:io
/// 被依赖方：FfiCryptoChannel
///
/// 安全说明：
/// - 所有 FFI 调用均在 try-finally 中执行，确保 native 内存正确释放
/// - 使用 Arena 自动管理 native 内存生命周期，避免内存泄漏
/// - 不缓存任何 native 指针，每次调用重新分配和释放
/// - 严格校验输入参数，防止 FFI 调用导致 native crash
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

// ============================================================================
// Windows 常量定义
// ============================================================================

/// NTSTATUS 成功返回值
const int _statusSuccess = 0x00000000;

/// BCryptGenRandom 标志：使用默认 RNG 算法
const int _bcryptUseSystemPreferredRng = 0x00000002;

/// AES 算法标识符
const String _bcryptAesAlgorithm = 'AES';

/// HMAC-SHA256 算法标识符（用于 PBKDF2 PRF）
const String _bcryptHmacSha256Algorithm = 'SHA256';

/// BCryptOpenAlgorithmProvider 标志：创建 HMAC 算法句柄
/// 当使用 BCryptDeriveKeyPBKDF2 时，需要传入带有此标志的 HMAC 句柄
const int _bcryptAlgHandleHmacFlag = 0x00000008;

/// GCM 链模式标识符
const String _bcryptChainModeGcm = 'ChainingModeGCM';

/// BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体大小
///
/// 在 x64 平台上，由于指针对齐填充，结构体实际大小为 88 字节：
/// - cbSize(4) + dwInfoVersion(4) = 8
/// - pbNonce(8, 对齐到8) + cbNonce(4) = 12, 累计 20
/// - pbAuthData(8, 对齐到8, 偏移24) + cbAuthData(4) = 12, 累计 36
/// - pbTag(8, 对齐到8, 偏移40) + cbTag(4) = 12, 累计 52
/// - pbMacContext(8, 对齐到8, 偏移56) + cbMacContext(4) = 12, 累计 68
/// - cbAAD(4) = 4, 累计 72
/// - cbData(8, 对齐到8, 偏移72) = 8, 累计 80
/// - dwFlags(4) + 4字节尾部填充 = 8, 总计 88
///
/// 在 x86 平台上，指针为 4 字节，结构体大小为 52 字节。
final int _authInfoSize = _calculateAuthInfoSize();

/// BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 版本号
const int _authInfoVersion = 1;

/// GCM 认证标签长度（字节）
const int _gcmTagLength = 16;

/// GCM 推荐 IV 长度（字节），NIST SP 800-38D 推荐值
const int _gcmNonceLength = 12;

/// 支持 BCryptDeriveKeyPBKDF2 的最低 Windows 构建号
const int _minBuildForPbkdf2 = 19041;

/// OSVERSIONINFOEXW 结构体大小（字节）
const int _osVersionInfoSize = 284;

// ============================================================================
// FFI 类型定义 - BCryptGenRandom
// ============================================================================

/// NTSTATUS BCryptGenRandom(PUCHAR pbBuffer, ULONG cbBuffer, ULONG dwFlags)
typedef BCryptGenRandomNative =
    Int32 Function(Pointer<Uint8> pbBuffer, Uint32 cbBuffer, Uint32 dwFlags);

/// Dart 侧 BCryptGenRandom 函数签名
typedef BCryptGenRandomDart = int Function(Pointer<Uint8>, int, int);

// ============================================================================
// FFI 类型定义 - BCryptOpenAlgorithmProvider
// ============================================================================

/// NTSTATUS BCryptOpenAlgorithmProvider(
///   BCRYPT_ALG_HANDLE *phAlgorithm,
///   LPCWSTR pszAlgId,
///   LPCWSTR pszImplementation,
///   ULONG dwFlags
/// )
typedef BCryptOpenAlgorithmProviderNative =
    Int32 Function(
      Pointer<Pointer<Void>> phAlgorithm,
      Pointer<Utf16> pszAlgId,
      Pointer<Utf16> pszImplementation,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptOpenAlgorithmProvider 函数签名
typedef BCryptOpenAlgorithmProviderDart =
    int Function(Pointer<Pointer<Void>>, Pointer<Utf16>, Pointer<Utf16>, int);

// ============================================================================
// FFI 类型定义 - BCryptCloseAlgorithmProvider
// ============================================================================

/// NTSTATUS BCryptCloseAlgorithmProvider(
///   BCRYPT_ALG_HANDLE hAlgorithm, ULONG dwFlags)
typedef BCryptCloseAlgorithmProviderNative =
    Int32 Function(Pointer<Void> hAlgorithm, Uint32 dwFlags);

/// Dart 侧 BCryptCloseAlgorithmProvider 函数签名
typedef BCryptCloseAlgorithmProviderDart = int Function(Pointer<Void>, int);

// ============================================================================
// FFI 类型定义 - BCryptSetProperty
// ============================================================================

/// NTSTATUS BCryptSetProperty(
///   BCRYPT_HANDLE hObject,
///   LPCWSTR pszProperty,
///   PUCHAR pbInput,
///   ULONG cbInput,
///   ULONG dwFlags
/// )
typedef BCryptSetPropertyNative =
    Int32 Function(
      Pointer<Void> hObject,
      Pointer<Utf16> pszProperty,
      Pointer<Uint8> pbInput,
      Uint32 cbInput,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptSetProperty 函数签名
typedef BCryptSetPropertyDart =
    int Function(Pointer<Void>, Pointer<Utf16>, Pointer<Uint8>, int, int);

// ============================================================================
// FFI 类型定义 - BCryptGenerateSymmetricKey
// ============================================================================

/// NTSTATUS BCryptGenerateSymmetricKey(
///   BCRYPT_ALG_HANDLE hAlgorithm,
///   BCRYPT_KEY_HANDLE *phKey,
///   PUCHAR pbKeyObject,
///   ULONG cbKeyObject,
///   PUCHAR pbSecret,
///   ULONG cbSecret,
///   ULONG dwFlags
/// )
typedef BCryptGenerateSymmetricKeyNative =
    Int32 Function(
      Pointer<Void> hAlgorithm,
      Pointer<Pointer<Void>> phKey,
      Pointer<Uint8> pbKeyObject,
      Uint32 cbKeyObject,
      Pointer<Uint8> pbSecret,
      Uint32 cbSecret,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptGenerateSymmetricKey 函数签名
typedef BCryptGenerateSymmetricKeyDart =
    int Function(
      Pointer<Void>,
      Pointer<Pointer<Void>>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
    );

// ============================================================================
// FFI 类型定义 - BCryptDestroyKey
// ============================================================================

/// NTSTATUS BCryptDestroyKey(BCRYPT_KEY_HANDLE hKey)
typedef BCryptDestroyKeyNative = Int32 Function(Pointer<Void> hKey);

/// Dart 侧 BCryptDestroyKey 函数签名
typedef BCryptDestroyKeyDart = int Function(Pointer<Void>);

// ============================================================================
// FFI 类型定义 - BCryptEncrypt
// ============================================================================

/// NTSTATUS BCryptEncrypt(
///   BCRYPT_KEY_HANDLE hKey,
///   PUCHAR pbInput,
///   ULONG cbInput,
///   VOID *pPaddingInfo,
///   PUCHAR pbIV,
///   ULONG cbIV,
///   PUCHAR pbOutput,
///   ULONG cbOutput,
///   ULONG *pcbResult,
///   ULONG dwFlags
/// )
typedef BCryptEncryptNative =
    Int32 Function(
      Pointer<Void> hKey,
      Pointer<Uint8> pbInput,
      Uint32 cbInput,
      Pointer<Void> pPaddingInfo,
      Pointer<Uint8> pbIV,
      Uint32 cbIV,
      Pointer<Uint8> pbOutput,
      Uint32 cbOutput,
      Pointer<Uint32> pcbResult,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptEncrypt 函数签名
typedef BCryptEncryptDart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      int,
    );

// ============================================================================
// FFI 类型定义 - BCryptDecrypt
// ============================================================================

/// NTSTATUS BCryptDecrypt(
///   BCRYPT_KEY_HANDLE hKey,
///   PUCHAR pbInput,
///   ULONG cbInput,
///   VOID *pPaddingInfo,
///   PUCHAR pbIV,
///   ULONG cbIV,
///   PUCHAR pbOutput,
///   ULONG cbOutput,
///   ULONG *pcbResult,
///   ULONG dwFlags
/// )
typedef BCryptDecryptNative =
    Int32 Function(
      Pointer<Void> hKey,
      Pointer<Uint8> pbInput,
      Uint32 cbInput,
      Pointer<Void> pPaddingInfo,
      Pointer<Uint8> pbIV,
      Uint32 cbIV,
      Pointer<Uint8> pbOutput,
      Uint32 cbOutput,
      Pointer<Uint32> pcbResult,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptDecrypt 函数签名
typedef BCryptDecryptDart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      Pointer<Uint32>,
      int,
    );

// ============================================================================
// FFI 类型定义 - BCryptDeriveKeyPBKDF2 (Windows 10 19041+)
// ============================================================================

/// NTSTATUS BCryptDeriveKeyPBKDF2(
///   BCRYPT_ALG_HANDLE hPrf,
///   PUCHAR pbPassword,
///   ULONG cbPassword,
///   PUCHAR pbSalt,
///   ULONG cbSalt,
///   ULONGLONG cIterations,
///   PUCHAR pbDerivedKey,
///   ULONG cbDerivedKey,
///   ULONG dwFlags
/// )
typedef BCryptDeriveKeyPBKDF2Native =
    Int32 Function(
      Pointer<Void> hPrf,
      Pointer<Uint8> pbPassword,
      Uint32 cbPassword,
      Pointer<Uint8> pbSalt,
      Uint32 cbSalt,
      Uint64 cIterations,
      Pointer<Uint8> pbDerivedKey,
      Uint32 cbDerivedKey,
      Uint32 dwFlags,
    );

/// Dart 侧 BCryptDeriveKeyPBKDF2 函数签名
typedef BCryptDeriveKeyPBKDF2Dart =
    int Function(
      Pointer<Void>,
      Pointer<Uint8>,
      int,
      Pointer<Uint8>,
      int,
      int,
      Pointer<Uint8>,
      int,
      int,
    );

// ============================================================================
// FFI 类型定义 - RtlGetVersion (ntdll.dll)
// ============================================================================

/// NTSTATUS RtlGetVersion(OSVERSIONINFOEXW *lpVersionInformation)
typedef RtlGetVersionNative =
    Int32 Function(Pointer<Uint8> lpVersionInformation);

/// Dart 侧 RtlGetVersion 函数签名
typedef RtlGetVersionDart = int Function(Pointer<Uint8>);

// ============================================================================
// 动态库加载（仅 Windows 平台）
// ============================================================================

/// bcrypt.dll - Windows CNG 加密 API
///
/// 延迟加载：仅在首次访问时初始化，避免非 Windows 平台上的加载错误。
/// 由于此文件可能被非 Windows 平台的代码引用（如条件导入），
/// 必须在运行时检查平台后再加载 DLL。
final DynamicLibrary _bcrypt = Platform.isWindows
    ? DynamicLibrary.open('bcrypt.dll')
    : DynamicLibrary.process(); // 非 Windows 平台使用占位值，不会被实际调用

/// ntdll.dll - Windows NT 运行时库（用于版本检测）
final DynamicLibrary _ntdll = Platform.isWindows
    ? DynamicLibrary.open('ntdll.dll')
    : DynamicLibrary.process(); // 非 Windows 平台使用占位值，不会被实际调用

// ============================================================================
// FFI 函数绑定查找（仅 Windows 平台有效）
// ============================================================================

/// 辅助函数：安全查找 FFI 函数绑定
///
/// 在 Windows 平台上查找指定函数，在非 Windows 平台上抛出 [UnsupportedError]。
/// 由于所有 FFI 函数绑定使用 late final，仅在首次访问时求值，
/// 非 Windows 平台上只要不调用 WindowsCryptoFfi 的方法就不会触发求值。
DynamicLibrary _requireWindows() {
  if (!Platform.isWindows) {
    throw UnsupportedError('Windows BCrypt FFI 绑定仅在 Windows 平台上可用');
  }
  return _bcrypt;
}

final BCryptGenRandomDart _bcryptGenRandom = _requireWindows()
    .lookupFunction<BCryptGenRandomNative, BCryptGenRandomDart>(
      'BCryptGenRandom',
    );

final BCryptOpenAlgorithmProviderDart _bcryptOpenAlgorithmProvider =
    _requireWindows().lookupFunction<
      BCryptOpenAlgorithmProviderNative,
      BCryptOpenAlgorithmProviderDart
    >('BCryptOpenAlgorithmProvider');

final BCryptCloseAlgorithmProviderDart _bcryptCloseAlgorithmProvider =
    _requireWindows().lookupFunction<
      BCryptCloseAlgorithmProviderNative,
      BCryptCloseAlgorithmProviderDart
    >('BCryptCloseAlgorithmProvider');

final BCryptSetPropertyDart _bcryptSetProperty = _requireWindows()
    .lookupFunction<BCryptSetPropertyNative, BCryptSetPropertyDart>(
      'BCryptSetProperty',
    );

final BCryptGenerateSymmetricKeyDart _bcryptGenerateSymmetricKey =
    _requireWindows().lookupFunction<
      BCryptGenerateSymmetricKeyNative,
      BCryptGenerateSymmetricKeyDart
    >('BCryptGenerateSymmetricKey');

final BCryptDestroyKeyDart _bcryptDestroyKey = _requireWindows()
    .lookupFunction<BCryptDestroyKeyNative, BCryptDestroyKeyDart>(
      'BCryptDestroyKey',
    );

final BCryptEncryptDart _bcryptEncrypt = _requireWindows()
    .lookupFunction<BCryptEncryptNative, BCryptEncryptDart>('BCryptEncrypt');

final BCryptDecryptDart _bcryptDecrypt = _requireWindows()
    .lookupFunction<BCryptDecryptNative, BCryptDecryptDart>('BCryptDecrypt');

final BCryptDeriveKeyPBKDF2Dart _bcryptDeriveKeyPBKDF2 = _requireWindows()
    .lookupFunction<BCryptDeriveKeyPBKDF2Native, BCryptDeriveKeyPBKDF2Dart>(
      'BCryptDeriveKeyPBKDF2',
    );

final RtlGetVersionDart _rtlGetVersion = _ntdll
    .lookupFunction<RtlGetVersionNative, RtlGetVersionDart>('RtlGetVersion');

// ============================================================================
// Windows 版本检测结果缓存
// ============================================================================

/// 当前系统是否支持 BCryptDeriveKeyPBKDF2（构建号 >= 19041）
///
/// 在 FfiCryptoChannel 构造时通过 [_checkWindowsVersion] 初始化。
/// 检测结果缓存，避免每次调用时重复检测。
bool _supportsNativePbkdf2 = _checkWindowsVersion();

// ============================================================================
// Windows 版本检测
// ============================================================================

/// 通过 RtlGetVersion 获取真实 Windows 版本号
///
/// RtlGetVersion 是 ntdll.dll 中的未文档化 API，它返回真实的 Windows
/// 版本信息，不受应用程序兼容性清单影响（与 GetVersionEx 不同）。
///
/// 返回值：Windows 构建号（如 19041、22631），获取失败返回 null
int? _getWindowsBuildNumber() {
  if (!Platform.isWindows) return null;

  // 分配 OSVERSIONINFOEXW 结构体（284 字节）
  final pVersionInfo = calloc<Uint8>(_osVersionInfoSize);
  try {
    // 设置 dwOSVersionInfoSize 字段（结构体大小，必须先设置）
    // DWORD 在偏移量 0，占 4 字节
    pVersionInfo
        .asTypedList(4)
        .buffer
        .asByteData()
        .setUint32(0, _osVersionInfoSize, Endian.host);

    final status = _rtlGetVersion(pVersionInfo);
    if (status != _statusSuccess) {
      return null;
    }

    // 读取 dwBuildNumber 字段
    // 偏移量：dwOSVersionInfoSize(4) + dwMajorVersion(4)
    //         + dwMinorVersion(4) = 12
    final buildNumber = pVersionInfo
        .asTypedList(16)
        .buffer
        .asByteData()
        .getUint32(12, Endian.host);

    return buildNumber;
  } on Exception {
    return null;
  } finally {
    calloc.free(pVersionInfo);
  }
}

/// 检测当前 Windows 版本是否支持 BCryptDeriveKeyPBKDF2
///
/// BCryptDeriveKeyPBKDF2 要求 Windows 10 构建号 >= 19041。
/// 此方法在模块加载时调用一次，结果缓存在 [_supportsNativePbkdf2]。
///
/// 返回值：true 表示支持原生 PBKDF2，false 表示不支持或检测失败
bool _checkWindowsVersion() {
  if (!Platform.isWindows) return false;
  final buildNumber = _getWindowsBuildNumber();
  return buildNumber != null && buildNumber >= _minBuildForPbkdf2;
}

// ============================================================================
// BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体构建
// ============================================================================

/// 将偏移量向上对齐到指定边界
///
/// [offset] 当前偏移量
/// [alignment] 对齐边界（必须为 2 的幂）
///
/// 返回值：对齐后的偏移量
int _align(int offset, int alignment) {
  return (offset + alignment - 1) & ~(alignment - 1);
}

/// 动态计算 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体大小
///
/// 根据当前平台的指针大小（x64: 8 字节, x86: 4 字节）计算结构体的
/// 实际内存布局大小，包括对齐填充。
///
/// 结构体字段布局（按 C 编译器默认对齐规则）：
/// - cbSize (ULONG, 4 字节)
/// - dwInfoVersion (ULONG, 4 字节)
/// - pbNonce (PUCHAR, 指针大小, 8 字节对齐)
/// - cbNonce (ULONG, 4 字节)
/// - pbAuthData (PUCHAR, 指针大小, 8 字节对齐)
/// - cbAuthData (ULONG, 4 字节)
/// - pbTag (PUCHAR, 指针大小, 8 字节对齐)
/// - cbTag (ULONG, 4 字节)
/// - pbMacContext (PUCHAR, 指针大小, 8 字节对齐)
/// - cbMacContext (ULONG, 4 字节)
/// - cbAAD (ULONG, 4 字节)
/// - cbData (ULONGLONG, 8 字节对齐)
/// - dwFlags (DWORD, 4 字节)
/// - 尾部填充至结构体最大对齐的整数倍
int _calculateAuthInfoSize() {
  final ptrSize = sizeOf<Pointer<Uint8>>();
  final ptrAlign = ptrSize; // 指针对齐 = 指针大小
  var offset = 0;

  // cbSize (ULONG = 4 bytes)
  offset += 4;
  // dwInfoVersion (ULONG = 4 bytes)
  offset += 4;
  // pbNonce (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign) + ptrSize;
  // cbNonce (ULONG = 4 bytes)
  offset += 4;
  // pbAuthData (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign) + ptrSize;
  // cbAuthData (ULONG = 4 bytes)
  offset += 4;
  // pbTag (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign) + ptrSize;
  // cbTag (ULONG = 4 bytes)
  offset += 4;
  // pbMacContext (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign) + ptrSize;
  // cbMacContext (ULONG = 4 bytes)
  offset += 4;
  // cbAAD (ULONG = 4 bytes)
  offset += 4;
  // cbData (ULONGLONG = 8 bytes, 8 字节对齐)
  offset = _align(offset, 8) + 8;
  // dwFlags (DWORD = 4 bytes)
  offset += 4;
  // 尾部填充至结构体最大对齐的整数倍
  offset = _align(offset, ptrAlign > 8 ? ptrAlign : 8);

  return offset;
}

/// 构建 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体
///
/// 该结构体用于 BCryptEncrypt/BCryptDecrypt 的 GCM 模式认证加密。
///
/// 结构体布局遵循 C 编译器默认对齐规则：
/// - cbSize (ULONG, 4 字节): 结构体大小
/// - dwInfoVersion (ULONG, 4 字节): 版本号 = 1
/// - pbNonce (PUCHAR, 指针大小, 指针对齐): IV/Nonce 指针
/// - cbNonce (ULONG, 4 字节): IV/Nonce 长度
/// - pbAuthData (PUCHAR, 指针大小, 指针对齐): 附加认证数据指针（NULL）
/// - cbAuthData (ULONG, 4 字节): 附加认证数据长度（0）
/// - pbTag (PUCHAR, 指针大小, 指针对齐): 认证标签指针（16 字节）
/// - cbTag (ULONG, 4 字节): 认证标签长度（16）
/// - pbMacContext (PUCHAR, 指针大小, 指针对齐): MAC 上下文指针（NULL）
/// - cbMacContext (ULONG, 4 字节): MAC 上下文长度（0）
/// - cbAAD (ULONG, 4 字节): 附加认证数据长度（0）
/// - cbData (ULONGLONG, 8 字节, 8字节对齐): 数据长度（0）
/// - dwFlags (DWORD, 4 字节): 标志（0）
///
/// 参数：
/// - [arena]: Arena 用于内存分配，函数返回后由调用方统一释放
/// - [noncePtr]: IV/Nonce 的 native 内存指针
/// - [nonceLength]: IV/Nonce 的长度
/// - [tagPtr]: 认证标签的 native 内存指针
///
/// 返回值：指向构建好的结构体的 `Pointer<Uint8>`
Pointer<Uint8> _buildAuthInfo(
  Arena arena,
  Pointer<Uint8> noncePtr,
  int nonceLength,
  Pointer<Uint8> tagPtr,
) {
  final pAuthInfo = arena<Uint8>(_authInfoSize);
  final byteData = pAuthInfo.asTypedList(_authInfoSize).buffer.asByteData();

  final ptrSize = sizeOf<Pointer<Uint8>>();
  final ptrAlign = ptrSize;
  var offset = 0;

  // cbSize (ULONG = 4 bytes)
  byteData.setUint32(offset, _authInfoSize, Endian.host);
  offset += 4;

  // dwInfoVersion (ULONG = 4 bytes)
  byteData.setUint32(offset, _authInfoVersion, Endian.host);
  offset += 4;

  // pbNonce (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign);
  _writePointer(byteData, offset, noncePtr);
  offset += ptrSize;

  // cbNonce (ULONG = 4 bytes)
  byteData.setUint32(offset, nonceLength, Endian.host);
  offset += 4;

  // pbAuthData (PUCHAR = pointer, ptrAlign 对齐) - NULL
  offset = _align(offset, ptrAlign);
  _writePointer(byteData, offset, Pointer<Uint8>.fromAddress(0));
  offset += ptrSize;

  // cbAuthData (ULONG = 4 bytes) - 0
  byteData.setUint32(offset, 0, Endian.host);
  offset += 4;

  // pbTag (PUCHAR = pointer, ptrAlign 对齐)
  offset = _align(offset, ptrAlign);
  _writePointer(byteData, offset, tagPtr);
  offset += ptrSize;

  // cbTag (ULONG = 4 bytes) - 16
  byteData.setUint32(offset, _gcmTagLength, Endian.host);
  offset += 4;

  // pbMacContext (PUCHAR = pointer, ptrAlign 对齐) - NULL
  offset = _align(offset, ptrAlign);
  _writePointer(byteData, offset, Pointer<Uint8>.fromAddress(0));
  offset += ptrSize;

  // cbMacContext (ULONG = 4 bytes) - 0
  byteData.setUint32(offset, 0, Endian.host);
  offset += 4;

  // cbAAD (ULONG = 4 bytes) - 0
  byteData.setUint32(offset, 0, Endian.host);
  offset += 4;

  // cbData (ULONGLONG = 8 bytes, 8字节对齐) - 0
  offset = _align(offset, 8);
  byteData.setUint64(offset, 0, Endian.host);
  offset += 8;

  // dwFlags (DWORD = 4 bytes) - 0
  byteData.setUint32(offset, 0, Endian.host);

  return pAuthInfo;
}

/// 将 Pointer 值写入 ByteData 的指定偏移位置
///
/// 在 x64 平台上，Pointer 为 8 字节（uint64）。
/// 在 x86 平台上，Pointer 为 4 字节（uint32）。
void _writePointer(ByteData byteData, int offset, Pointer<Uint8> ptr) {
  final ptrSize = sizeOf<Pointer<Uint8>>();
  if (ptrSize == 8) {
    byteData.setUint64(offset, ptr.address, Endian.host);
  } else {
    byteData.setUint32(offset, ptr.address, Endian.host);
  }
}

/// 检查 NTSTATUS 返回值，非零时抛出异常
void _checkNtStatus(int status, String operation) {
  if (status != _statusSuccess) {
    final hexStatus = status.toRadixString(16).toUpperCase();
    throw WindowsCryptoException(
      'Windows BCrypt API 调用失败: '
      '$operation (NTSTATUS=0x$hexStatus)',
    );
  }
}

// ============================================================================
// 公共 API
// ============================================================================

/// Windows BCrypt (CNG) API FFI 绑定类
///
/// 提供对 Windows 原生加密 API 的静态方法封装，包括：
/// - CSPRNG 随机数生成
/// - AES-256-GCM 加密/解密
/// - PBKDF2-HMAC-SHA256 密钥派生
/// - Windows 版本检测
///
/// 使用示例：
/// ```dart
/// // 生成随机字节
/// final random = WindowsCryptoFfi.generateRandom(32);
///
/// // AES-256-GCM 加密
/// final result = WindowsCryptoFfi.encryptAesGcm(plaintext, key);
///
/// // AES-256-GCM 解密
/// final plaintext =
///     WindowsCryptoFfi.decryptAesGcm(ciphertext, key, iv);
///
/// // PBKDF2 密钥派生
/// final derivedKey = WindowsCryptoFfi.deriveKeyPBKDF2(
///     passphrase, salt, 100000, 32);
/// ```
class WindowsCryptoFfi {
  WindowsCryptoFfi._();

  /// 检查当前 Windows 版本是否支持 BCryptDeriveKeyPBKDF2
  ///
  /// BCryptDeriveKeyPBKDF2 要求 Windows 10 构建号 >= 19041。
  /// 此值在模块加载时通过 RtlGetVersion 检测并缓存。
  ///
  /// 返回值：
  /// - true: 当前系统支持原生 PBKDF2
  /// - false: 当前系统不支持（版本低于 19041 或非 Windows 平台）
  static bool get supportsPbkdf2 => _supportsNativePbkdf2;

  /// 生成密码学安全随机字节
  ///
  /// 使用 Windows BCryptGenRandom API（基于 AES-CTR-DRBG，符合 NIST SP 800-90A）
  /// 生成指定长度的密码学安全随机数。
  ///
  /// 参数：
  /// - [length]: 要生成的随机字节长度
  ///
  /// 返回值：包含随机字节的 [Uint8List]
  ///
  /// 异常：
  /// - [WindowsCryptoException]: BCryptGenRandom 调用失败时抛出
  static Uint8List generateRandom(int length) {
    if (length <= 0) {
      throw ArgumentError('length 必须为正整数，当前值: $length');
    }

    final pBuffer = calloc<Uint8>(length);
    try {
      final status = _bcryptGenRandom(
        pBuffer,
        length,
        _bcryptUseSystemPreferredRng,
      );
      _checkNtStatus(status, 'BCryptGenRandom');

      return Uint8List.fromList(pBuffer.asTypedList(length));
    } finally {
      calloc.free(pBuffer);
    }
  }

  /// AES-256-GCM 加密
  ///
  /// 使用 Windows BCrypt API 执行 AES-256-GCM 认证加密。
  ///
  /// 加密流程：
  /// 1. 打开 AES 算法提供者
  /// 2. 设置链模式为 GCM
  /// 3. 从密钥材料生成对称密钥
  /// 4. 生成 12 字节安全随机 IV
  /// 5. 构建 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体
  /// 6. 调用 BCryptEncrypt 执行加密
  /// 7. 输出 = 密文 + 16 字节 GCM 认证标签
  /// 8. 销毁密钥句柄，关闭算法提供者
  ///
  /// 参数：
  /// - [plaintext]: 明文字节数组
  /// - [key]: 32 字节 AES-256 密钥
  ///
  /// 返回值：记录类型，包含：
  /// - `ciphertext`: 密文（包含 16 字节 GCM 认证标签附加在末尾）
  /// - `iv`: 12 字节初始化向量
  ///
  /// 异常：
  /// - [ArgumentError]: 密钥长度不正确时抛出
  /// - [WindowsCryptoException]: BCrypt API 调用失败时抛出
  static ({Uint8List ciphertext, Uint8List iv}) encryptAesGcm(
    Uint8List plaintext,
    Uint8List key,
  ) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 密钥长度必须为 32 字节，当前: ${key.length} 字节');
    }

    final arena = Arena();
    try {
      // 1. 打开 AES 算法提供者
      final phAlgorithm = arena<Pointer<Void>>();
      final pszAlgId = _bcryptAesAlgorithm.toNativeUtf16(allocator: arena);

      var status = _bcryptOpenAlgorithmProvider(
        phAlgorithm,
        pszAlgId,
        Pointer<Utf16>.fromAddress(0), // pszImplementation = NULL（默认实现）
        0, // dwFlags = 0
      );
      _checkNtStatus(status, 'BCryptOpenAlgorithmProvider(AES)');

      final hAlgorithm = phAlgorithm.value;

      try {
        // 2. 设置链模式为 GCM
        final pszProperty = 'ChainingMode'.toNativeUtf16(allocator: arena);
        final pbInput = _bcryptChainModeGcm.toNativeUtf16(allocator: arena);
        // GCM 模式字符串的 UTF-16 字节长度（不含末尾 null）
        const cbInput = _bcryptChainModeGcm.length * 2;

        status = _bcryptSetProperty(
          hAlgorithm,
          pszProperty,
          pbInput.cast<Uint8>(),
          cbInput,
          0,
        );
        _checkNtStatus(status, 'BCryptSetProperty(ChainingModeGCM)');

        // 3. 从密钥材料生成对称密钥
        final phKey = arena<Pointer<Void>>();
        final pbSecret = arena<Uint8>(key.length);
        pbSecret.asTypedList(key.length).setAll(0, key);

        status = _bcryptGenerateSymmetricKey(
          hAlgorithm,
          phKey,
          Pointer<Uint8>.fromAddress(0), // pbKeyObject = NULL（由 API 分配）
          0, // cbKeyObject = 0
          pbSecret,
          key.length,
          0, // dwFlags = 0
        );
        _checkNtStatus(status, 'BCryptGenerateSymmetricKey');

        final hKey = phKey.value;

        try {
          // 4. 生成 12 字节安全随机 IV
          final iv = generateRandom(_gcmNonceLength);
          final pbNonce = arena<Uint8>(_gcmNonceLength);
          pbNonce.asTypedList(_gcmNonceLength).setAll(0, iv);

          // 5. 准备认证标签缓冲区（16 字节，加密后由 API 填充）
          final pbTag = arena<Uint8>(_gcmTagLength);

          // 6. 构建 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体
          final pAuthInfo = _buildAuthInfo(
            arena,
            pbNonce,
            _gcmNonceLength,
            pbTag,
          );

          // 7. 第一次调用 BCryptEncrypt 获取输出所需缓冲区大小
          final pcbResult = arena<Uint32>();

          status = _bcryptEncrypt(
            hKey,
            Pointer<Uint8>.fromAddress(0), // pbInput = NULL（查询大小）
            0, // cbInput = 0
            pAuthInfo.cast<Void>(), // pPaddingInfo = auth info
            pbNonce, // pbIV
            _gcmNonceLength, // cbIV
            Pointer<Uint8>.fromAddress(0), // pbOutput = NULL（查询大小）
            0, // cbOutput = 0
            pcbResult,
            0, // dwFlags = 0
          );
          _checkNtStatus(status, 'BCryptEncrypt(query size)');

          final outputSize = pcbResult.value;

          // 8. 第二次调用 BCryptEncrypt 执行实际加密
          final pbOutput = arena<Uint8>(outputSize);

          // 重新构建 auth info（因为 BCryptEncrypt 可能修改了 IV）
          // 重新填充 IV 值
          pbNonce.asTypedList(_gcmNonceLength).setAll(0, iv);

          // 重新构建 auth info 结构体
          final pAuthInfo2 = _buildAuthInfo(
            arena,
            pbNonce,
            _gcmNonceLength,
            pbTag,
          );

          status = _bcryptEncrypt(
            hKey,
            plaintext.isEmpty
                ? Pointer<Uint8>.fromAddress(0)
                : _copyToNative(arena, plaintext),
            plaintext.length, // cbInput
            pAuthInfo2.cast<Void>(), // pPaddingInfo = auth info
            pbNonce, // pbIV
            _gcmNonceLength, // cbIV
            pbOutput, // pbOutput
            outputSize, // cbOutput
            pcbResult,
            0, // dwFlags = 0
          );
          _checkNtStatus(status, 'BCryptEncrypt(encrypt)');

          final ciphertextLength = pcbResult.value;

          // 9. 组装结果：密文 + 认证标签
          // BCryptEncrypt 在 GCM 模式下输出密文（不含 tag），
          // tag 需要从 pbTag 单独读取并附加到密文末尾
          final ciphertext = Uint8List(ciphertextLength + _gcmTagLength);
          if (ciphertextLength > 0) {
            ciphertext.setAll(0, pbOutput.asTypedList(ciphertextLength));
          }
          ciphertext.setAll(ciphertextLength, pbTag.asTypedList(_gcmTagLength));

          return (ciphertext: ciphertext, iv: iv);
        } finally {
          _bcryptDestroyKey(hKey);
        }
      } finally {
        _bcryptCloseAlgorithmProvider(hAlgorithm, 0);
      }
    } finally {
      arena.releaseAll();
    }
  }

  /// AES-256-GCM 解密
  ///
  /// 使用 Windows BCrypt API 执行 AES-256-GCM 认证解密。
  ///
  /// 解密流程：
  /// 1. 打开 AES 算法提供者
  /// 2. 设置链模式为 GCM
  /// 3. 从密钥材料生成对称密钥
  /// 4. 从密文末尾提取 16 字节 GCM 认证标签
  /// 5. 构建 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体
  /// 6. 调用 BCryptDecrypt 执行解密（自动验证 GCM 标签）
  /// 7. 销毁密钥句柄，关闭算法提供者
  ///
  /// 参数：
  /// - [ciphertext]: 密文字节数组（末尾必须包含 16 字节 GCM 认证标签）
  /// - [key]: 32 字节 AES-256 密钥
  /// - [iv]: 初始化向量（支持 12 字节和 16 字节，兼容旧版文件）
  ///
  /// 返回值：解密后的明文字节数组
  ///
  /// 异常：
  /// - [ArgumentError]: 密钥长度不正确或密文过短时抛出
  /// - [WindowsCryptoException]: BCrypt API 调用失败时抛出
  ///   （包括 GCM 标签验证失败，即密钥错误或密文被篡改）
  static Uint8List decryptAesGcm(
    Uint8List ciphertext,
    Uint8List key,
    Uint8List iv,
  ) {
    if (key.length != 32) {
      throw ArgumentError('AES-256 密钥长度必须为 32 字节，当前: ${key.length} 字节');
    }
    if (ciphertext.length < _gcmTagLength) {
      throw ArgumentError(
        '密文长度必须至少为 $_gcmTagLength 字节（GCM 认证标签），当前: ${ciphertext.length} 字节',
      );
    }
    if (iv.length != _gcmNonceLength && iv.length != 16) {
      throw ArgumentError(
        'IV 长度必须为 $_gcmNonceLength 或 16 字节，当前: ${iv.length} 字节',
      );
    }

    final arena = Arena();
    try {
      // 1. 打开 AES 算法提供者
      final phAlgorithm = arena<Pointer<Void>>();
      final pszAlgId = _bcryptAesAlgorithm.toNativeUtf16(allocator: arena);

      var status = _bcryptOpenAlgorithmProvider(
        phAlgorithm,
        pszAlgId,
        Pointer<Utf16>.fromAddress(0),
        0,
      );
      _checkNtStatus(status, 'BCryptOpenAlgorithmProvider(AES)');

      final hAlgorithm = phAlgorithm.value;

      try {
        // 2. 设置链模式为 GCM
        final pszProperty = 'ChainingMode'.toNativeUtf16(allocator: arena);
        final pbInput = _bcryptChainModeGcm.toNativeUtf16(allocator: arena);
        const cbInput = _bcryptChainModeGcm.length * 2;

        status = _bcryptSetProperty(
          hAlgorithm,
          pszProperty,
          pbInput.cast<Uint8>(),
          cbInput,
          0,
        );
        _checkNtStatus(status, 'BCryptSetProperty(ChainingModeGCM)');

        // 3. 从密钥材料生成对称密钥
        final phKey = arena<Pointer<Void>>();
        final pbSecret = arena<Uint8>(key.length);
        pbSecret.asTypedList(key.length).setAll(0, key);

        status = _bcryptGenerateSymmetricKey(
          hAlgorithm,
          phKey,
          Pointer<Uint8>.fromAddress(0),
          0,
          pbSecret,
          key.length,
          0,
        );
        _checkNtStatus(status, 'BCryptGenerateSymmetricKey');

        final hKey = phKey.value;

        try {
          // 4. 从密文末尾分离认证标签和实际密文
          final tagOffset = ciphertext.length - _gcmTagLength;
          final actualCiphertextLength = tagOffset;

          // 复制 IV 到 native 内存
          final pbNonce = arena<Uint8>(iv.length);
          pbNonce.asTypedList(iv.length).setAll(0, iv);

          // 复制认证标签到 native 内存
          final pbTag = arena<Uint8>(_gcmTagLength);
          pbTag
              .asTypedList(_gcmTagLength)
              .setAll(0, ciphertext.sublist(tagOffset));

          // 5. 构建 BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO 结构体
          final pAuthInfo = _buildAuthInfo(arena, pbNonce, iv.length, pbTag);

          // 6. 第一次调用 BCryptDecrypt 获取输出所需缓冲区大小
          final pcbResult = arena<Uint32>();

          status = _bcryptDecrypt(
            hKey,
            Pointer<Uint8>.fromAddress(0), // pbInput = NULL（查询大小）
            0, // cbInput = 0
            pAuthInfo.cast<Void>(), // pPaddingInfo = auth info
            pbNonce, // pbIV
            iv.length, // cbIV
            Pointer<Uint8>.fromAddress(0), // pbOutput = NULL（查询大小）
            0, // cbOutput = 0
            pcbResult,
            0,
          );
          _checkNtStatus(status, 'BCryptDecrypt(query size)');

          final outputSize = pcbResult.value;

          // 7. 第二次调用 BCryptDecrypt 执行实际解密
          final pbOutput = arena<Uint8>(outputSize);

          // 重新填充 IV 和 Tag（因为 BCryptDecrypt 可能修改了这些值）
          pbNonce.asTypedList(iv.length).setAll(0, iv);
          pbTag
              .asTypedList(_gcmTagLength)
              .setAll(0, ciphertext.sublist(tagOffset));

          // 重新构建 auth info 结构体
          final pAuthInfo2 = _buildAuthInfo(arena, pbNonce, iv.length, pbTag);

          status = _bcryptDecrypt(
            hKey,
            actualCiphertextLength == 0
                ? Pointer<Uint8>.fromAddress(0)
                : _copyToNative(
                    arena,
                    ciphertext.sublist(0, actualCiphertextLength),
                  ),
            actualCiphertextLength,
            pAuthInfo2.cast<Void>(),
            pbNonce,
            iv.length,
            pbOutput,
            outputSize,
            pcbResult,
            0,
          );
          _checkNtStatus(status, 'BCryptDecrypt(decrypt)');

          final plaintextLength = pcbResult.value;
          return Uint8List.fromList(pbOutput.asTypedList(plaintextLength));
        } finally {
          _bcryptDestroyKey(hKey);
        }
      } finally {
        _bcryptCloseAlgorithmProvider(hAlgorithm, 0);
      }
    } finally {
      arena.releaseAll();
    }
  }

  /// PBKDF2-HMAC-SHA256 密钥派生
  ///
  /// 使用 Windows BCryptDeriveKeyPBKDF2 API 执行 PBKDF2-HMAC-SHA256
  /// 密钥派生。此 API 要求 Windows 10 构建号 >= 19041。
  ///
  /// 调用流程：
  /// 1. 打开 HMAC-SHA256 算法提供者（作为 PRF）
  /// 2. 调用 BCryptDeriveKeyPBKDF2 执行密钥派生
  /// 3. 关闭算法提供者
  ///
  /// 参数：
  /// - [passphrase]: 用户口令字符串
  /// - [salt]: 盐值字节数组
  /// - [iterations]: PBKDF2 迭代次数
  /// - [keyLength]: 派生密钥长度（字节）
  ///
  /// 返回值：派生出的密钥字节数组
  ///
  /// 异常：
  /// - [UnsupportedError]: 当前 Windows 版本不支持 BCryptDeriveKeyPBKDF2 时抛出
  /// - [ArgumentError]: 参数无效时抛出
  /// - [WindowsCryptoException]: BCrypt API 调用失败时抛出
  static Uint8List deriveKeyPBKDF2(
    String passphrase,
    Uint8List salt,
    int iterations,
    int keyLength,
  ) {
    if (!_supportsNativePbkdf2) {
      throw UnsupportedError(
        'BCryptDeriveKeyPBKDF2 要求 Windows 10 构建号 >= '
        '$_minBuildForPbkdf2。'
        '当前系统不支持此 API，请回退到纯 Dart PBKDF2 实现。',
      );
    }
    if (passphrase.isEmpty) {
      throw ArgumentError('口令不能为空');
    }
    if (salt.isEmpty) {
      throw ArgumentError('盐值不能为空');
    }
    if (iterations <= 0) {
      throw ArgumentError('迭代次数必须为正整数，当前值: $iterations');
    }
    if (keyLength <= 0) {
      throw ArgumentError('密钥长度必须为正整数，当前值: $keyLength');
    }

    final arena = Arena();
    try {
      // 1. 打开 HMAC-SHA256 算法提供者（作为 PBKDF2 的 PRF）
      // 必须使用 BCRYPT_ALG_HANDLE_HMAC_FLAG 标志，才能获得 HMAC 句柄
      final phPrf = arena<Pointer<Void>>();
      final pszAlgId = _bcryptHmacSha256Algorithm.toNativeUtf16(
        allocator: arena,
      );

      var status = _bcryptOpenAlgorithmProvider(
        phPrf,
        pszAlgId,
        Pointer<Utf16>.fromAddress(0),
        _bcryptAlgHandleHmacFlag, // BCRYPT_ALG_HANDLE_HMAC_FLAG
      );
      _checkNtStatus(status, 'BCryptOpenAlgorithmProvider(SHA256/HMAC)');

      final hPrf = phPrf.value;

      try {
        // 2. 准备口令字节数组（UTF-8 编码，与纯 Dart 实现一致）
        final passphraseBytes = Uint8List.fromList(utf8.encode(passphrase));
        final pbPassword = arena<Uint8>(passphraseBytes.length);
        pbPassword
            .asTypedList(passphraseBytes.length)
            .setAll(0, passphraseBytes);

        // 3. 准备盐值
        final pbSalt = arena<Uint8>(salt.length);
        pbSalt.asTypedList(salt.length).setAll(0, salt);

        // 4. 准备输出缓冲区
        final pbDerivedKey = arena<Uint8>(keyLength);

        // 5. 执行 PBKDF2 密钥派生
        status = _bcryptDeriveKeyPBKDF2(
          hPrf,
          pbPassword,
          passphraseBytes.length,
          pbSalt,
          salt.length,
          iterations,
          pbDerivedKey,
          keyLength,
          0, // dwFlags = 0
        );
        _checkNtStatus(status, 'BCryptDeriveKeyPBKDF2');

        return Uint8List.fromList(pbDerivedKey.asTypedList(keyLength));
      } finally {
        _bcryptCloseAlgorithmProvider(hPrf, 0);
      }
    } finally {
      arena.releaseAll();
    }
  }
}

// ============================================================================
// 辅助函数
// ============================================================================

/// 将 Dart Uint8List 复制到 Arena 分配的 native 内存
///
/// 参数：
/// - [arena]: Arena 内存分配器
/// - [data]: 要复制的字节数组
///
/// 返回值：指向 native 内存中数据副本的指针
Pointer<Uint8> _copyToNative(Arena arena, Uint8List data) {
  final ptr = arena<Uint8>(data.length);
  ptr.asTypedList(data.length).setAll(0, data);
  return ptr;
}

// ============================================================================
// 异常类
// ============================================================================

/// Windows 加密操作异常
///
/// 在 Windows BCrypt API 调用失败时抛出此异常。
/// 包含 NTSTATUS 错误码信息，便于调试和问题定位。
///
/// 常见触发场景：
/// - BCrypt API 返回非零 NTSTATUS
/// - FFI 调用参数错误
/// - 内存分配失败
class WindowsCryptoException implements Exception {
  /// 创建一个新的 [WindowsCryptoException] 实例
  ///
  /// [message] 为异常描述，包含操作名称和 NTSTATUS 错误码。
  const WindowsCryptoException(this.message);

  /// 异常描述信息
  final String message;

  @override
  String toString() => 'WindowsCryptoException: $message';
}
