import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models/encrypt_result.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';
import 'package:strawhut/core/utils/memory_utils.dart';
import 'package:strawhut/core/utils/temp_file_manager.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_file_upload.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_input.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/passphrase_decrypt_input.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/add_passphrase_dialog.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 解密对话框
///
/// 知识卡片解密的弹窗界面，支持两种解密方式：
/// - 随机密钥模式：手动输入 Base64 密钥字符串或上传 .key 密钥文件
/// - 协商密钥模式：输入暗号（passphrase）派生密钥解密
///
/// 架构位置：应用层（Presentation Layer）→ 对话框
/// 弹出方式：从 ReaderScreen 自动弹出或手动调用
///
/// 对话框结构：
/// - 标题："解密知识卡片"
/// - 卡片元数据预览（标题、描述、发布者）
/// - 随机密钥模式：
///   - KeyInput：手动输入密钥字符串
///   - KeyFileUpload：上传 .key 文件获取密钥
/// - 协商密钥模式：
///   - PassphraseDecryptInput：输入暗号
/// - 底部按钮："取消"、"解密"
///
/// 完整解密流程：
/// 1. 展示当前卡片的元数据预览
/// 2. 根据加密模式显示不同输入区域
/// 3. 点击"解密"按钮
/// 4. 调用 CryptoService.decrypt() 解密（新接口，返回 DecryptResult）
/// 5. 调用 IntegrityService.verifyIntegrity() 校验完整性
/// 6. 解密成功 → 关闭对话框，调用 onDecryptSuccess 回调（传入 DecryptResult）
/// 7. 解密失败 → 显示错误提示
///
/// 使用示例：
/// ```dart
/// await DecryptDialog.show(
///   context,
///   strawFile: strawFile,
///   parsedFile: parsedFile,
///   onDecryptSuccess: (result) {
///     // 处理解密结果（包含 PayloadMetadata + payloadBytes）
///     Navigator.push(context, ...);
///   },
/// );
/// ```
class DecryptDialog extends ConsumerStatefulWidget {
  /// 创建解密对话框实例
  ///
  /// 参数：
  /// - [strawFile] - 要解密的 .straw 文件对象，必填
  /// - [parsedFile] - 解析后的 .straw 文件对象（包含分块数据），必填
  /// - [onDecryptSuccess] - 解密成功后的回调函数，
  ///   参数为解密结果（包含 PayloadMetadata 和 payloadBytes）
  /// - [strawFilePath] - .straw 文件路径，用于流式解密大文件，可选
  const DecryptDialog({
    super.key,
    required this.strawFile,
    required this.parsedFile,
    required this.onDecryptSuccess,
    this.strawFilePath,
  });

  /// 要解密的 .straw 文件对象（JSON Header 部分）
  final StrawFile strawFile;

  /// 解析后的 .straw 文件对象（包含分块数据）
  final ParsedStrawFile parsedFile;

  /// 解密成功回调
  ///
  /// 解密和完整性校验全部通过后触发。
  /// 参数为解密结果，包含载荷元数据和解密后的字节。
  final void Function(DecryptResult result) onDecryptSuccess;

  /// .straw 文件路径，用于流式解密大文件
  ///
  /// 当文件路径可用且文件为大文件（originalPayloadSize > 10MB）时，
  /// 使用 [CryptoService.decryptStream] 流式解密，避免 OOM。
  /// 路径不可用时（如 Android Intent 接收的字节数据），使用内存解密。
  final String? strawFilePath;

  /// 弹出解密对话框
  ///
  /// 便捷静态方法，简化对话框的弹出调用。
  ///
  /// 参数：
  /// - [context] - BuildContext 对象
  /// - [strawFile] - 要解密的 .straw 文件对象
  /// - [parsedFile] - 解析后的 .straw 文件对象（包含分块数据）
  /// - [onDecryptSuccess] - 解密成功后的回调函数
  /// - [strawFilePath] - .straw 文件路径，用于流式解密大文件，可选
  static Future<void> show(
    BuildContext context, {
    required StrawFile strawFile,
    required ParsedStrawFile parsedFile,
    required void Function(DecryptResult result) onDecryptSuccess,
    String? strawFilePath,
  }) {
    // On Android, use bottom sheet for better mobile UX
    if (defaultTargetPlatform == TargetPlatform.android) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        isDismissible: false,
        enableDrag: false,
        useSafeArea: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (context) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          maxChildSize: 0.95,
          builder: (context, scrollController) => _DecryptDialogMobile(
            scrollController: scrollController,
            strawFile: strawFile,
            parsedFile: parsedFile,
            onDecryptSuccess: onDecryptSuccess,
            strawFilePath: strawFilePath,
          ),
        ),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DecryptDialog(
        strawFile: strawFile,
        parsedFile: parsedFile,
        onDecryptSuccess: onDecryptSuccess,
        strawFilePath: strawFilePath,
      ),
    );
  }

  @override
  ConsumerState<DecryptDialog> createState() => _DecryptDialogState();
}

