import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:strawhut/core/file_io/file_selection_service.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/utils/cover_image_service.dart';
import 'package:strawhut/core/utils/image_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/export_options.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/meta_form.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/passphrase_input.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';

/// 发布对话框
///
/// 知识卡片加密发布的弹窗界面，支持两种加密模式：
/// - 随机密钥模式：系统自动生成高强度随机密钥（默认推荐）
/// - 协商密钥模式：通过暗号派生密钥，适合口头分享
///
/// 架构位置：应用层（Presentation Layer）→ 对话框
/// 弹出方式：从 EditorScreen 点击"发布"按钮时调用
///
/// 完整发布流程：
/// 1. 从 EditorProvider 获取当前编辑器内容的 Delta JSON
/// 2. 用户填写元信息并选择加密模式后点击"生成并加密"
/// 3. 根据加密模式生成/派生密钥
/// 4. 调用 CryptoService.encryptContent() 加密内容
/// 5. 调用 IntegrityService.computeHash() 计算哈希
/// 6. 组装 StrawFile JSON
/// 7. 展示生成的密钥或暗号分享提示
/// 8. 用户选择是否导出 .key 文件
/// 9. 调用 FileIOService.writeStrawFile() 保存 .straw 文件
/// 10. 可选调用 FileIOService.writeKeyFile() 保存 .key 文件
/// 11. 调用 CryptoService.clearSensitiveData() 清理敏感数据
/// 12. 关闭对话框，提示发布成功
///
/// 组件结构：
/// - [MetaForm]: 元信息表单（标题、发布者、描述、标签、匿名模式）
/// - [PassphraseInput]: 暗号输入（协商密钥模式下使用）
/// - [KeyDisplay]: 密钥展示（Base64 密钥、复制按钮、安全提示）
/// - [ExportOptions]: 导出选项（是否导出 .key 文件）
class PublishDialog extends ConsumerStatefulWidget {
  /// 创建发布对话框实例
  const PublishDialog({super.key});

  /// 显示发布对话框的静态方法
  ///
  /// 参数：[context] - BuildContext 对象
  /// 返回：对话框关闭时的 Future
  static Future<void> show(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => const _PublishDialogMobile(),
        ),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const PublishDialog(),
    );
  }

  @override
  ConsumerState<PublishDialog> createState() => _PublishDialogState();
}

/// PublishDialog 的内部状态管理类
///
/// 负责管理发布流程的所有状态和业务逻辑：
/// - 表单状态和验证
/// - 加密模式选择
/// - 加密流程控制
/// - 文件保存操作
/// - 密钥展示和导出
class _PublishDialogState extends ConsumerState<PublishDialog> {
  /// MetaForm 组件的全局 Key，用于访问表单方法
  final _metaFormKey = GlobalKey<MetaFormState>();

  /// PassphraseInput 组件的全局 Key，用于访问暗号输入方法
  final _passphraseInputKey = GlobalKey<PassphraseInputState>();

  /// 加载状态（加密进行中）
  bool _isLoading = false;

  /// 是否显示密钥（加密完成后）
  bool _showKey = false;

  /// 生成的 Base64 密钥字符串
  String? _generatedKeyBase64;

  /// 保存的文件路径
  String? _savedFilePath;

  /// 是否导出 .key 文件
  bool _exportKeyFile = false;

  // On Android, only .png export is supported
  String get _exportFormat => defaultTargetPlatform == TargetPlatform.android
      ? 'png'
      : _exportFormatValue;
  String _exportFormatValue = 'straw';
  set _exportFormat(String value) => _exportFormatValue = value;

  Uint8List? _customCoverBytes;

  /// 加密模式：'random' 为随机密钥模式，'negotiated' 为协商密钥模式
  String _encryptionMode = 'random';

  @override
  void dispose() {
    super.dispose();
  }

