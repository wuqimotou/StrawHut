import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/errors/crypto_exception.dart';
import 'package:strawhut/core/utils/memory_utils.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_file_upload.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/widgets/key_input.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';

/// 解密对话框
///
/// 知识卡片解密的弹窗界面，支持两种解密方式：
/// - 方式 A：手动输入 Base64 密钥字符串
/// - 方式 B：上传 .key 密钥文件自动填充密钥
///
/// 架构位置：应用层（Presentation Layer）→ 对话框
/// 弹出方式：从 ReaderScreen 自动弹出或手动调用
///
/// 对话框结构：
/// - 标题："解密知识卡片"
/// - 卡片元数据预览（标题、描述、发布者）
/// - KeyInput：手动输入密钥字符串
/// - KeyFileUpload：上传 .key 文件获取密钥
/// - 底部按钮："取消"、"解密"
///
/// 完整解密流程：
/// 1. 展示当前卡片的元数据预览
/// 2. 用户选择解密方式：
///    - 方式 A：手动输入密钥字符串（Base64）
///    - 方式 B：上传 .key 文件 → 解析获取 key_base64
/// 3. 点击"解密"按钮
/// 4. 调用 CryptoService.decryptContent() 解密
/// 5. 调用 IntegrityService.verifyIntegrity() 校验完整性
/// 6. 解密成功 → 关闭对话框，调用 onDecryptSuccess 回调
/// 7. 解密失败 → 显示错误提示"密钥错误或文件已损坏"
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
/// - 解密流程控制（loading、error）
/// - 调用 CryptoService 和 IntegrityService
/// - 敏感数据清理
class _DecryptDialogState extends ConsumerState<DecryptDialog> {
  /// 密钥输入组件的全局 Key，用于访问其方法
  final _keyInputKey = GlobalKey<KeyInputState>();

  /// 加载状态（解密进行中）
  bool _isLoading = false;

  /// 错误消息
  String? _errorMessage;

  /// 当前输入的密钥字符串
  String? _currentKey;

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
  /// 1. 验证密钥是否已输入
  /// 2. 将 Base64 密钥解码为字节数组
  /// 3. 调用 CryptoService.decryptContent() 解密
  /// 4. 调用 IntegrityService.verifyIntegrity() 校验完整性
  /// 5. 解密成功 → 清理敏感数据 → 关闭对话框 → 调用成功回调
  /// 6. 解密失败 → 显示错误提示
  Future<void> _handleDecrypt() async {
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
      // 重新计算完整的 .straw 文件 JSON 的 SHA-256 哈希，
      // 与文件中存储的哈希比对
      // 注意：计算时需要将 integrity.hash 置空，因为发布时也是用空 hash 计算的
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
          _errorMessage = '文件完整性校验失败，文件可能已被篡改';
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
        _errorMessage = '密钥错误或文件已损坏';
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

  @override
  Widget build(BuildContext context) {
    final meta = widget.strawFile.meta;

    return AlertDialog(
      title: const Text('解密知识卡片'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ========== 卡片元数据预览 ==========
            _buildMetaPreview(meta),
            const Divider(height: 24),

            // ========== 方式 A：手动输入密钥 ==========
            KeyInput(
              key: _keyInputKey,
              onKeyChanged: _onKeyChanged,
            ),
            const SizedBox(height: 16),

            // ========== 方式 B：上传 .key 文件 ==========
            KeyFileUpload(
              onKeyFileLoaded: _onKeyFileLoaded,
            ),

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
          ],
        ),
      ),
      actions: [
        // 取消按钮：关闭对话框
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
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
              : const Text('解密'),
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
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),

          // 发布者信息行
          Row(
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
              if (meta.isAnonymous) const SizedBox(width: 8),
              // 发布者代号
              Icon(
                Icons.person_outline,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 4),
              Text(
                meta.publisherAlias,
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              // 发布日期
              const SizedBox(width: 12),
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
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer
                        .withOpacity(0.5),
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
