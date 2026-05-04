import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/core/utils/cover_image_service.dart';
import 'package:strawhut/core/utils/image_service.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/export_options.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/meta_form.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';

/// 发布对话框
///
/// 知识卡片加密发布的弹窗界面。
///
/// 架构位置：应用层（Presentation Layer）→ 对话框
/// 弹出方式：从 EditorScreen 点击"发布"按钮时调用
///
/// 完整发布流程：
/// 1. 从 EditorProvider 获取当前编辑器内容的 Delta JSON
/// 2. 用户填写元信息后点击"生成并加密"
/// 3. 调用 CryptoService.generateKey() 生成密钥
/// 4. 调用 CryptoService.encryptContent() 加密内容
/// 5. 调用 IntegrityService.computeHash() 计算哈希
/// 6. 组装 StrawFile JSON
/// 7. 展示生成的密钥
/// 8. 用户选择是否导出 .key 文件
/// 9. 调用 FileIOService.writeStrawFile() 保存 .straw 文件
/// 10. 可选调用 FileIOService.writeKeyFile() 保存 .key 文件
/// 11. 调用 CryptoService.clearSensitiveData() 清理敏感数据
/// 12. 关闭对话框，提示发布成功
///
/// 组件结构：
/// - [MetaForm]: 元信息表单（标题、发布者、描述、标签、匿名模式）
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
/// - 加密流程控制
/// - 文件保存操作
/// - 密钥展示和导出
class _PublishDialogState extends ConsumerState<PublishDialog> {
  /// MetaForm 组件的全局 Key，用于访问表单方法
  final _metaFormKey = GlobalKey<MetaFormState>();

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

  String _exportFormat = 'straw';

  Uint8List? _customCoverBytes;

  @override
  void dispose() {
    super.dispose();
  }

  /// 处理发布流程
  ///
  /// 完整的加密发布流程：
  /// 1. 验证表单
  /// 2. 获取编辑器内容
  /// 3. 生成密钥
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
    // 步骤 1：验证表单
    if (!_metaFormKey.currentState!.validate()) return;

    // 切换到加载状态
    setState(() {
      _isLoading = true;
    });

    try {
      // 获取服务实例
      final cryptoService = ref.read(cryptoServiceProvider);
      final fileIOService = ref.read(fileIOServiceProvider);
      final integrityService = ref.read(integrityServiceProvider);
      final editorContent = ref.read(editorContentProvider);

      // 检查编辑器内容是否为空
      if (editorContent.isEmpty) {
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

      // 步骤 2：生成密钥
      final key = await cryptoService.generateKey();

      // 步骤 3：加密内容
      final encrypted = await cryptoService.encryptContent(
        deltaJson: editorContent,
        key: key.bytes,
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

      // 步骤 5：组装 StrawFile（先用空哈希占位）
      final strawFileForHash = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: meta,
        content: encrypted,
        integrity: IntegrityInfo(
          hash: '',
          hashAlgorithm: 'SHA-256',
        ),
      );

      // 步骤 6：计算完整 JSON 的哈希（此时 integrity.hash 为空）
      final hash =
          integrityService.computeHash(strawFileForHash.assembleToJson());

      // 步骤 7：用正确的哈希组装最终的 StrawFile
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(1, 0, 0),
        meta: meta,
        content: encrypted,
        integrity: IntegrityInfo(
          hash: hash,
          hashAlgorithm: 'SHA-256',
        ),
      );

      String savePath;

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

        final pngSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存知识卡片图片',
          fileName: '${meta.title}.png',
          type: FileType.custom,
          allowedExtensions: ['png'],
        );

        if (pngSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
          });
          return;
        }

        final file = File(pngSavePath);
        await file.writeAsBytes(pngBytes);

        savePath = pngSavePath;
      } else {
        final strawSavePath = await FilePicker.platform.saveFile(
          dialogTitle: '保存知识卡片',
          fileName: '${meta.title}.straw',
          type: FileType.custom,
          allowedExtensions: ['straw'],
        );

        if (strawSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
          });
          return;
        }

        await fileIOService.writeStrawFile(
          content: strawFile.assembleToJson(),
          targetPath: strawSavePath,
        );

        savePath = strawSavePath;
      }

      // 步骤 10：如果勾选了导出选项，则导出 .key 文件
      if (_exportKeyFile) {
        debugPrint('导出 Key 文件选项已勾选，准备弹出保存对话框');
        final keyPath = await FilePicker.platform.saveFile(
          dialogTitle: '保存密钥文件',
          fileName: '${meta.title}.key',
          type: FileType.custom,
          allowedExtensions: ['key'],
        );
        debugPrint('Key 文件保存路径: ${keyPath ?? "用户取消"}');

        if (keyPath != null) {
          try {
            final keyFileJson = _buildKeyFile(
              keyBase64: key.base64,
              cardTitle: meta.title,
            );
            debugPrint('开始写入 Key 文件: $keyPath');
            await fileIOService.writeKeyFile(
              content: jsonEncode(keyFileJson),
              targetPath: keyPath,
            );
            debugPrint('Key 文件写入成功');
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

      // 步骤 13：切换到密钥显示状态
      setState(() {
        _isLoading = false;
        _showKey = true;
        _generatedKeyBase64 = key.base64;
        _savedFilePath = savePath;
      });

      // 步骤 14：显示成功提示
      _showSuccess('发布成功！文件已保存至：$savePath');
    } on Exception catch (e) {
      _showError('发布失败：$e');
      setState(() {
        _isLoading = false;
      });
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
      'integrity': {
        'hash': '',
        'hash_algorithm': 'SHA-256',
      },
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

  Future<void> _pickCoverImage() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      final bytes = await file.readAsBytes();
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
    // 如果已发布成功，显示密钥展示界面
    if (_showKey && _generatedKeyBase64 != null) {
      return _buildKeyDisplayDialog();
    }

    // 否则显示元信息表单界面
    return AlertDialog(
      title: const Text('发布知识卡片'),
      content: SingleChildScrollView(
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
            const Text('导出格式：', style: TextStyle(fontWeight: FontWeight.w600)),
            RadioListTile<String>(
              title: const Text('.straw 文件'),
              subtitle: const Text('标准加密知识卡片文件，适合桌面端',
                  style: TextStyle(fontSize: 12)),
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
              subtitle: const Text('封面图内嵌加密数据，适合移动端分享',
                  style: TextStyle(fontSize: 12)),
              value: 'png',
              groupValue: _exportFormat,
              onChanged: (value) =>
                  setState(() => _exportFormat = value ?? 'straw'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
            ),
            if (_exportFormat == 'png') ...[
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 4),
              const Text('封面图片：',
                  style: TextStyle(fontWeight: FontWeight.w600)),
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
            // 导出密钥文件选项
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
      ),
      actions: [
        // 取消按钮：关闭对话框
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('取消'),
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

  /// 构建密钥显示对话框
  ///
  /// 在发布成功后展示生成的密钥，并提供导出选项。
  /// 使用 KeyDisplay 和 ExportOptions 子组件。
  Widget _buildKeyDisplayDialog() {
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
                  border: Border.all(color: Colors.orange.withOpacity(0.3)),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange, size: 18),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '分享提示：请务必以"原图"方式发送图片，否则图片压缩会导致数据丢失，接收方将无法解密。',
                        style: TextStyle(fontSize: 13, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),

            // 使用 KeyDisplay 组件替换内联密钥显示代码
            KeyDisplay(keyBase64: _generatedKeyBase64!),
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
