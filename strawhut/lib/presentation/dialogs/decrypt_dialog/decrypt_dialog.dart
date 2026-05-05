import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/utils/memory_utils.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_file_upload.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_input.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/passphrase_decrypt_input.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

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
/// 4. 调用 CryptoService.decryptContent() 解密
/// 5. 调用 IntegrityService.verifyIntegrity() 校验完整性
/// 6. 解密成功 → 关闭对话框，调用 onDecryptSuccess 回调
/// 7. 解密失败 → 显示错误提示
///
/// 使用示例：
/// ```dart
/// await DecryptDialog.show(
///   context,
///   strawFile: strawFile,
///   onDecryptSuccess: (deltaJson) {
///     // 处理解密后的 Delta JSON
///     Navigator.push(context, ...);
///   },
/// );
/// ```
class DecryptDialog extends ConsumerStatefulWidget {
  /// 创建解密对话框实例
  ///
  /// 参数：
  /// - [strawFile] - 要解密的 .straw 文件对象，必填
  /// - [onDecryptSuccess] - 解密成功后的回调函数，
  ///   参数为解密后的 Delta JSON 字符串
  const DecryptDialog({
    super.key,
    required this.strawFile,
    required this.onDecryptSuccess,
  });

  /// 要解密的 .straw 文件对象
  final StrawFile strawFile;

  /// 解密成功回调
  ///
  /// 解密和完整性校验全部通过后触发。
  /// 参数为解密后的 Delta JSON 字符串，可用于渲染富文本内容。
  final void Function(String deltaJson) onDecryptSuccess;