/// DecryptDialog 的内部状态管理类
///
/// 负责管理解密流程的所有状态和业务逻辑：
/// - 密钥输入状态（手动输入和 .key 文件上传）
/// - 暗号输入状态（协商密钥模式）
/// - 解密流程控制（loading、error）
/// - 调用 CryptoService 和 IntegrityService
/// - 敏感数据清理
class _DecryptDialogState extends ConsumerState<DecryptDialog> {
  /// 密钥输入组件的全局 Key，用于访问其方法
  final _keyInputKey = GlobalKey<KeyInputState>();

  /// 暗号输入组件的全局 Key，用于访问其方法
  final _passphraseInputKey = GlobalKey<PassphraseDecryptInputState>();

  /// 加载状态（解密进行中）
  bool _isLoading = false;

  bool _isCancelling = false;

  CancellationToken? _cancellationToken;

  /// 解密进度（0.0 ~ 1.0），仅当 _isLoading 为 true 时有意义
  double _decryptProgress = 0.0;

  /// 错误消息
  String? _errorMessage;

  /// 当前输入的密钥字符串
  String? _currentKey;

  /// 是否勾选"保存此暗号到保险库"
  bool _savePassphrase = false;

  bool _usingVaultPassphrase = false;

  /// 是否为协商密钥模式
  bool get _isNegotiatedMode => widget.strawFile.content.kdfAlgorithm != null;

  @override
  void dispose() {
    _cancellationToken?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    if (!_isLoading) {
      Navigator.pop(context);
      return;
    }
    if (_isCancelling) return;
    _isCancelling = true;
    _cancellationToken?.cancel();
    Navigator.pop(context);
  }

  /// 处理密钥变化回调（来自 KeyInput 组件）
  void _onKeyChanged(String? key) {
    setState(() {
      _currentKey = key;
    });
  }

  /// 处理密钥文件加载回调（来自 KeyFileUpload 组件）
  ///
  /// 从 .key 文件解析到密钥后，自动填充到 KeyInput 文本框中。
  void _onKeyFileLoaded(String keyBase64) {
    setState(() {
      _currentKey = keyBase64;
      _errorMessage = null;
    });
    // 将解析到的密钥自动填充到 KeyInput 组件
    _keyInputKey.currentState?.setKey(keyBase64);
  }