  /// 处理发布流程
  ///
  /// 完整的加密发布流程：
  /// 1. 验证表单
  /// 2. 获取编辑器内容
  /// 3. 根据加密模式生成/派生密钥
  /// 4. 加密内容
  /// 5. 计算哈希
  /// 6. 组装元数据
  /// 7. 组装 StrawFile
  /// 8. 选择保存路径
  /// 9. 写入文件
  /// 10. 询问是否导出密钥
  /// 11. 清理敏感数据
  /// 12. 显示密钥
  Future<void> _handlePublish() async {
    final l10n = AppLocalizations.of(context)!;

    // 步骤 1：验证表单
    if (!_metaFormKey.currentState!.validate()) return;

    // 协商密钥模式：验证暗号输入
    if (_encryptionMode == 'negotiated') {
      if (!_passphraseInputKey.currentState!.validate()) return;

      // 弱暗号确认
      final strength = _passphraseInputKey.currentState!.strength;
      if (strength == PassphraseStrength.weak) {
        final confirmed = await _showWeakPassphraseWarning();
        if (!confirmed) return;
      }
    }

    // 切换到加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取服务实例
      final cryptoService = ref.read(cryptoServiceProvider);
      final integrityService = ref.read(integrityServiceProvider);
      final editorContent = ref.read(editorContentProvider);

      // 检查编辑器内容是否为空
      // 通过解析 Delta JSON 并提取纯文本来判断，排除 Quill 默认空文档（仅换行符）
      if (!_hasActualContent(editorContent)) {
        _showError('编辑器内容为空，无法发布');
        return;
      }

      if (ImageService.isTotalContentExceeded(editorContent)) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('内容过大提示'),
            content: const Text('当前卡片内容超过 10MB，可能影响加密/解密性能。是否继续发布？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续发布'),
              ),
            ],
          ),
        );
        if (shouldProceed != true) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      // 步骤 2：根据加密模式生成/派生密钥
      final Uint8List keyBytes;
      String? keyBase64;
      String? saltBase64;
      String? kdfAlgorithm;
      int? kdfIterations;

      if (_encryptionMode == 'negotiated') {
        // 协商密钥模式：从暗号派生密钥
        final passphrase = _passphraseInputKey.currentState!.passphrase;

        // 生成 16 字节盐值
        final salt = Uint8List(SALT_LENGTH_BYTES);
        final secureRandom = Random.secure();
        for (var i = 0; i < SALT_LENGTH_BYTES; i++) {
          salt[i] = secureRandom.nextInt(256);
        }

        // 使用 PBKDF2 从暗号派生密钥
        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
        );

        saltBase64 = base64Encode(salt);
        kdfAlgorithm = KDF_ALGORITHM_PBKDF2;
        kdfIterations = KDF_ITERATIONS;
      } else {
        // 随机密钥模式：系统生成随机密钥
        final key = await cryptoService.generateKey();
        keyBytes = key.bytes;
        keyBase64 = key.base64;

        // 为格式统一性也生成盐值，但 kdfAlgorithm/kdfIterations 为 null
        final salt = Uint8List(SALT_LENGTH_BYTES);
        final secureRandom = Random.secure();
        for (var i = 0; i < SALT_LENGTH_BYTES; i++) {
          salt[i] = secureRandom.nextInt(256);
        }
        saltBase64 = base64Encode(salt);
      }

      // 步骤 3：加密内容
      final encrypted = await cryptoService.encryptContent(
        deltaJson: editorContent,
        key: keyBytes,
      );

      // 步骤 4：组装元数据
      final now = DateTime.now().toUtc();
      final formState = _metaFormKey.currentState!;
      final isAnonymous = formState.isAnonymous;
      final publisherAlias =
          isAnonymous ? 'Anonymous' : formState.publisherAlias!;

      final meta = CardMeta(
        publisherAlias: publisherAlias,
        publishDate: '${now.toIso8601String().split('.').first}Z',
        title: formState.title,
        isAnonymous: isAnonymous,
        tags: formState.tags,
        description:
            formState.description.isEmpty ? null : formState.description,
      );

      // 组装带有 KDF 信息的 EncryptedContent
      final encryptedWithKdf = EncryptedContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        algorithm: encrypted.algorithm,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
      );

      // 步骤 5：组装 StrawFile（先用空哈希占位）
      final strawFileForHash = StrawFile(
        formatVersion: const FormatVersion(1, 1, 0),
        meta: meta,
        content: encryptedWithKdf,
        integrity: IntegrityInfo(hash: '', hashAlgorithm: 'SHA-256'),
      );

      // 步骤 6：计算完整 JSON 的哈希（此时 integrity.hash 为空）
      final hash = integrityService.computeHash(
        strawFileForHash.assembleToJson(),
      );

      // 步骤 7：用正确的哈希组装最终的 StrawFile
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 1, 0),
        meta: meta,
        content: encryptedWithKdf,
        integrity: IntegrityInfo(hash: hash, hashAlgorithm: 'SHA-256'),
      );

      String savePath;
      final fileSelectionService = ref.read(fileSelectionServiceProvider);
      final l10n = AppLocalizations.of(context)!;

      if (_exportFormat == 'png') {
        final pngBytes = await CoverImageService.createStrawPng(
          strawJson: strawFile.assembleToJson(),
          title: meta.title,
          publisherAlias: publisherAlias,
          publishDate: meta.publishDate,
          tags: meta.tags,
          description: meta.description,
          isAnonymous: isAnonymous,
          customImageBytes: _customCoverBytes,
        );

        final pngSavePath = await fileSelectionService.saveFileBytes(
          fileName: '${meta.title}.png',
          bytes: pngBytes,
          fileType: 'png',
        );

        if (pngSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
          });
          return;
        }

        // Notify MediaStore on Android so the image appears in gallery
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _notifyMediaStore(pngSavePath);
        }

        savePath = pngSavePath;
      } else {
        final strawSavePath = await fileSelectionService.saveFile(
          fileName: '${meta.title}.straw',
          content: strawFile.assembleToJson(),
          fileType: 'straw',
        );

        if (strawSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
          });
          return;
        }

        savePath = strawSavePath;
      }

      // 步骤 10：如果勾选了导出选项，则导出 .key 文件（仅随机密钥模式）
      if (_exportKeyFile && _encryptionMode == 'random') {
        debugPrint('导出 Key 文件选项已勾选，准备弹出保存对话框');
        final keyPath = await fileSelectionService.saveFile(
          fileName: '${meta.title}.key',
          content: jsonEncode(
            _buildKeyFile(keyBase64: keyBase64!, cardTitle: meta.title),
          ),
          fileType: 'key',
        );
        debugPrint('Key 文件保存路径: ${keyPath ?? "用户取消"}');

        if (keyPath != null) {
          try {
            debugPrint('Key 文件写入成功: $keyPath');
          } on Exception catch (e) {
            debugPrint('Key 文件写入失败: $e');
            _showError('密钥文件写入失败：$e');
          }
        }
      }

      // 步骤 11：清理敏感数据
      cryptoService.clearSensitiveData();

      // 步骤 12：清空编辑器内容
      if (mounted) {
        ref.read(editorContentProvider.notifier).clear();
      }

      // 协商密钥模式：清空暗号输入
      if (_encryptionMode == 'negotiated') {
        _passphraseInputKey.currentState?.clear();
      }

      // 步骤 13：切换到密钥显示状态
      setState(() {
        _isLoading = false;
        _showKey = true;
        _generatedKeyBase64 = keyBase64;
        _savedFilePath = savePath;
      });

      // 步骤 14：显示成功提示
      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, show localized save location message
        String saveMessage;
        if (_exportFormat == 'png') {
          saveMessage = l10n.pngSavedToPhotos;
        } else if (_exportKeyFile && _encryptionMode == 'random') {
          saveMessage = l10n.keySavedToDownloads;
        } else {
          saveMessage = l10n.strawSavedToDownloads;
        }
        _showSuccess(saveMessage);
      } else {
        _showSuccess('发布成功！文件已保存至：$savePath');
      }
    } on Exception catch (e) {
      _showError('发布失败：$e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// 显示弱暗号警告对话框
  ///
  /// 当暗号强度为 weak 时弹出确认对话框，
  /// 让用户选择返回修改或继续使用。
  ///
  /// 返回：true 表示用户确认继续，false 表示返回修改
  Future<bool> _showWeakPassphraseWarning() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.weakPassphraseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.passphraseWeakWarning,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.passphraseWeakSuggestion,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.passphraseWeakConfirm,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backToEdit),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirmContinue),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  /// 检查编辑器是否有实际内容（非空白文档）
  ///
  /// Quill 的 Delta JSON 根结构为 ops 数组，直接解码为 List。
  /// 通过提取所有 insert 操作中的纯文本来判断。
  /// 如果纯文本 trim 后为空，但有图片等非文本内嵌，也视为有内容。
  /// 如果纯文本 trim 后为空，则视为空白文档。
  bool _hasActualContent(String deltaJson) {
    if (deltaJson.isEmpty) return false;

    try {
      // Quill Delta JSON 根结构是 List，不是 Map
      final ops = jsonDecode(deltaJson) as List<dynamic>;
      if (ops.isEmpty) return false;

      // 提取所有 insert 操作中的文本内容，同时检查是否有图片等非文本嵌入
      final buffer = StringBuffer();
      bool hasNonTextContent = false;
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else if (insert is Map) {
            // Image or other embed types (e.g. {"image": "data:..."} or {"video": "..."})
            if (insert.containsKey('image') || insert.containsKey('video')) {
              hasNonTextContent = true;
            }
          }
        }
      }

      // 有图片等非文本内容，或有文本内容
      if (hasNonTextContent) return true;
      return buffer.toString().trim().isNotEmpty;
    } on Exception {
      return false;
    }
  }

  /// 构建 .key 文件的 JSON 结构
  ///
  /// 参数：
  /// - [keyBase64]: Base64 编码的密钥
  /// - [cardTitle]: 关联的卡片标题
  ///
  /// 返回：可序列化为 .key 文件的 JSON Map
  Map<String, dynamic> _buildKeyFile({
    required String keyBase64,
    required String cardTitle,
  }) {
    final now = DateTime.now().toUtc();
    final timestamp = '${now.toIso8601String().split('.').first}Z';
    final keyId = 'k_${now.millisecondsSinceEpoch}_${_generateRandomHex(4)}';

    return {
      'format_version': '1.0.0',
      'key_metadata': {
        'key_id': keyId,
        'created_at': timestamp,
        'associated_card_title': cardTitle,
        'key_algorithm': 'AES-256-GCM',
        'key_length_bits': 256,
      },
      'key_data': {'key_base64': keyBase64, 'encoding': 'base64'},
      'integrity': {'hash': '', 'hash_algorithm': 'SHA-256'},
    };
  }

  /// 生成指定长度的随机十六进制字符串
  ///
  /// 参数：[length] - 生成的字节数（每个字节转换为 2 位十六进制）
  /// 返回：随机十六进制字符串
  String _generateRandomHex(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  /// Notify Android MediaStore to scan the newly saved file so it appears in the gallery.
  ///
  /// On Android 10+ (API 29+), files saved via path_provider may not immediately
  /// appear in the Photos app. This method triggers a media scan using media_scanner.
  Future<void> _notifyMediaStore(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
      debugPrint('MediaStore scanned: $filePath');
    } catch (e) {
      debugPrint('MediaStore notification failed for $filePath: $e');
    }
  }

  Future<void> _pickCoverImage() async {
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
    final result = await fileSelectionService.pickImageFile();
    if (result != null) {
      final (bytes, _) = result;
      if (mounted) {
        setState(() {
          _customCoverBytes = bytes;
        });
      }
    }
  }

  /// 显示错误提示
  ///
  /// 参数：[message] - 错误消息内容
  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// 显示成功提示
  ///
  /// 参数：[message] - 成功消息内容
  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // 如果已发布成功，显示密钥展示界面
    if (_showKey &&
        (_generatedKeyBase64 != null || _encryptionMode == 'negotiated')) {
      return _buildKeyDisplayDialog();
    }

    // 否则显示元信息表单界面
    return AlertDialog(
      title: const Text('发布知识卡片'),
      content: SizedBox(
        width: min(500, MediaQuery.sizeOf(context).width * 0.9),
        child: _buildFormContent(l10n),
      ),
      actions: [
        // 取消按钮：关闭对话框
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        // 发布按钮：触发布流程
        FilledButton(
          onPressed: _isLoading ? null : _handlePublish,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('生成并加密'),
        ),
      ],
    );
  }

  /// Builds the shared form content used by both desktop AlertDialog and mobile full-screen versions.
  Widget _buildFormContent(AppLocalizations l10n) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 使用 MetaForm 组件替换内联表单代码
          MetaForm(
            key: _metaFormKey,
            // 表单变化回调（当前无需特殊处理）
            onChanged: () {},
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // 加密模式选择
          Text(
            l10n.encryptionModeLabel,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          RadioListTile<String>(
            title: Text(l10n.randomKeyMode),
            subtitle: Text(
              l10n.randomKeyModeDesc,
              style: const TextStyle(fontSize: 12),
            ),
            value: 'random',
            groupValue: _encryptionMode,
            onChanged: (value) =>
                setState(() => _encryptionMode = value ?? 'random'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),
          RadioListTile<String>(
            title: Text(l10n.negotiatedKeyMode),
            subtitle: Text(
              l10n.negotiatedKeyModeDesc,
              style: const TextStyle(fontSize: 12),
            ),
            value: 'negotiated',
            groupValue: _encryptionMode,
            onChanged: (value) =>
                setState(() => _encryptionMode = value ?? 'random'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
          ),

          // 协商密钥模式：显示暗号输入组件
          if (_encryptionMode == 'negotiated') ...[
            const SizedBox(height: 8),
            PassphraseInput(key: _passphraseInputKey),
            const SizedBox(height: 8),
            const Divider(),
          ] else ...[
            const SizedBox(height: 8),
            const Divider(),
          ],

          const SizedBox(height: 8),
          // Export format selection - hidden on Android (PNG only)
          if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) ...[
            const Text('导出格式：', style: TextStyle(fontWeight: FontWeight.w600)),
            RadioListTile<String>(
              title: const Text('.straw 文件'),
              subtitle: const Text(
                '标准加密知识卡片文件，适合桌面端',
                style: TextStyle(fontSize: 12),
              ),
              value: 'straw',
              groupValue: _exportFormat,
              onChanged: (value) =>
                  setState(() => _exportFormat = value ?? 'straw'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            RadioListTile<String>(
              title: const Text('.png 图片'),
              subtitle: const Text(
                '封面图内嵌加密数据，适合移动端分享',
                style: TextStyle(fontSize: 12),
              ),
              value: 'png',
              groupValue: _exportFormat,
              onChanged: (value) =>
                  setState(() => _exportFormat = value ?? 'straw'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
          ],
          if (_exportFormat == 'png') ...[
            const SizedBox(height: 8),
            const Divider(),
            const SizedBox(height: 4),
            const Text('封面图片：', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChoiceChip(
                  label: const Text('使用元信息生成'),
                  selected: _customCoverBytes == null,
                  onSelected: (_) => setState(() => _customCoverBytes = null),
                ),
                const SizedBox(height: 4),
                ChoiceChip(
                  label: const Text('上传自定义图片'),
                  selected: _customCoverBytes != null,
                  onSelected: (_) => _pickCoverImage(),
                ),
              ],
            ),
            if (_customCoverBytes != null) ...[
              const SizedBox(height: 8),
              Container(
                height: 120,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(_customCoverBytes!, fit: BoxFit.cover),
                ),
              ),
            ],
          ],
          const SizedBox(height: 8),
          const Divider(),
          // 导出密钥文件选项（仅随机密钥模式下可用）
          if (_encryptionMode == 'random')
            CheckboxListTile(
              title: const Text('导出 .key 文件'),
              subtitle: const Text(
                '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
                style: TextStyle(fontSize: 12),
              ),
              value: _exportKeyFile,
              onChanged: (value) =>
                  setState(() => _exportKeyFile = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: Theme.of(context).colorScheme.primary,
              checkColor: Colors.white,
            ),
        ],
      ),
    );
  }

  /// 构建密钥显示对话框
  ///
  /// 在发布成功后展示生成的密钥，并提供导出选项。
  /// 使用 KeyDisplay 和 ExportOptions 子组件。
  /// 协商密钥模式下显示暗号分享提示而非 KeyDisplay。
  Widget _buildKeyDisplayDialog() {
    final l10n = AppLocalizations.of(context)!;
    final isNegotiated = _encryptionMode == 'negotiated';

    return AlertDialog(
      title: const Text('发布成功'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 成功提示
            const Text(
              '知识卡片已成功发布！',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 16),

            // 文件路径信息
            const Text('文件路径：'),
            Text(_savedFilePath ?? '未知', style: const TextStyle(fontSize: 12)),
            if (_exportFormat == 'png') ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '提示：知识卡片已保存。分享时请务必以"原图"方式发送，否则图片压缩会导致数据丢失，接收方将无法解密。',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 根据加密模式显示不同内容
            if (isNegotiated) ...[
              // 协商密钥模式：显示暗号分享提示
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.share_outlined,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.passphraseShareNote,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.blue[800],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Colors.orange[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            l10n.passphraseSecurityNote,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.orange[800],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ] else ...[
              // 随机密钥模式：使用 KeyDisplay 组件展示密钥
              KeyDisplay(keyBase64: _generatedKeyBase64!),
            ],
          ],
        ),
      ),
      actions: [
        // 完成按钮：关闭两层对话框（当前对话框 + EditorScreen）
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(); // 关闭 PublishDialog
            // 使用 context.go 返回首页，避免 Navigator.pop 的问题
            context.go('/');
          },
          child: const Text('完成'),
        ),
      ],
    );
  }
}