  /// 弹出解密对话框
  ///
  /// 便捷静态方法，简化对话框的弹出调用。
  ///
  /// 参数：
  /// - [context] - BuildContext 对象
  /// - [strawFile] - 要解密的 .straw 文件对象
  /// - [onDecryptSuccess] - 解密成功后的回调函数
  static Future<void> show(
    BuildContext context, {
    required StrawFile strawFile,
    required void Function(String deltaJson) onDecryptSuccess,
  }) {
    // On Android, use bottom sheet for better mobile UX
    if (defaultTargetPlatform == TargetPlatform.android) {
      return showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
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
            onDecryptSuccess: onDecryptSuccess,
          ),
        ),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => DecryptDialog(
        strawFile: strawFile,
        onDecryptSuccess: onDecryptSuccess,
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

  /// 错误消息
  String? _errorMessage;

  /// 当前输入的密钥字符串
  String? _currentKey;

  /// 是否为协商密钥模式
  bool get _isNegotiatedMode => widget.strawFile.content.kdfAlgorithm != null;

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

  /// 处理解密流程
  ///
  /// 完整的解密流程：
  /// 1. 根据加密模式获取密钥/暗号
  /// 2. 将密钥解码或从暗号派生密钥
  /// 3. 调用 CryptoService.decryptContent() 解密
  /// 4. 调用 IntegrityService.verifyIntegrity() 校验完整性
  /// 5. 解密成功 → 清理敏感数据 → 关闭对话框 → 调用成功回调
  /// 6. 解密失败 → 显示错误提示
  Future<void> _handleDecrypt() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isNegotiatedMode) {
      // 协商密钥模式：验证暗号是否已输入
      final passphrase = _passphraseInputKey.currentState?.passphrase;
      if (passphrase == null || passphrase.isEmpty) {
        setState(() {
          _errorMessage = l10n.decryptPassphraseLabel;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        // ========== 步骤 1：获取服务实例 ==========
        final cryptoService = ref.read(cryptoServiceProvider);
        final integrityService = ref.read(integrityServiceProvider);

        // ========== 步骤 2：从暗号派生密钥 ==========
        // 读取 salt 和 kdfIterations
        final saltBase64 = widget.strawFile.content.saltBase64;
        final kdfIterations = widget.strawFile.content.kdfIterations;

        if (saltBase64 == null || kdfIterations == null) {
          setState(() {
            _isLoading = false;
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
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        // 使用 PBKDF2 从暗号派生密钥
        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
          iterations: kdfIterations,
        );

        // ========== 步骤 3：调用 CryptoService.decryptContent() 解密 ==========
        final deltaJson = await cryptoService.decryptContent(
          encryptedDataBase64: widget.strawFile.content.encryptedDataBase64,
          ivBase64: widget.strawFile.content.ivBase64,
          key: keyBytes,
        );

        // ========== 步骤 4：调用 IntegrityService.verifyIntegrity() 校验 ==========
        final strawFileForHash = StrawFile(
          formatVersion: widget.strawFile.formatVersion,
          meta: widget.strawFile.meta,
          content: widget.strawFile.content,
          integrity: IntegrityInfo(
            hash: '',
            hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
          ),
        );
        final strawFileJson = strawFileForHash.assembleToJson();
        final isIntegrityValid = integrityService.verifyIntegrity(
          content: strawFileJson,
          expectedHash: widget.strawFile.integrity.hash,
        );

        if (!isIntegrityValid) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.integrityError;
          });
          MemoryUtils.wipeBytes(keyBytes);
          cryptoService.clearSensitiveData();
          return;
        }

        // ========== 步骤 5：解密成功，清理敏感数据 ==========
        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        // 清除暗号输入框中的敏感内容
        _passphraseInputKey.currentState?.clear();

        // 调用成功回调，传入解密后的 Delta JSON
        if (mounted) {
          widget.onDecryptSuccess(deltaJson);
          // 关闭对话框
          Navigator.pop(context);
        }
      } on CryptoException {
        // 加密服务抛出的异常（暗号错误、解密失败等）
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.passphraseDecryptFailed;
        });
      } on Exception catch (e) {
        // 其他已知异常
        setState(() {
          _isLoading = false;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        // 确保密钥字节被清理（即使发生异常）
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
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

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        // ========== 步骤 1：获取服务实例 ==========
        final cryptoService = ref.read(cryptoServiceProvider);
        final integrityService = ref.read(integrityServiceProvider);

        // ========== 步骤 2：将 Base64 密钥解码为字节数组 ==========
        final Uint8List decodedKey;
        try {
          decodedKey = base64Decode(_currentKey!);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _errorMessage = '密钥格式不正确，无法解析为有效的 Base64 数据';
          });
          return;
        }

        // 验证密钥长度是否为 32 字节
        if (decodedKey.length != KEY_LENGTH_BYTES) {
          setState(() {
            _isLoading = false;
            _errorMessage = '密钥长度不正确：期望 $KEY_LENGTH_BYTES '
                '字节，实际 ${decodedKey.length} 字节';
          });
          MemoryUtils.wipeBytes(decodedKey);
          return;
        }

        keyBytes = decodedKey;

        // ========== 步骤 3：调用 CryptoService.decryptContent() 解密 ==========
        final deltaJson = await cryptoService.decryptContent(
          encryptedDataBase64: widget.strawFile.content.encryptedDataBase64,
          ivBase64: widget.strawFile.content.ivBase64,
          key: keyBytes,
        );

        // ========== 步骤 4：调用 IntegrityService.verifyIntegrity() 校验 ==========
        final strawFileForHash = StrawFile(
          formatVersion: widget.strawFile.formatVersion,
          meta: widget.strawFile.meta,
          content: widget.strawFile.content,
          integrity: IntegrityInfo(
            hash: '',
            hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
          ),
        );
        final strawFileJson = strawFileForHash.assembleToJson();
        final isIntegrityValid = integrityService.verifyIntegrity(
          content: strawFileJson,
          expectedHash: widget.strawFile.integrity.hash,
        );

        if (!isIntegrityValid) {
          // 完整性校验失败，文件可能被篡改
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.integrityError;
          });
          // 清理敏感数据
          MemoryUtils.wipeBytes(keyBytes);
          cryptoService.clearSensitiveData();
          return;
        }

        // ========== 步骤 5：解密成功，清理敏感数据 ==========
        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        // 清除密钥输入框中的敏感内容
        _keyInputKey.currentState?.clear();

        // 调用成功回调，传入解密后的 Delta JSON
        if (mounted) {
          widget.onDecryptSuccess(deltaJson);
          // 关闭对话框
          Navigator.pop(context);
        }
      } on CryptoException {
        // 加密服务抛出的异常（密钥错误、解密失败等）
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.keyError;
        });
      } on Exception catch (e) {
        // 其他已知异常
        setState(() {
          _isLoading = false;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        // 确保密钥字节被清理（即使发生异常）
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = widget.strawFile.meta;

    return AlertDialog(
      title: Text(l10n.decrypt),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========== 卡片元数据预览 ==========
            _buildMetaPreview(meta),
            const Divider(height: 24),

            // ========== 根据加密模式显示不同输入区域 ==========
            if (_isNegotiatedMode) ...[
              // 协商密钥模式：显示暗号输入
              PassphraseDecryptInput(key: _passphraseInputKey),
            ] else ...[
              // 随机密钥模式：显示密钥输入和文件上传
              // ========== 方式 A：手动输入密钥 ==========
              KeyInput(key: _keyInputKey, onKeyChanged: _onKeyChanged),
              const SizedBox(height: 16),

              // ========== 方式 B：上传 .key 文件 ==========
              KeyFileUpload(onKeyFileLoaded: _onKeyFileLoaded),
            ],

            // ========== 错误提示 ==========
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        // 取消按钮：关闭对话框
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        // 解密按钮：触发解密流程
        FilledButton(
          onPressed: _isLoading ? null : _handleDecrypt,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.decrypt),
        ),
      ],
    );
  }

  /// 构建元数据预览区域
  ///
  /// 展示 .straw 文件的公开元数据，帮助用户确认要解密的文件是否正确。
  /// 展示内容包括：标题、发布者、发布日期、描述、标签、匿名标识。
  Widget _buildMetaPreview(CardMeta meta) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 标题
          Text(
            meta.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),

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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '匿名',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              // 发布者代号
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      meta.publisherAlias,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              // 发布日期
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(meta.publishDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),

          // 描述（如果有）
          if (meta.description != null && meta.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],

          // 标签列表
          if (meta.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
    required this.onDecryptSuccess,
  });

  final ScrollController scrollController;
  final StrawFile strawFile;
  final void Function(String deltaJson) onDecryptSuccess;

  @override
  ConsumerState<_DecryptDialogMobile> createState() =>
      _DecryptDialogMobileState();
}