  /// 执行解密操作并校验完整性
  ///
  /// 统一封装解密+完整性校验逻辑。
  /// 对于大文件（originalPayloadSize > 10MB）且有文件路径时，使用流式解密避免 OOM。
  /// 当 chunks 为空（流式头部加载）且文件路径可用时，必须使用流式解密。
  /// 返回解密成功的结果或 null（如果完整性校验失败）。
  Future<DecryptResult?> _performDecryptAndVerify(
    Uint8List keyBytes,
    CancellationToken cancellationToken,
  ) async {
    final cryptoService = ref.read(cryptoServiceProvider);
    final integrityService = ref.read(integrityServiceProvider);

    // 判断是否使用流式解密
    // 条件1：有文件路径（可以流式读取）
    // 条件2：分块数据为空（流式加载的头部）或文件较大（>10MB）
    const streamThreshold = 10 * 1024 * 1024; // 10MB
    final isRawStrawPath =
        widget.strawFilePath?.toLowerCase().endsWith('.straw') ?? false;
    final useStream = isRawStrawPath &&
        (widget.parsedFile.chunks.isEmpty ||
            widget.strawFile.content.originalPayloadSize > streamThreshold);

    DecryptResult decryptResult;

    if (useStream) {
      // ========== 流式解密：直接写入临时文件，避免 OOM ==========
      final tempDir = await TempFileManager.getTempDirectory();
      final tempPath =
          '$tempDir${Platform.pathSeparator}decrypt_temp_${DateTime.now().millisecondsSinceEpoch}';

      final streamResult = await cryptoService.decryptStream(
        strawFilePath: widget.strawFilePath!,
        key: keyBytes,
        targetPath: tempPath,
        chunkSize: widget.strawFile.content.chunkSize,
        originalPayloadSize: widget.strawFile.content.originalPayloadSize,
        cancellationToken: cancellationToken,
        onProgress: (current, total) {
          if (mounted && total > 0) {
            setState(() {
              _decryptProgress = 0.05 + (current / total) * 0.85;
            });
          }
        },
      );

      decryptResult = DecryptResult(
        payloadMetadata: streamResult.payloadMetadata,
        payloadBytes: Uint8List(0), // 流式解密不返回内存数据
        decryptedFilePath: tempPath,
      );
    } else {
      // ========== 内存解密 ==========
      decryptResult = await cryptoService.decrypt(
        chunks: widget.parsedFile.chunks,
        key: keyBytes,
        chunkSize: widget.strawFile.content.chunkSize,
        originalPayloadSize: widget.strawFile.content.originalPayloadSize,
        cancellationToken: cancellationToken,
        onProgress: (current, total) {
          if (mounted && total > 0) {
            setState(() {
              _decryptProgress = 0.05 + (current / total) * 0.85;
            });
          }
        },
      );
    }

    // ========== 完整性校验 ==========
    final strawFileForHash = StrawFile(
      formatVersion: widget.strawFile.formatVersion,
      meta: widget.strawFile.meta,
      content: widget.strawFile.content,
      integrity: IntegrityInfo(
        hash: '',
        hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
      ),
    );

    String computedHash;
    try {
      if (useStream) {
        computedHash = await integrityService.computeHashFromStrawFile(
          strawFile: strawFileForHash,
          filePath: widget.strawFilePath!,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (mounted && total > 0) {
              setState(() {
                _decryptProgress = 0.9 + (current / total) * 0.09;
              });
            }
          },
        );
      } else {
        computedHash = await integrityService.computeHashFromChunks(
          strawFile: strawFileForHash,
          chunks: widget.parsedFile.chunks,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (mounted && total > 0) {
              setState(() {
                _decryptProgress = 0.9 + (current / total) * 0.09;
              });
            }
          },
        );
      }
      cancellationToken.throwIfCancelled();
    } on Exception {
      if (decryptResult.decryptedFilePath != null) {
        await TempFileManager.deleteTempFile(decryptResult.decryptedFilePath!);
      }
      rethrow;
    }

    final isIntegrityValid = computedHash == widget.strawFile.integrity.hash;

    if (!isIntegrityValid) {
      // 清理临时文件
      if (decryptResult.decryptedFilePath != null) {
        await TempFileManager.deleteTempFile(decryptResult.decryptedFilePath!);
      }
      // 清理敏感数据
      MemoryUtils.wipeBytes(keyBytes);
      cryptoService.clearSensitiveData();
      return null; // 完整性校验失败
    }

    return decryptResult;
  }

  /// 处理解密流程
  ///
  /// 完整的解密流程：
  /// 1. 根据加密模式获取密钥/暗号
  /// 2. 将密钥解码或从暗号派生密钥
  /// 3. 调用 CryptoService.decrypt() 解密（新接口）
  /// 4. 调用 IntegrityService.verifyIntegrity() 校验完整性
  /// 5. 解密成功 → 清理敏感数据 → 关闭对话框 → 调用成功回调（传入 DecryptResult）
  /// 6. 解密失败 → 显示错误提示
  Future<void> _handleDecrypt() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isNegotiatedMode) {
      // 协商密钥模式：验证暗号是否已输入
      final passphrase = _passphraseInputKey.currentState?.passphrase;
      final selectedEntryId = _passphraseInputKey.currentState?.selectedEntryId;
      if (passphrase == null || passphrase.isEmpty) {
        setState(() {
          _errorMessage = l10n.decryptPassphraseRequired;
        });
        return;
      }

      final cancellationToken = CancellationToken();
      _cancellationToken = cancellationToken;
      setState(() {
        _isLoading = true;
        _isCancelling = false;
        _decryptProgress = 0.0;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        // ========== 步骤 1：获取服务实例 ==========
        final cryptoService = ref.read(cryptoServiceProvider);

        // ========== 步骤 2：从暗号派生密钥 ==========
        // 读取 salt 和 kdfIterations
        final saltBase64 = widget.strawFile.content.saltBase64;
        final kdfIterations = widget.strawFile.content.kdfIterations;

        if (saltBase64 == null || kdfIterations == null) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        final Uint8List salt;
        try {
          salt = base64Decode(saltBase64);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        // 使用 PBKDF2 从暗号派生密钥
        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
          iterations: kdfIterations,
          cancellationToken: cancellationToken,
        );

        // ========== 步骤 3：执行解密 + 完整性校验 ==========
        final decryptResult = await _performDecryptAndVerify(
          keyBytes,
          cancellationToken,
        );

        if (decryptResult == null) {
          // 完整性校验失败
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.integrityError;
          });
          return;
        }

        // ========== 步骤 4：解密成功，清理敏感数据 ==========
        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        if (selectedEntryId != null) {
          try {
            await ref
                .read(passphraseVaultServiceProvider)
                .markUsed(selectedEntryId);
            ref.invalidate(passphraseEntriesProvider);
          } on Exception {
            // Usage statistics must not turn a successful decrypt into a
            // failure if secure storage is temporarily unavailable.
          }
        }

        // 清除暗号输入框中的敏感内容
        _passphraseInputKey.currentState?.clear();

        // 如果用户勾选了"保存此暗号"，弹出保存对话框
        if (_savePassphrase && mounted) {
          cancellationToken.throwIfCancelled();
          final saved = await AddPassphraseDialog.show(
            context,
            initialPassphrase: passphrase,
          );
          if (saved == true) {
            ref.invalidate(passphraseEntriesProvider);
          }
        }

        // 调用成功回调，传入 DecryptResult
        cancellationToken.throwIfCancelled();
        if (mounted) {
          widget.onDecryptSuccess(decryptResult);
          // 关闭对话框
          Navigator.pop(context);
        }
      } on OperationCancelledException {
        if (mounted && !_isCancelling) {
          Navigator.pop(context);
        }
      } on CryptoException {
        if (!mounted || cancellationToken.isCancelled) return;
        // 加密服务抛出的异常（暗号错误、解密失败等）
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = l10n.passphraseDecryptFailed;
        });
      } on Exception catch (e) {
        if (!mounted || cancellationToken.isCancelled) return;
        // 其他已知异常
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        // 确保密钥字节被清理（即使发生异常）
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
        if (identical(_cancellationToken, cancellationToken)) {
          _cancellationToken = null;
        }
      }
    } else {
      // 随机密钥模式：使用 Base64 密钥解密
      // 验证是否已输入密钥
      if (_currentKey == null || _currentKey!.isEmpty) {
        setState(() {
          _errorMessage = '请输入密钥或上传 .key 文件';
        });
        return;
      }

      final cancellationToken = CancellationToken();
      _cancellationToken = cancellationToken;
      setState(() {
        _isLoading = true;
        _isCancelling = false;
        _decryptProgress = 0.0;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        // ========== 步骤 1：获取服务实例 ==========
        final cryptoService = ref.read(cryptoServiceProvider);

        // ========== 步骤 2：将 Base64 密钥解码为字节数组 ==========
        final Uint8List decodedKey;
        try {
          decodedKey = base64Decode(_currentKey!);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = '密钥格式不正确，无法解析为有效的 Base64 数据';
          });
          return;
        }

        // 验证密钥长度是否为 32 字节
        if (decodedKey.length != KEY_LENGTH_BYTES) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = '密钥长度不正确：期望 $KEY_LENGTH_BYTES '
                '字节，实际 ${decodedKey.length} 字节';
          });
          MemoryUtils.wipeBytes(decodedKey);
          return;
        }

        keyBytes = decodedKey;

        // ========== 步骤 3：执行解密 + 完整性校验 ==========
        final decryptResult = await _performDecryptAndVerify(
          keyBytes,
          cancellationToken,
        );

        if (decryptResult == null) {
          // 完整性校验失败
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.integrityError;
          });
          return;
        }

        // ========== 步骤 4：解密成功，清理敏感数据 ==========
        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        // 清除密钥输入框中的敏感内容
        _keyInputKey.currentState?.clear();

        // 调用成功回调，传入 DecryptResult
        cancellationToken.throwIfCancelled();
        if (mounted) {
          widget.onDecryptSuccess(decryptResult);
          // 关闭对话框
          Navigator.pop(context);
        }
      } on OperationCancelledException {
        if (mounted && !_isCancelling) {
          Navigator.pop(context);
        }
      } on CryptoException {
        if (!mounted || cancellationToken.isCancelled) return;
        // 加密服务抛出的异常（密钥错误、解密失败等）
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = l10n.keyError;
        });
      } on Exception catch (e) {
        if (!mounted || cancellationToken.isCancelled) return;
        // 其他已知异常
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        // 确保密钥字节被清理（即使发生异常）
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
        if (identical(_cancellationToken, cancellationToken)) {
          _cancellationToken = null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final meta = widget.strawFile.meta;

    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isLoading) _handleCancel();
      },
      child: Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 标题
                Row(
                  children: [
                    NeumorphicIcon(
                      StrawIcons.unlock,
                      size: 22,
                      color: tokens.inkPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.decrypt,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ========== 卡片元数据预览 ==========
                        _buildMetaPreview(meta),
                        Divider(
                          height: tokens.spaceLg,
                          color: tokens.divider,
                        ),

                        // ========== 根据加密模式显示不同输入区域 ==========
                        if (_isNegotiatedMode) ...[
                          // 协商密钥模式：显示暗号输入
                          PassphraseDecryptInput(
                            key: _passphraseInputKey,
                            enabled: !_isLoading,
                            onVaultSelectionChanged: (selected) {
                              setState(() {
                                _usingVaultPassphrase = selected;
                                if (selected) _savePassphrase = false;
                              });
                            },
                          ),
                          if (!_usingVaultPassphrase) ...[
                            SizedBox(height: tokens.spaceSm),
                            // 保存暗号到保险库复选框
                            CheckboxListTile(
                              value: _savePassphrase,
                              onChanged: _isLoading
                                  ? null
                                  : (value) {
                                      setState(() {
                                        _savePassphrase = value ?? false;
                                      });
                                    },
                              title: Text(
                                l10n.saveAfterDecrypt,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: tokens.textSecondary,
                                ),
                              ),
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              dense: true,
                              activeColor: tokens.inkPrimary,
                              checkColor: tokens.surface,
                            ),
                          ],
                        ] else ...[
                          // 随机密钥模式：显示密钥输入和文件上传
                          // ========== 方式 A：手动输入密钥 ==========
                          KeyInput(
                            key: _keyInputKey,
                            onKeyChanged: _onKeyChanged,
                          ),
                          SizedBox(height: tokens.spaceMd),

                          // ========== 方式 B：上传 .key 文件 ==========
                          KeyFileUpload(onKeyFileLoaded: _onKeyFileLoaded),
                        ],

                        // ========== 错误提示 ==========
                        if (_errorMessage != null) ...[
                          SizedBox(height: tokens.spaceSm + tokens.spaceXs),
                          NeumorphicContainer(
                            shape: NeumorphicShape.concave,
                            borderRadius: tokens.radiusSmall,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                NeumorphicIcon(
                                  StrawIcons.error,
                                  size: 18,
                                  color: tokens.error,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: TextStyle(
                                      color: tokens.error,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                SizedBox(height: tokens.spaceMd),
                // 操作按钮
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      key: const ValueKey('decrypt_cancel_button'),
                      label: l10n.cancel,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: _isCancelling ? null : _handleCancel,
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: _isLoading
                          ? (_isCancelling
                              ? '${l10n.cancel}...'
                              : _decryptProgress > 0
                                  ? '${(_decryptProgress * 100).toInt()}%'
                                  : '解密中...')
                          : l10n.decrypt,
                      style: NeumorphicButtonStyle.primary,
                      icon: _isLoading ? null : StrawIcons.unlock,
                      onPressed: _isLoading ? null : _handleDecrypt,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 构建元数据预览区域
  ///
  /// 展示 .straw 文件的公开元数据，帮助用户确认要解密的文件是否正确。
  /// 展示内容包括：标题、发布者、发布日期、描述、标签、匿名标识。
  Widget _buildMetaPreview(CardMeta meta) {
    final tokens = NeumorphicTokens.ofContext(context);
    return NeumorphicContainer(
      shape: NeumorphicShape.concave,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            meta.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spaceSm),

          // 发布者信息行
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // 匿名标识
              if (meta.isAnonymous)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '匿名',
                    style: TextStyle(
                      color: tokens.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // 发布者代号
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeumorphicIcon(
                    StrawIcons.globe,
                    size: 16,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      meta.publisherAlias,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              // 发布日期
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeumorphicIcon(
                    StrawIcons.document,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(meta.publishDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 描述（如果有）
          if (meta.description != null && meta.description!.isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Text(
              meta.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
          ],

          // 标签列表
          if (meta.tags.isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: meta.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.inkWash.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.inkSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  /// 格式化 ISO 8601 日期字符串为可读格式
  ///
  /// 将 "2026-05-01T12:00:00Z" 格式化为 "2026-05-01"。
  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } on Exception {
      return isoDate;
    }
  }
}

/// Mobile bottom sheet version of the Decrypt Dialog for Android.
///
/// Uses DraggableScrollableSheet inside a showModalBottomSheet, providing:
/// - Draggable bottom sheet that can expand up to 95% of screen height
/// - Scrollable content area
/// - Minimum 48dp touch targets
/// - Keyboard-aware layout
class _DecryptDialogMobile extends ConsumerStatefulWidget {
  const _DecryptDialogMobile({
    required this.scrollController,
    required this.strawFile,
    required this.parsedFile,
    required this.onDecryptSuccess,
    this.strawFilePath,
  });

  final ScrollController scrollController;
  final StrawFile strawFile;
  final ParsedStrawFile parsedFile;
  final void Function(DecryptResult result) onDecryptSuccess;
  final String? strawFilePath;

  @override
  ConsumerState<_DecryptDialogMobile> createState() =>
      _DecryptDialogMobileState();
}

class _DecryptDialogMobileState extends ConsumerState<_DecryptDialogMobile> {
  final _keyInputKey = GlobalKey<KeyInputState>();
  final _passphraseInputKey = GlobalKey<PassphraseDecryptInputState>();

  bool _isLoading = false;
  bool _isCancelling = false;
  double _decryptProgress = 0.0;
  String? _errorMessage;
  String? _currentKey;
  bool _savePassphrase = false;
  bool _usingVaultPassphrase = false;
  CancellationToken? _cancellationToken;

  bool get _isNegotiatedMode => widget.strawFile.content.kdfAlgorithm != null;

  @override
  void dispose() {
    _cancellationToken?.cancel();
    super.dispose();
  }

  void _handleCancel() {
    if (!_isLoading) {
      Navigator.pop(context);
      return;
    }
    if (_isCancelling) return;
    _isCancelling = true;
    _cancellationToken?.cancel();
    Navigator.pop(context);
  }

  void _onKeyChanged(String? key) {
    setState(() {
      _currentKey = key;
    });
  }

  void _onKeyFileLoaded(String keyBase64) {
    setState(() {
      _currentKey = keyBase64;
      _errorMessage = null;
    });
    _keyInputKey.currentState?.setKey(keyBase64);
  }

  /// 执行解密操作并校验完整性
  ///
  /// 对于大文件（originalPayloadSize > 10MB）且有文件路径时，使用流式解密避免 OOM。
  /// 当 chunks 为空（流式头部加载）且文件路径可用时，必须使用流式解密。
  Future<DecryptResult?> _performDecryptAndVerify(
    Uint8List keyBytes,
    CancellationToken cancellationToken,
  ) async {
    final cryptoService = ref.read(cryptoServiceProvider);
    final integrityService = ref.read(integrityServiceProvider);

    // 判断是否使用流式解密
    // 条件1：有文件路径（可以流式读取）
    // 条件2：分块数据为空（流式加载的头部）或文件较大（>10MB）
    const streamThreshold = 10 * 1024 * 1024; // 10MB
    final isRawStrawPath =
        widget.strawFilePath?.toLowerCase().endsWith('.straw') ?? false;
    final useStream = isRawStrawPath &&
        (widget.parsedFile.chunks.isEmpty ||
            widget.strawFile.content.originalPayloadSize > streamThreshold);

    DecryptResult decryptResult;

    if (useStream) {
      // ========== 流式解密：直接写入临时文件，避免 OOM ==========
      final tempDir = await TempFileManager.getTempDirectory();
      final tempPath =
          '$tempDir${Platform.pathSeparator}decrypt_temp_${DateTime.now().millisecondsSinceEpoch}';

      final streamResult = await cryptoService.decryptStream(
        strawFilePath: widget.strawFilePath!,
        key: keyBytes,
        targetPath: tempPath,
        chunkSize: widget.strawFile.content.chunkSize,
        originalPayloadSize: widget.strawFile.content.originalPayloadSize,
        cancellationToken: cancellationToken,
        onProgress: (current, total) {
          if (mounted && total > 0) {
            setState(() {
              _decryptProgress = 0.05 + (current / total) * 0.85;
            });
          }
        },
      );

      decryptResult = DecryptResult(
        payloadMetadata: streamResult.payloadMetadata,
        payloadBytes: Uint8List(0), // 流式解密不返回内存数据
        decryptedFilePath: tempPath,
      );
    } else {
      // ========== 内存解密 ==========
      decryptResult = await cryptoService.decrypt(
        chunks: widget.parsedFile.chunks,
        key: keyBytes,
        chunkSize: widget.strawFile.content.chunkSize,
        originalPayloadSize: widget.strawFile.content.originalPayloadSize,
        cancellationToken: cancellationToken,
        onProgress: (current, total) {
          if (mounted && total > 0) {
            setState(() {
              _decryptProgress = 0.05 + (current / total) * 0.85;
            });
          }
        },
      );
    }

    // ========== 完整性校验 ==========
    final strawFileForHash = StrawFile(
      formatVersion: widget.strawFile.formatVersion,
      meta: widget.strawFile.meta,
      content: widget.strawFile.content,
      integrity: IntegrityInfo(
        hash: '',
        hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
      ),
    );

    String computedHash;
    try {
      if (useStream) {
        computedHash = await integrityService.computeHashFromStrawFile(
          strawFile: strawFileForHash,
          filePath: widget.strawFilePath!,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (mounted && total > 0) {
              setState(() {
                _decryptProgress = 0.9 + (current / total) * 0.09;
              });
            }
          },
        );
      } else {
        computedHash = await integrityService.computeHashFromChunks(
          strawFile: strawFileForHash,
          chunks: widget.parsedFile.chunks,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (mounted && total > 0) {
              setState(() {
                _decryptProgress = 0.9 + (current / total) * 0.09;
              });
            }
          },
        );
      }
      cancellationToken.throwIfCancelled();
    } on Exception {
      if (decryptResult.decryptedFilePath != null) {
        await TempFileManager.deleteTempFile(decryptResult.decryptedFilePath!);
      }
      rethrow;
    }

    final isIntegrityValid = computedHash == widget.strawFile.integrity.hash;

    if (!isIntegrityValid) {
      // 清理临时文件
      if (decryptResult.decryptedFilePath != null) {
        await TempFileManager.deleteTempFile(decryptResult.decryptedFilePath!);
      }
      MemoryUtils.wipeBytes(keyBytes);
      cryptoService.clearSensitiveData();
      return null;
    }

    return decryptResult;
  }

  Future<void> _handleDecrypt() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isNegotiatedMode) {
      final passphrase = _passphraseInputKey.currentState?.passphrase;
      final selectedEntryId = _passphraseInputKey.currentState?.selectedEntryId;
      if (passphrase == null || passphrase.isEmpty) {
        setState(() {
          _errorMessage = l10n.decryptPassphraseRequired;
        });
        return;
      }

      final cancellationToken = CancellationToken();
      _cancellationToken = cancellationToken;
      setState(() {
        _isLoading = true;
        _isCancelling = false;
        _decryptProgress = 0.0;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        final cryptoService = ref.read(cryptoServiceProvider);

        final saltBase64 = widget.strawFile.content.saltBase64;
        final kdfIterations = widget.strawFile.content.kdfIterations;

        if (saltBase64 == null || kdfIterations == null) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        final Uint8List salt;
        try {
          salt = base64Decode(saltBase64);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
          iterations: kdfIterations,
          cancellationToken: cancellationToken,
        );

        final decryptResult = await _performDecryptAndVerify(
          keyBytes,
          cancellationToken,
        );

        if (decryptResult == null) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.integrityError;
          });
          return;
        }

        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        if (selectedEntryId != null) {
          try {
            await ref
                .read(passphraseVaultServiceProvider)
                .markUsed(selectedEntryId);
            ref.invalidate(passphraseEntriesProvider);
          } on Exception {
            // A statistics write must not invalidate successful decryption.
          }
        }

        _passphraseInputKey.currentState?.clear();

        // 如果用户勾选了"保存此暗号"，弹出保存对话框
        if (_savePassphrase && mounted) {
          cancellationToken.throwIfCancelled();
          final saved = await AddPassphraseDialog.show(
            context,
            initialPassphrase: passphrase,
          );
          if (saved == true) {
            ref.invalidate(passphraseEntriesProvider);
          }
        }

        cancellationToken.throwIfCancelled();
        if (mounted) {
          widget.onDecryptSuccess(decryptResult);
          Navigator.pop(context);
        }
      } on OperationCancelledException {
        if (mounted && !_isCancelling) {
          Navigator.pop(context);
        }
      } on CryptoException {
        if (!mounted || cancellationToken.isCancelled) return;
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = l10n.passphraseDecryptFailed;
        });
      } on Exception catch (e) {
        if (!mounted || cancellationToken.isCancelled) return;
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
        if (identical(_cancellationToken, cancellationToken)) {
          _cancellationToken = null;
        }
      }
    } else {
      if (_currentKey == null || _currentKey!.isEmpty) {
        setState(() {
          _errorMessage = '请输入密钥或上传 .key 文件';
        });
        return;
      }

      final cancellationToken = CancellationToken();
      _cancellationToken = cancellationToken;
      setState(() {
        _isLoading = true;
        _isCancelling = false;
        _decryptProgress = 0.0;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        final cryptoService = ref.read(cryptoServiceProvider);

        final Uint8List decodedKey;
        try {
          decodedKey = base64Decode(_currentKey!);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = '密钥格式不正确，无法解析为有效的 Base64 数据';
          });
          return;
        }

        if (decodedKey.length != KEY_LENGTH_BYTES) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = '密钥长度不正确：期望 $KEY_LENGTH_BYTES '
                '字节，实际 ${decodedKey.length} 字节';
          });
          MemoryUtils.wipeBytes(decodedKey);
          return;
        }

        keyBytes = decodedKey;

        final decryptResult = await _performDecryptAndVerify(
          keyBytes,
          cancellationToken,
        );

        if (decryptResult == null) {
          setState(() {
            _isLoading = false;
            _decryptProgress = 0.0;
            _errorMessage = l10n.integrityError;
          });
          return;
        }

        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        _keyInputKey.currentState?.clear();

        cancellationToken.throwIfCancelled();
        if (mounted) {
          widget.onDecryptSuccess(decryptResult);
          Navigator.pop(context);
        }
      } on OperationCancelledException {
        if (mounted && !_isCancelling) {
          Navigator.pop(context);
        }
      } on CryptoException {
        if (!mounted || cancellationToken.isCancelled) return;
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = l10n.keyError;
        });
      } on Exception catch (e) {
        if (!mounted || cancellationToken.isCancelled) return;
        setState(() {
          _isLoading = false;
          _decryptProgress = 0.0;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
        if (identical(_cancellationToken, cancellationToken)) {
          _cancellationToken = null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final meta = widget.strawFile.meta;

    return PopScope(
      canPop: !_isLoading,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isLoading) _handleCancel();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Drag handle indicator
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: tokens.surfaceAlt,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // 标题
            Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.unlock,
                  size: 22,
                  color: tokens.inkPrimary,
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    l10n.decrypt,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: tokens.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: tokens.spaceSm + tokens.spaceXs),
            // Scrollable content
            Flexible(
              child: SingleChildScrollView(
                controller: widget.scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Meta preview
                    _buildMetaPreview(meta),
                    Divider(
                      height: tokens.spaceLg,
                      color: tokens.divider,
                    ),

                    // Input area based on encryption mode
                    if (_isNegotiatedMode) ...[
                      PassphraseDecryptInput(
                        key: _passphraseInputKey,
                        enabled: !_isLoading,
                        onVaultSelectionChanged: (selected) {
                          setState(() {
                            _usingVaultPassphrase = selected;
                            if (selected) _savePassphrase = false;
                          });
                        },
                      ),
                      if (!_usingVaultPassphrase) ...[
                        SizedBox(height: tokens.spaceSm),
                        // 保存暗号到保险库复选框
                        CheckboxListTile(
                          value: _savePassphrase,
                          onChanged: _isLoading
                              ? null
                              : (value) {
                                  setState(() {
                                    _savePassphrase = value ?? false;
                                  });
                                },
                          title: Text(
                            l10n.saveAfterDecrypt,
                            style: TextStyle(
                              fontSize: 13,
                              color: tokens.textSecondary,
                            ),
                          ),
                          contentPadding: EdgeInsets.zero,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                          activeColor: tokens.inkPrimary,
                          checkColor: tokens.surface,
                        ),
                      ],
                    ] else ...[
                      KeyInput(key: _keyInputKey, onKeyChanged: _onKeyChanged),
                      SizedBox(height: tokens.spaceMd),
                      KeyFileUpload(onKeyFileLoaded: _onKeyFileLoaded),
                    ],

                    // Error message
                    if (_errorMessage != null) ...[
                      SizedBox(height: tokens.spaceSm + tokens.spaceXs),
                      NeumorphicContainer(
                        shape: NeumorphicShape.concave,
                        borderRadius: tokens.radiusSmall,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            NeumorphicIcon(
                              StrawIcons.error,
                              size: 18,
                              color: tokens.error,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage!,
                                style: TextStyle(
                                  color: tokens.error,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    SizedBox(height: tokens.spaceMd),
                  ],
                ),
              ),
            ),
            // Fixed bottom action bar
            Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    key: const ValueKey('decrypt_cancel_button'),
                    label: l10n.cancel,
                    style: NeumorphicButtonStyle.flat,
                    onPressed: _isCancelling ? null : _handleCancel,
                  ),
                  const SizedBox(width: 8),
                  NeumorphicButton(
                    label: _isLoading
                        ? (_isCancelling
                            ? '${l10n.cancel}...'
                            : _decryptProgress > 0
                                ? '${(_decryptProgress * 100).toInt()}%'
                                : '解密中...')
                        : l10n.decrypt,
                    style: NeumorphicButtonStyle.primary,
                    icon: _isLoading ? null : StrawIcons.unlock,
                    onPressed: _isLoading ? null : _handleDecrypt,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaPreview(CardMeta meta) {
    final tokens = NeumorphicTokens.ofContext(context);
    return NeumorphicContainer(
      shape: NeumorphicShape.concave,
      borderRadius: tokens.radiusSmall,
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meta.title,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (meta.isAnonymous)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.warning.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '匿名',
                    style: TextStyle(
                      color: tokens.warning,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeumorphicIcon(
                    StrawIcons.globe,
                    size: 16,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      meta.publisherAlias,
                      style: TextStyle(
                        fontSize: 13,
                        color: tokens.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NeumorphicIcon(
                    StrawIcons.document,
                    size: 14,
                    color: tokens.textSecondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(meta.publishDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (meta.description != null && meta.description!.isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Text(
              meta.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: tokens.textSecondary,
              ),
            ),
          ],
          if (meta.tags.isNotEmpty) ...[
            SizedBox(height: tokens.spaceSm),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: meta.tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tokens.inkWash.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: tokens.inkSecondary,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dateTime = DateTime.parse(isoDate).toLocal();
      return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')}';
    } on Exception {
      return isoDate;
    }
  }
}