/// Mobile full-screen version of the Publish Dialog for Android.
///
/// Uses a Scaffold with AppBar instead of AlertDialog, providing:
/// - Full-screen layout suitable for narrow mobile screens
/// - Scrollable form content
/// - Keyboard-aware layout via MediaQuery.viewInsets
/// - Minimum 48dp touch targets
class _PublishDialogMobile extends StatefulWidget {
  const _PublishDialogMobile();

  @override
  State<_PublishDialogMobile> createState() => _PublishDialogMobileState();
}

class _PublishDialogMobileState extends State<_PublishDialogMobile> {
  final _metaFormKey = GlobalKey<MetaFormState>();
  final _passphraseInputKey = GlobalKey<PassphraseInputState>();

  bool _isLoading = false;
  bool _showKey = false;
  String? _generatedKeyBase64;
  String? _savedFilePath;
  bool _exportKeyFile = false;
  // On Android, only .png export is supported
  String get _exportFormat => defaultTargetPlatform == TargetPlatform.android
      ? 'png'
      : _exportFormatValue;
  String _exportFormatValue = 'straw';
  set _exportFormat(String value) => _exportFormatValue = value;
  Uint8List? _customCoverBytes;
  String _encryptionMode = 'random';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (_showKey &&
        (_generatedKeyBase64 != null || _encryptionMode == 'negotiated')) {
      return _buildKeyDisplayScreen();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: const Text('发布知识卡片'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          tooltip: '取消',
        ),
      ),
      body: Column(
        children: [
          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: bottomInset > 0 ? 16 : 16,
              ),
              child: _buildMobileFormContent(),
            ),
          ),
          // Fixed bottom action bar
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8 + (bottomInset > 0 ? 8 : 0),
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: FilledButton(
                        onPressed: _isLoading ? null : _handleMobilePublish,
                        child: _isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('生成并加密'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileFormContent() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MetaForm(key: _metaFormKey, onChanged: () {}),
        const SizedBox(height: 16),
        const Divider(),
        const SizedBox(height: 8),

        // Encryption mode selection
        Text(
          l10n.encryptionModeLabel,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        RadioListTile<String>(
          title: Text(l10n.randomKeyMode),
          subtitle: Text(
            l10n.randomKeyModeDesc,
            style: const TextStyle(fontSize: 12),
          ),
          value: 'random',
          groupValue: _encryptionMode,
          onChanged: (value) =>
              setState(() => _encryptionMode = value ?? 'random'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
        ),
        RadioListTile<String>(
          title: Text(l10n.negotiatedKeyMode),
          subtitle: Text(
            l10n.negotiatedKeyModeDesc,
            style: const TextStyle(fontSize: 12),
          ),
          value: 'negotiated',
          groupValue: _encryptionMode,
          onChanged: (value) =>
              setState(() => _encryptionMode = value ?? 'random'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
        ),

        if (_encryptionMode == 'negotiated') ...[
          const SizedBox(height: 8),
          PassphraseInput(key: _passphraseInputKey),
          const SizedBox(height: 8),
          const Divider(),
        ] else ...[
          const SizedBox(height: 8),
          const Divider(),
        ],

        const SizedBox(height: 8),
        // Export format selection - hidden on Android (PNG only)
        if (!kIsWeb && defaultTargetPlatform != TargetPlatform.android) ...[
          const Text('导出格式：', style: TextStyle(fontWeight: FontWeight.w600)),
          RadioListTile<String>(
            title: const Text('.straw 文件'),
            subtitle: const Text(
              '标准加密知识卡片文件，适合桌面端',
              style: TextStyle(fontSize: 12),
            ),
            value: 'straw',
            groupValue: _exportFormat,
            onChanged: (value) =>
                setState(() => _exportFormat = value ?? 'straw'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
          ),
          RadioListTile<String>(
            title: const Text('.png 图片'),
            subtitle: const Text(
              '封面图内嵌加密数据，适合移动端分享',
              style: TextStyle(fontSize: 12),
            ),
            value: 'png',
            groupValue: _exportFormat,
            onChanged: (value) =>
                setState(() => _exportFormat = value ?? 'straw'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
          ),
        ],
        if (_exportFormat == 'png') ...[
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 4),
          const Text('封面图片：', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceChip(
                label: const Text('使用元信息生成'),
                selected: _customCoverBytes == null,
                onSelected: (_) => setState(() => _customCoverBytes = null),
              ),
              const SizedBox(height: 8),
              ChoiceChip(
                label: const Text('上传自定义图片'),
                selected: _customCoverBytes != null,
                onSelected: (_) => _pickMobileCoverImage(),
              ),
            ],
          ),
          if (_customCoverBytes != null) ...[
            const SizedBox(height: 8),
            Container(
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.memory(_customCoverBytes!, fit: BoxFit.cover),
              ),
            ),
          ],
        ],
        const SizedBox(height: 16),
        const Divider(),
        // Export key file option (only in random key mode)
        if (_encryptionMode == 'random')
          CheckboxListTile(
            title: const Text('导出 .key 文件'),
            subtitle: const Text(
              '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
              style: TextStyle(fontSize: 12),
            ),
            value: _exportKeyFile,
            onChanged: (value) =>
                setState(() => _exportKeyFile = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: Theme.of(context).colorScheme.primary,
            checkColor: Colors.white,
          ),
      ],
    );
  }

  Future<void> _handleMobilePublish() async {
    // Reuse the same publish logic from the parent class by delegating
    // to a shared implementation. Since we can't access the parent state,
    // we replicate the essential flow here.

    final l10n = AppLocalizations.of(context)!;

    // Step 1: Validate form
    if (!_metaFormKey.currentState!.validate()) return;

    if (_encryptionMode == 'negotiated') {
      if (!_passphraseInputKey.currentState!.validate()) return;

      final strength = _passphraseInputKey.currentState!.strength;
      if (strength == PassphraseStrength.weak) {
        final confirmed = await _showWeakPassphraseWarning();
        if (!confirmed) return;
      }
    }

    setState(() => _isLoading = true);

    try {
      // We need access to providers - use ProviderScope
      final cryptoService = ProviderScope.containerOf(
        context,
      ).read(cryptoServiceProvider);
      final integrityService = ProviderScope.containerOf(
        context,
      ).read(integrityServiceProvider);
      final editorContent = ProviderScope.containerOf(
        context,
      ).read(editorContentProvider);

      if (!_hasActualContent(editorContent)) {
        _showMobileError('编辑器内容为空，无法发布');
        return;
      }

      if (ImageService.isTotalContentExceeded(editorContent)) {
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('内容过大提示'),
            content: const Text('当前卡片内容超过 10MB，可能影响加密/解密性能。是否继续发布？'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('取消'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('继续发布'),
              ),
            ],
          ),
        );
        if (shouldProceed != true) {
          setState(() => _isLoading = false);
          return;
        }
      }

      // Generate/derive key
      final Uint8List keyBytes;
      String? keyBase64;
      String? saltBase64;
      String? kdfAlgorithm;
      int? kdfIterations;

      if (_encryptionMode == 'negotiated') {
        final passphrase = _passphraseInputKey.currentState!.passphrase;
        final salt = Uint8List(SALT_LENGTH_BYTES);
        final secureRandom = Random.secure();
        for (var i = 0; i < SALT_LENGTH_BYTES; i++) {
          salt[i] = secureRandom.nextInt(256);
        }

        keyBytes = await cryptoService.deriveKeyFromPassphrase(
          passphrase: passphrase,
          salt: salt,
        );

        saltBase64 = base64Encode(salt);
        kdfAlgorithm = KDF_ALGORITHM_PBKDF2;
        kdfIterations = KDF_ITERATIONS;
      } else {
        final key = await cryptoService.generateKey();
        keyBytes = key.bytes;
        keyBase64 = key.base64;

        final salt = Uint8List(SALT_LENGTH_BYTES);
        final secureRandom = Random.secure();
        for (var i = 0; i < SALT_LENGTH_BYTES; i++) {
          salt[i] = secureRandom.nextInt(256);
        }
        saltBase64 = base64Encode(salt);
      }

      // Encrypt content
      final encrypted = await cryptoService.encryptContent(
        deltaJson: editorContent,
        key: keyBytes,
      );

      // Assemble metadata
      final now = DateTime.now().toUtc();
      final formState = _metaFormKey.currentState!;
      final isAnonymous = formState.isAnonymous;
      final publisherAlias =
          isAnonymous ? 'Anonymous' : formState.publisherAlias!;

      final meta = CardMeta(
        publisherAlias: publisherAlias,
        publishDate: '${now.toIso8601String().split('.').first}Z',
        title: formState.title,
        isAnonymous: isAnonymous,
        tags: formState.tags,
        description:
            formState.description.isEmpty ? null : formState.description,
      );

      final encryptedWithKdf = EncryptedContent(
        encryptedDataBase64: encrypted.encryptedDataBase64,
        ivBase64: encrypted.ivBase64,
        algorithm: encrypted.algorithm,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
      );

      final strawFileForHash = StrawFile(
        formatVersion: const FormatVersion(1, 1, 0),
        meta: meta,
        content: encryptedWithKdf,
        integrity: IntegrityInfo(hash: '', hashAlgorithm: 'SHA-256'),
      );

      final hash = integrityService.computeHash(
        strawFileForHash.assembleToJson(),
      );

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 1, 0),
        meta: meta,
        content: encryptedWithKdf,
        integrity: IntegrityInfo(hash: hash, hashAlgorithm: 'SHA-256'),
      );

      String savePath;
      final fileSelectionService = ProviderScope.containerOf(
        context,
      ).read(fileSelectionServiceProvider);

      if (_exportFormat == 'png') {
        final pngBytes = await CoverImageService.createStrawPng(
          strawJson: strawFile.assembleToJson(),
          title: meta.title,
          publisherAlias: publisherAlias,
          publishDate: meta.publishDate,
          tags: meta.tags,
          description: meta.description,
          isAnonymous: isAnonymous,
          customImageBytes: _customCoverBytes,
        );

        final pngSavePath = await fileSelectionService.saveFileBytes(
          fileName: '${meta.title}.png',
          bytes: pngBytes,
          fileType: 'png',
        );

        if (pngSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() => _isLoading = false);
          return;
        }

        if (defaultTargetPlatform == TargetPlatform.android) {
          await _notifyMediaStore(pngSavePath);
        }

        savePath = pngSavePath;
      } else {
        final strawSavePath = await fileSelectionService.saveFile(
          fileName: '${meta.title}.straw',
          content: strawFile.assembleToJson(),
          fileType: 'straw',
        );

        if (strawSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() => _isLoading = false);
          return;
        }

        savePath = strawSavePath;
      }

      // Export key file if requested
      if (_exportKeyFile && _encryptionMode == 'random') {
        final keyPath = await fileSelectionService.saveFile(
          fileName: '${meta.title}.key',
          content: jsonEncode(
            _buildKeyFile(keyBase64: keyBase64!, cardTitle: meta.title),
          ),
          fileType: 'key',
        );

        if (keyPath != null) {
          try {
            debugPrint('Key 文件写入成功: $keyPath');
          } on Exception catch (e) {
            debugPrint('Key 文件写入失败: $e');
            _showMobileError('密钥文件写入失败：$e');
          }
        }
      }

      cryptoService.clearSensitiveData();

      // Clear editor content
      if (mounted) {
        ProviderScope.containerOf(
          context,
        ).read(editorContentProvider.notifier).clear();
      }

      if (_encryptionMode == 'negotiated') {
        _passphraseInputKey.currentState?.clear();
      }

      setState(() {
        _isLoading = false;
        _showKey = true;
        _generatedKeyBase64 = keyBase64;
        _savedFilePath = savePath;
      });

      // Show success message
      if (mounted) {
        String saveMessage;
        if (_exportFormat == 'png') {
          saveMessage = l10n.pngSavedToPhotos;
        } else if (_exportKeyFile && _encryptionMode == 'random') {
          saveMessage = l10n.keySavedToDownloads;
        } else {
          saveMessage = l10n.strawSavedToDownloads;
        }
        _showMobileSuccess(saveMessage);
      }
    } on Exception catch (e) {
      _showMobileError('发布失败：$e');
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showWeakPassphraseWarning() async {
    final l10n = AppLocalizations.of(context)!;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(l10n.weakPassphraseTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.passphraseWeakWarning,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline,
                  color: Colors.blue[700],
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.passphraseWeakSuggestion,
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              l10n.passphraseWeakConfirm,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.backToEdit),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.confirmContinue),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  bool _hasActualContent(String deltaJson) {
    if (deltaJson.isEmpty) return false;

    try {
      final ops = jsonDecode(deltaJson) as List<dynamic>;
      if (ops.isEmpty) return false;

      final buffer = StringBuffer();
      bool hasNonTextContent = false;
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          } else if (insert is Map) {
            if (insert.containsKey('image') || insert.containsKey('video')) {
              hasNonTextContent = true;
            }
          }
        }
      }

      if (hasNonTextContent) return true;
      return buffer.toString().trim().isNotEmpty;
    } on Exception {
      return false;
    }
  }

  Map<String, dynamic> _buildKeyFile({
    required String keyBase64,
    required String cardTitle,
  }) {
    final now = DateTime.now().toUtc();
    final timestamp = '${now.toIso8601String().split('.').first}Z';
    final keyId = 'k_${now.millisecondsSinceEpoch}_${_generateRandomHex(4)}';

    return {
      'format_version': '1.0.0',
      'key_metadata': {
        'key_id': keyId,
        'created_at': timestamp,
        'associated_card_title': cardTitle,
        'key_algorithm': 'AES-256-GCM',
        'key_length_bits': 256,
      },
      'key_data': {'key_base64': keyBase64, 'encoding': 'base64'},
      'integrity': {'hash': '', 'hash_algorithm': 'SHA-256'},
    };
  }

  String _generateRandomHex(int length) {
    final random = Random.secure();
    return List.generate(
      length,
      (_) => random.nextInt(16).toRadixString(16).padLeft(2, '0'),
    ).join();
  }

  Future<void> _notifyMediaStore(String filePath) async {
    try {
      await MediaScanner.loadMedia(path: filePath);
      debugPrint('MediaStore scanned: $filePath');
    } catch (e) {
      debugPrint('MediaStore notification failed for $filePath: $e');
    }
  }

  Future<void> _pickMobileCoverImage() async {
    final fileSelectionService = ProviderScope.containerOf(
      context,
    ).read(fileSelectionServiceProvider);
    final result = await fileSelectionService.pickImageFile();
    if (result != null) {
      final (bytes, _) = result;
      if (mounted) {
        setState(() => _customCoverBytes = bytes);
      }
    }
  }

  void _showMobileError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[700],
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _showMobileSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green[700],
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Widget _buildKeyDisplayScreen() {
    final l10n = AppLocalizations.of(context)!;
    final isNegotiated = _encryptionMode == 'negotiated';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: const Text('发布成功'),
        leading: const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '知识卡片已成功发布！',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 16),
                  const Text('文件路径：'),
                  Text(
                    _savedFilePath ?? '未知',
                    style: const TextStyle(fontSize: 12),
                  ),
                  if (_exportFormat == 'png') ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.3),
                        ),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange,
                            size: 18,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '提示：知识卡片已保存。分享时请务必以"原图"方式发送，否则图片压缩会导致数据丢失，接收方将无法解密。',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.orange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  if (isNegotiated) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.withOpacity(0.2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.share_outlined,
                                color: Colors.blue[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.passphraseShareNote,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blue[800],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: Colors.orange[700],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.passphraseSecurityNote,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.orange[800],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    KeyDisplay(keyBase64: _generatedKeyBase64!),
                  ],
                ],
              ),
            ),
          ),
          // Bottom action button
          Container(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: 8 + bottomInset,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: Theme.of(context).dividerColor,
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/');
                  },
                  child: const Text('完成'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