class _DecryptDialogMobileState extends ConsumerState<_DecryptDialogMobile> {
  final _keyInputKey = GlobalKey<KeyInputState>();
  final _passphraseInputKey = GlobalKey<PassphraseDecryptInputState>();

  bool _isLoading = false;
  String? _errorMessage;
  String? _currentKey;

  bool get _isNegotiatedMode => widget.strawFile.content.kdfAlgorithm != null;

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

  Future<void> _handleDecrypt() async {
    final l10n = AppLocalizations.of(context)!;

    if (_isNegotiatedMode) {
      final passphrase = _passphraseInputKey.currentState?.passphrase;
      if (passphrase == null || passphrase.isEmpty) {
        setState(() {
          _errorMessage = l10n.decryptPassphraseLabel;
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        final cryptoService = ref.read(cryptoServiceProvider);
        final integrityService = ref.read(integrityServiceProvider);

        final saltBase64 = widget.strawFile.content.saltBase64;
        final kdfIterations = widget.strawFile.content.kdfIterations;

        if (saltBase64 == null || kdfIterations == null) {
          setState(() {
            _isLoading = false;
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
            _errorMessage = l10n.passphraseDecryptFailed;
          });
          return;
        }

        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
          iterations: kdfIterations,
        );

        final deltaJson = await cryptoService.decryptContent(
          encryptedDataBase64: widget.strawFile.content.encryptedDataBase64,
          ivBase64: widget.strawFile.content.ivBase64,
          key: keyBytes,
        );

        final strawFileForHash = StrawFile(
          formatVersion: widget.strawFile.formatVersion,
          meta: widget.strawFile.meta,
          content: widget.strawFile.content,
          integrity: IntegrityInfo(
            hash: '',
            hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
          ),
        );
        final strawFileJson = strawFileForHash.assembleToJson();
        final isIntegrityValid = integrityService.verifyIntegrity(
          content: strawFileJson,
          expectedHash: widget.strawFile.integrity.hash,
        );

        if (!isIntegrityValid) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.integrityError;
          });
          MemoryUtils.wipeBytes(keyBytes);
          cryptoService.clearSensitiveData();
          return;
        }

        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        _passphraseInputKey.currentState?.clear();

        if (mounted) {
          widget.onDecryptSuccess(deltaJson);
          Navigator.pop(context);
        }
      } on CryptoException {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.passphraseDecryptFailed;
        });
      } on Exception catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
      }
    } else {
      if (_currentKey == null || _currentKey!.isEmpty) {
        setState(() {
          _errorMessage = '请输入密钥或上传 .key 文件';
        });
        return;
      }

      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      Uint8List? keyBytes;
      try {
        final cryptoService = ref.read(cryptoServiceProvider);
        final integrityService = ref.read(integrityServiceProvider);

        final Uint8List decodedKey;
        try {
          decodedKey = base64Decode(_currentKey!);
        } on FormatException {
          setState(() {
            _isLoading = false;
            _errorMessage = '密钥格式不正确，无法解析为有效的 Base64 数据';
          });
          return;
        }

        if (decodedKey.length != KEY_LENGTH_BYTES) {
          setState(() {
            _isLoading = false;
            _errorMessage = '密钥长度不正确：期望 $KEY_LENGTH_BYTES '
                '字节，实际 ${decodedKey.length} 字节';
          });
          MemoryUtils.wipeBytes(decodedKey);
          return;
        }

        keyBytes = decodedKey;

        final deltaJson = await cryptoService.decryptContent(
          encryptedDataBase64: widget.strawFile.content.encryptedDataBase64,
          ivBase64: widget.strawFile.content.ivBase64,
          key: keyBytes,
        );

        final strawFileForHash = StrawFile(
          formatVersion: widget.strawFile.formatVersion,
          meta: widget.strawFile.meta,
          content: widget.strawFile.content,
          integrity: IntegrityInfo(
            hash: '',
            hashAlgorithm: widget.strawFile.integrity.hashAlgorithm,
          ),
        );
        final strawFileJson = strawFileForHash.assembleToJson();
        final isIntegrityValid = integrityService.verifyIntegrity(
          content: strawFileJson,
          expectedHash: widget.strawFile.integrity.hash,
        );

        if (!isIntegrityValid) {
          setState(() {
            _isLoading = false;
            _errorMessage = l10n.integrityError;
          });
          MemoryUtils.wipeBytes(keyBytes);
          cryptoService.clearSensitiveData();
          return;
        }

        MemoryUtils.wipeBytes(keyBytes);
        keyBytes = null;
        cryptoService.clearSensitiveData();

        _keyInputKey.currentState?.clear();

        if (mounted) {
          widget.onDecryptSuccess(deltaJson);
          Navigator.pop(context);
        }
      } on CryptoException {
        setState(() {
          _isLoading = false;
          _errorMessage = l10n.keyError;
        });
      } on Exception catch (e) {
        setState(() {
          _isLoading = false;
          _errorMessage = '解密过程中发生错误：$e';
        });
      } finally {
        if (keyBytes != null) {
          MemoryUtils.wipeBytes(keyBytes);
          keyBytes = null;
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final meta = widget.strawFile.meta;

    return Padding(
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
                color: Colors.grey[400],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              controller: widget.scrollController,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Meta preview
                  _buildMetaPreview(meta),
                  const Divider(height: 24),

                  // Input area based on encryption mode
                  if (_isNegotiatedMode) ...[
                    PassphraseDecryptInput(key: _passphraseInputKey),
                  ] else ...[
                    KeyInput(key: _keyInputKey, onKeyChanged: _onKeyChanged),
                    const SizedBox(height: 16),
                    KeyFileUpload(onKeyFileLoaded: _onKeyFileLoaded),
                  ],

                  // Error message
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.withOpacity(0.3)),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: const TextStyle(
                                color: Colors.red,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          // Fixed bottom action bar
          Container(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(context).bottom,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handleDecrypt,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(l10n.decrypt),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaPreview(CardMeta meta) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            meta.title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 8),
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
                    color: Colors.orange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text(
                    '匿名',
                    style: TextStyle(
                      color: Colors.orange,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      meta.publisherAlias,
                      style: TextStyle(
                        fontSize: 13,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatDate(meta.publishDate),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (meta.description != null && meta.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              meta.description!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          if (meta.tags.isNotEmpty) ...[
            const SizedBox(height: 8),
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
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
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
