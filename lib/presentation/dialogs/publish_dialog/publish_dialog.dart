import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:desktop_drop/desktop_drop.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:media_scanner/media_scanner.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/core/crypto/crypto_constants.dart';
import 'package:strawhut/core/crypto/crypto_models.dart';
import 'package:strawhut/core/integrity/integrity_service.dart';
import 'package:strawhut/core/utils/cover_image_service.dart';
import 'package:strawhut/core/utils/image_service.dart';
import 'package:strawhut/core/utils/memory_utils.dart';
import 'package:strawhut/data/models/card_meta.dart';
import 'package:strawhut/data/models/format_version.dart';
import 'package:strawhut/data/models/integrity_info.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/data/models/straw_content.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/add_passphrase_dialog.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/export_options.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/key_display.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/meta_form.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/passphrase_input.dart';
import 'package:strawhut/presentation/dialogs/publish_dialog/widgets/publish_security_notices.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/providers/editor_provider.dart';
import 'package:strawhut/presentation/providers/picked_file_provider.dart';
import 'package:strawhut/presentation/providers/passphrase_vault_provider.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';
import 'package:strawhut/core/utils/cancellation_token.dart';

/// 发布对话框
///
/// 知识卡片加密发布的弹窗界面，支持两种内容来源和两种加密模式：
/// - 内容来源：
///   - 编辑器内容：富文本模式，从 Quill 编辑器获取 Delta JSON
///   - 上传文件：文件加密模式，直接加密原始文件字节
/// - 加密模式：
///   - 随机密钥模式：系统自动生成高强度随机密钥（默认推荐）
///   - 协商密钥模式：通过暗号派生密钥，适合口头分享
///
/// 架构位置：应用层（Presentation Layer）→ 对话框
/// 弹出方式：从 EditorScreen 点击"发布"按钮时调用
///
/// 完整发布流程：
/// 1. 选择内容来源（编辑器内容 / 上传文件）
/// 2. 填写元信息并选择加密模式后点击"生成并加密"
/// 3. 根据内容来源准备载荷数据和元数据
/// 4. 根据加密模式生成/派生密钥
/// 5. 调用 CryptoService.encrypt() 加密载荷
/// 6. 从 EncryptResult 构建 StrawContent
/// 7. 组装 StrawFile（格式版本 2.0.0）
/// 8. 调用 IntegrityService.computeHash() 计算哈希
/// 9. 展示生成的密钥或暗号分享提示
/// 10. 用户选择是否导出 .key 文件
/// 11. 使用 FileIOService 写入二进制 .straw 文件
/// 12. 可选：构建二进制 .straw 字节嵌入 PNG 图片
/// 13. 调用 CryptoService.clearSensitiveData() 清理敏感数据
/// 14. 关闭对话框，提示发布成功
///
/// 组件结构：
/// - [MetaForm]: 元信息表单（标题、发布者、描述、标签、匿名模式）
/// - [PassphraseInput]: 暗号输入（协商密钥模式下使用）
/// - [KeyDisplay]: 密钥展示（Base64 密钥、复制按钮、安全提示）
/// - [ExportOptions]: 导出选项（是否导出 .key 文件）
class PublishDialog extends ConsumerStatefulWidget {
  /// 初始内容来源模式，用于从首页直接进入文件加密模式时锁定选项
  final ContentSourceMode? initialMode;

  /// 创建发布对话框实例
  const PublishDialog({super.key, this.initialMode});

  /// 显示发布对话框的静态方法
  ///
  /// 参数：
  /// - [context] - BuildContext 对象
  /// - [initialMode] - 初始内容来源模式，传入时锁定该模式并隐藏选择器
  /// 返回：对话框关闭时的 Future
  static Future<void> show(
    BuildContext context, {
    ContentSourceMode? initialMode,
  }) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return Navigator.of(context).push(
        MaterialPageRoute<void>(
          fullscreenDialog: true,
          builder: (context) => _PublishDialogMobile(initialMode: initialMode),
        ),
      );
    }
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PublishDialog(initialMode: initialMode),
    );
  }

  @override
  ConsumerState<PublishDialog> createState() => _PublishDialogState();
}

/// PublishDialog 的内部状态管理类
///
/// 负责管理发布流程的所有状态和业务逻辑：
/// - 内容来源选择（编辑器内容 / 上传文件）
/// - 文件选择和大小警告
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

  /// 取消中状态（用户点击取消后到加密实际停止期间）
  bool _isCancelling = false;

  /// 加密取消令牌
  CancellationToken? _cancellationToken;

  /// 加密进度（0.0 ~ 1.0），仅当 _isLoading 为 true 时有意义
  double _encryptProgress = 0.0;

  /// 进度回调 throttle：上一次 setState 时间，避免每块都触发 UI 重绘
  DateTime? _lastProgressUpdateTime;

  /// 节流式更新进度：每 100ms 或进度到达 1.0 时刷新 UI
  void _throttledSetProgress(double progress) {
    if (!mounted) return;
    final now = DateTime.now();
    final shouldUpdate = _lastProgressUpdateTime == null ||
        now.difference(_lastProgressUpdateTime!) >= const Duration(milliseconds: 100) ||
        progress >= 1.0;
    if (shouldUpdate) {
      _lastProgressUpdateTime = now;
      setState(() {
        _encryptProgress = progress;
      });
    }
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    super.dispose();
  }

  /// 处理取消操作
  ///
  /// 非加载状态：关闭对话框。
  /// 加载状态：触发取消令牌，停止后续分块加密。
  void _handleCancel() {
    if (!_isLoading) {
      Navigator.pop(context);
      return;
    }
    if (_isCancelling) return;
    setState(() {
      _isCancelling = true;
    });
    _cancellationToken?.cancel();
  }

  /// 是否显示密钥（加密完成后）
  bool _showKey = false;

  /// 生成的 Base64 密钥字符串
  String? _generatedKeyBase64;

  /// 保存的文件路径
  String? _savedFilePath;

  /// 是否导出 .key 文件
  bool _exportKeyFile = false;

  /// 内容来源模式
  late ContentSourceMode _contentSourceMode;

  /// 是否锁定内容来源模式（从首页直接进入文件加密时锁定）
  bool get _isContentSourceLocked => widget.initialMode != null;

  String get _exportFormat => _exportFormatValue;
  String _exportFormatValue = 'straw';
  set _exportFormat(String value) {
    _exportFormatValue = value;
  }

  /// 文件加密模式下只能选 .straw
  String get _effectiveExportFormat {
    if (_contentSourceMode == ContentSourceMode.fileUpload) {
      return 'straw';
    }
    return _exportFormat;
  }

  Uint8List? _customCoverBytes;

  /// 加密模式：'random' 为随机密钥模式，'negotiated' 为协商密钥模式
  String _encryptionMode = 'random';

  /// 文件拖放状态：是否有文件正在被拖入文件选择区域
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    _contentSourceMode = widget.initialMode ?? ContentSourceMode.editor;
    if (widget.initialMode == ContentSourceMode.fileUpload) {
      _exportFormatValue = 'straw';
    }
  }

  /// 格式化文件大小为人类可读字符串
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取文件大小警告级别
  ///
  /// 根据文件大小返回不同的警告信息：
  /// - < 10MB: 无警告
  /// - 10-50MB: 提示
  /// - 50-200MB: 警告
  /// - 200MB-1GB: 强烈警告
  /// - >= 1GB: 严重警告
  _FileSizeWarning? _getFileSizeWarning(int fileSizeBytes) {
    const mb = 1024 * 1024;
    if (fileSizeBytes < 10 * mb) return null;
    if (fileSizeBytes < 50 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.hint,
        message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密可能需要较长时间',
      );
    }
    if (fileSizeBytes < 200 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.warning,
        message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密耗时较长，请耐心等待',
      );
    }
    if (fileSizeBytes < 1024 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.strongWarning,
        message: '文件非常大（${_formatFileSize(fileSizeBytes)}），加密/解密将非常耗时，建议使用流式加密',
      );
    }
    return _FileSizeWarning(
      level: _FileSizeWarningLevel.severe,
      message: '文件极大（${_formatFileSize(fileSizeBytes)}），可能占用大量内存和时间，是否继续？',
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false, // 不预加载字节
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;

    // 提取扩展名（不含点号）
    final dotIndex = fileName.lastIndexOf('.');
    final ext = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    // 获取文件路径
    final String? filePath = file.path;

    // 获取文件大小
    int fileSize = 0;
    if (filePath != null) {
      try {
        fileSize = await File(filePath).length();
      } on Exception catch (_) {
        if (mounted) _showError('无法读取文件信息');
        return;
      }
    } else if (file.bytes != null) {
      fileSize = file.bytes!.length;
    }

    // 大文件：只保存路径，使用流式加密
    // 小文件：读取字节到内存
    Uint8List? fileBytes;
    const largeFileThreshold = 10 * 1024 * 1024; // 10MB

    if (fileSize > largeFileThreshold) {
      // 大文件：不加载到内存，使用 filePath + encryptStream
      if (filePath == null) {
        if (mounted) _showError('无法获取文件路径');
        return;
      }
      // fileBytes 保持 null，后续用 encryptStream
    } else {
      // 小文件：读取字节
      if (file.bytes != null) {
        fileBytes = file.bytes;
      } else if (filePath != null) {
        try {
          fileBytes = await File(filePath).readAsBytes();
        } on Exception catch (_) {
          if (mounted) _showError('读取文件失败');
          return;
        }
      }

      if (fileBytes == null) {
        if (mounted) _showError('无法读取文件内容');
        return;
      }
      fileSize = fileBytes.length;
    }

    final info = PickedFileInfo(
      fileName: fileName,
      fileBytes: fileBytes,
      fileSize: fileSize,
      extension: ext,
      filePath: filePath,
    );

    ref.read(pickedFileProvider.notifier).setFile(info);

    // 自动填充标题：使用文件名（不含扩展名）
    final titleFromFileName =
        dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    _metaFormKey.currentState?.updateTitle(titleFromFileName);

    // 检查文件大小警告
    final warning = _getFileSizeWarning(fileSize);
    if (warning != null && mounted) {
      await _showFileSizeWarning(warning);
    }
  }

  /// 显示文件大小警告对话框
  Future<void> _showFileSizeWarning(_FileSizeWarning warning) async {
    final tokens = NeumorphicTokens.ofContext(context);
    final colors = {
      _FileSizeWarningLevel.hint: tokens.inkSecondary,
      _FileSizeWarningLevel.warning: tokens.warning,
      _FileSizeWarningLevel.strongWarning: tokens.warning,
      _FileSizeWarningLevel.severe: tokens.error,
    };
    final icons = {
      _FileSizeWarningLevel.hint: StrawIcons.info,
      _FileSizeWarningLevel.warning: StrawIcons.warning,
      _FileSizeWarningLevel.strongWarning: StrawIcons.warning,
      _FileSizeWarningLevel.severe: StrawIcons.error,
    };

    final color = colors[warning.level]!;
    final icon = icons[warning.level]!;

    // 根据级别设置不同的标题和按钮文字
    String title;
    String cancelText;
    switch (warning.level) {
      case _FileSizeWarningLevel.hint:
        title = '文件较大';
        cancelText = '知道了';
        break;
      case _FileSizeWarningLevel.warning:
        title = '文件很大';
        cancelText = '返回';
        break;
      case _FileSizeWarningLevel.strongWarning:
        title = '文件超大';
        cancelText = '取消选择';
        break;
      case _FileSizeWarningLevel.severe:
        title = '文件极大';
        cancelText = '取消选择';
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(icon, size: 22, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(icon, size: 20, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warning.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: cancelText,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: '继续',
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) {
      ref.read(pickedFileProvider.notifier).clear();
    }
  }

  /// 处理发布流程
  ///
  /// 完整的加密发布流程：
  /// 1. 验证表单
  /// 2. 根据内容来源准备载荷数据和元数据
  /// 3. 根据加密模式生成/派生密钥
  /// 4. 调用新加密接口 encrypt() 加密载荷
  /// 5. 从 EncryptResult 构建 StrawContent
  /// 6. 组装 StrawFile（格式版本 2.0.0）
  /// 7. 计算哈希
  /// 8. 构建二进制 .straw 数据并保存
  /// 9. 可选导出 PNG
  /// 10. 清理敏感数据
  /// 11. 显示密钥
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

    // 文件上传模式：验证已选文件
    if (_contentSourceMode == ContentSourceMode.fileUpload) {
      final pickedFile = ref.read(pickedFileProvider);
      if (pickedFile == null) {
        _showError('请先选择要加密的文件');
        return;
      }
    }

    // 编辑器模式：检查内容是否为空
    if (_contentSourceMode == ContentSourceMode.editor) {
      final editorContent = ref.read(editorContentProvider);
      if (!_hasActualContent(editorContent)) {
        _showError('编辑器内容为空，无法发布');
        return;
      }

      if (ImageService.isTotalContentExceeded(editorContent)) {
        final tokens = NeumorphicTokens.ofContext(context);
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusXLarge),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NeumorphicIcon(
                          StrawIcons.warning,
                          size: 22,
                          color: tokens.warning,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '内容过大提示',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spaceMd),
                    Text(
                      '当前卡片内容超过 10MB，可能影响加密/解密性能。是否继续发布？',
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textSecondary,
                      ),
                    ),
                    SizedBox(height: tokens.spaceLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        NeumorphicButton(
                          label: '取消',
                          style: NeumorphicButtonStyle.flat,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(width: 8),
                        NeumorphicButton(
                          label: '继续发布',
                          style: NeumorphicButtonStyle.primary,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (shouldProceed != true) {
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }
    }

    // 切换到加载状态
    final cancellationToken = CancellationToken();
    _cancellationToken = cancellationToken;
    setState(() {
      _isLoading = true;
      _isCancelling = false;
      _encryptProgress = 0.0;
    });

    try {
      // 获取服务实例
      final cryptoService = ref.read(cryptoServiceProvider);
      final integrityService = ref.read(integrityServiceProvider);
      final fileIOService = ref.read(fileIOServiceProvider);
      final fileSelectionService = ref.read(fileSelectionServiceProvider);

      // 步骤 2：根据内容来源准备载荷数据和元数据
      final Uint8List? payloadBytes;
      final PayloadMetadata payloadMetadata;

      if (_contentSourceMode == ContentSourceMode.fileUpload) {
        final pickedFile = ref.read(pickedFileProvider)!;
        if (pickedFile.useStreamEncryption) {
          // 大文件：不使用内存加密，后续用 encryptStream
          payloadBytes = null;
        } else {
          payloadBytes = pickedFile.fileBytes;
        }
        payloadMetadata = PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: pickedFile.extension,
          originalFileName: pickedFile.fileName,
        );
      } else {
        final editorContent = ref.read(editorContentProvider);
        payloadBytes = Uint8List.fromList(utf8.encode(editorContent));
        payloadMetadata = const PayloadMetadata(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        );
      }

      // 步骤 3：根据加密模式生成/派生密钥
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

      // 步骤 4：加密载荷
      final EncryptResult encryptResult;
      if (_contentSourceMode == ContentSourceMode.fileUpload) {
        final pickedFile = ref.read(pickedFileProvider)!;
        if (pickedFile.useStreamEncryption) {
          // 大文件：使用流式加密
          encryptResult = await cryptoService.encryptStream(
            sourcePath: pickedFile.filePath!,
            payloadMetadata: payloadMetadata,
            key: keyBytes,
            cancellationToken: cancellationToken,
            onProgress: (current, total) {
              if (total > 0) {
                _throttledSetProgress(current / total);
              }
            },
          );
        } else {
          // 小文件：使用内存加密
          encryptResult = await cryptoService.encrypt(
            payloadBytes: payloadBytes!,
            payloadMetadata: payloadMetadata,
            key: keyBytes,
            cancellationToken: cancellationToken,
            onProgress: (current, total) {
              if (total > 0) {
                _throttledSetProgress(current / total);
              }
            },
          );
        }
      } else {
        // 编辑器内容：使用内存加密
        encryptResult = await cryptoService.encrypt(
          payloadBytes: payloadBytes!,
          payloadMetadata: payloadMetadata,
          key: keyBytes,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (total > 0) {
              _throttledSetProgress(current / total);
            }
          },
        );
      }

      // 步骤 5：从 EncryptResult 构建 StrawContent
      final strawContent = StrawContent(
        encryptionAlgorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
        chunkSize: encryptResult.chunkSize,
        totalChunks: encryptResult.totalChunks,
        originalPayloadSize: encryptResult.originalPayloadSize,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
      );

      // 步骤 6：组装元数据
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

      // 步骤 7：组装 StrawFile（格式版本 2.1.0，先用空哈希占位）
      // v2.1 启用容器认证：GCM 绑定 AAD + 外层 HMAC-SHA256
      final strawFileForHash = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: meta,
        content: strawContent,
        integrity: IntegrityInfo(hash: '', hashAlgorithm: 'HMAC-SHA256'),
      );

      // 步骤 8：构建二进制 .straw 数据并同步计算 HMAC-SHA256 完整性哈希
      // 通过 IntegritySink 边构造边算，消除一次完整 bytes 遍历和一次 buildBinaryFileBytes 调用
      // HMAC 密钥从加密密钥派生，防止攻击者重算哈希绕过完整性校验
      final hmacKey = cryptoService.deriveHmacKey(keyBytes);
      final integritySink = integrityService.createIntegritySink(
        strawFileForHash: strawFileForHash,
        hmacKey: hmacKey,
      );
      MemoryUtils.wipeBytes(hmacKey);

      final binaryResult = fileIOService.buildBinaryFileBytesWithIntegrity(
        strawFileForHash: strawFileForHash,
        chunks: encryptResult.chunks,
        integritySink: integritySink,
      );
      final strawBinaryData = binaryResult.bytes;
      final hash = binaryResult.hash;

      // 步骤 9：用正确的哈希组装最终的 StrawFile（用于后续元数据引用）
      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: meta,
        content: strawContent,
        integrity: IntegrityInfo(hash: hash, hashAlgorithm: 'HMAC-SHA256'),
      );

      String savePath;
      if (_effectiveExportFormat == 'png') {
        // PNG 导出：将二进制 .straw 数据嵌入封面图
        final pngBytes = await CoverImageService.createStrawPng(
          strawBinaryData: strawBinaryData,
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
            _encryptProgress = 0.0;
          });
          return;
        }

        // Notify MediaStore on Android so the image appears in gallery
        if (defaultTargetPlatform == TargetPlatform.android) {
          await _notifyMediaStore(pngSavePath);
        }

        savePath = pngSavePath;
      } else {
        // .straw 导出：直接保存二进制文件
        final strawSavePath = await fileSelectionService.saveFileBytes(
          fileName: '${meta.title}.straw',
          bytes: strawBinaryData,
          fileType: 'straw',
        );

        if (strawSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
            _encryptProgress = 0.0;
          });
          return;
        }

        savePath = strawSavePath;
      }

      // 步骤 11：如果勾选了导出选项，则导出 .key 文件（仅随机密钥模式）
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

      // 步骤 12：清理敏感数据
      cryptoService.clearSensitiveData();

      // 步骤 13：编辑器模式下清空编辑器内容
      if (_contentSourceMode == ContentSourceMode.editor && mounted) {
        ref.read(editorContentProvider.notifier).clear();
      }

      // 文件上传模式下清空已选文件
      if (_contentSourceMode == ContentSourceMode.fileUpload && mounted) {
        ref.read(pickedFileProvider.notifier).clear();
      }

      // 协商密钥模式：保存暗号引用（在清空之前）
      final negotiatedPassphrase = _encryptionMode == 'negotiated'
          ? _passphraseInputKey.currentState?.passphrase
          : null;

      // 协商密钥模式：清空暗号输入
      if (_encryptionMode == 'negotiated') {
        _passphraseInputKey.currentState?.clear();
      }

      // 步骤 14：切换到密钥显示状态
      setState(() {
        _isLoading = false;
        _encryptProgress = 0.0;
        _showKey = true;
        _generatedKeyBase64 = keyBase64;
        _savedFilePath = savePath;
      });

      // 协商密钥模式发布成功后，提示保存暗号到保险库
      if (negotiatedPassphrase != null &&
          negotiatedPassphrase.isNotEmpty &&
          mounted) {
        final vaultService = ref.read(passphraseVaultServiceProvider);
        final alreadySaved = await vaultService.containsPassphrase(
          negotiatedPassphrase,
        );
        if (!alreadySaved && mounted) {
          final shouldSave = await _showSavePassphrasePrompt();
          if (shouldSave == true && mounted) {
            final saved = await AddPassphraseDialog.show(
              context,
              initialPassphrase: negotiatedPassphrase,
            );
            if (saved == true) {
              ref.invalidate(passphraseEntriesProvider);
            }
          }
        }
      }

      // 步骤 15：显示成功提示
      if (defaultTargetPlatform == TargetPlatform.android) {
        // On Android, show localized save location message
        String saveMessage;
        if (_effectiveExportFormat == 'png') {
          saveMessage = l10n.pngSavedToPhotos;
        } else {
          saveMessage = l10n.strawSavedToDownloads;
        }
        if (_exportKeyFile && _encryptionMode == 'random') {
          saveMessage = '$saveMessage\n${l10n.keySavedToDownloads}';
        }
        _showSuccess(saveMessage);
      } else {
        _showSuccess(l10n.publishSavedToPath(savePath));
      }
    } on OperationCancelledException {
      // 用户取消加密，不显示错误，静默恢复初始状态
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
      }
      setState(() {
        _isLoading = false;
        _isCancelling = false;
        _encryptProgress = 0.0;
      });
    } on Exception catch (e) {
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
      }
      _showError(l10n.publishFailed(e.toString()));
      setState(() {
        _isLoading = false;
        _isCancelling = false;
        _encryptProgress = 0.0;
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
    final tokens = NeumorphicTokens.ofContext(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(
                      StrawIcons.warning,
                      size: 22,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.weakPassphraseTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.warning,
                      size: 20,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseWeakWarning,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.info,
                      size: 20,
                      color: tokens.inkSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseWeakSuggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Text(
                  l10n.passphraseWeakConfirm,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: l10n.backToEdit,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: l10n.confirmContinue,
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// 显示发布后保存暗号提示对话框
  ///
  /// 当协商密钥模式发布成功后，如果暗号不在保险库中，
  /// 提示用户是否保存暗号到保险库。
  ///
  /// 返回：true 表示用户选择保存，false 表示跳过
  Future<bool?> _showSavePassphrasePrompt() async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(
                      StrawIcons.save,
                      size: 22,
                      color: tokens.inkPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.saveAfterPublish,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Text(
                  l10n.saveAfterPublishDesc,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: l10n.skipSave,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: l10n.savePassphraseAction,
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
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
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
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
    final tokens = NeumorphicTokens.ofContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.error,
              size: 20,
              color: tokens.surface,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// 显示成功提示
  ///
  /// 参数：[message] - 成功消息内容
  void _showSuccess(String message) {
    if (!mounted) return;
    final tokens = NeumorphicTokens.ofContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.check,
              size: 20,
              color: tokens.surface,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.success,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);

    // 如果已发布成功，显示密钥展示界面
    if (_showKey &&
        (_generatedKeyBase64 != null || _encryptionMode == 'negotiated')) {
      return _buildKeyDisplayDialog();
    }

    // 否则显示元信息表单界面
    return Dialog(
      backgroundColor: tokens.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(tokens.radiusXLarge),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: min(520, MediaQuery.sizeOf(context).width * 0.9),
        ),
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
                    StrawIcons.publish,
                    size: 22,
                    color: tokens.inkPrimary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      '发布知识卡片',
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
              Flexible(child: _buildFormContent(l10n)),
              SizedBox(height: tokens.spaceMd),
              // 操作按钮
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: _isLoading && _isCancelling
                        ? '取消中...'
                        : l10n.cancel,
                    style: NeumorphicButtonStyle.flat,
                    onPressed: _isCancelling ? null : _handleCancel,
                  ),
                  const SizedBox(width: 8),
                  NeumorphicButton(
                    label: _isLoading
                        ? (_isCancelling
                            ? '取消中...'
                            : _encryptProgress > 0
                                ? '${(_encryptProgress * 100).toInt()}%'
                                : '加密中...')
                        : '生成并加密',
                    style: NeumorphicButtonStyle.primary,
                    icon: _isLoading ? null : StrawIcons.publish,
                    onPressed: _isLoading ? null : _handlePublish,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds the shared form content used by both desktop Dialog and mobile full-screen versions.
  Widget _buildFormContent(AppLocalizations l10n) {
    final tokens = NeumorphicTokens.ofContext(context);
    final pickedFile = ref.watch(pickedFileProvider);

    return SingleChildScrollView(
      // 水平 padding 为凹陷软槽的两侧外阴影留出完整渐变空间，
      // 阴影作用范围 ≈ offset(4) + blur(8) ≈ 12px，需全部容纳以避免截断
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ===== 内容来源选择（仅从编辑器进入时显示） =====
          if (!_isContentSourceLocked) ...[
            Text(
              l10n.contentSourceLabel,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            SegmentedButton<ContentSourceMode>(
              segments: [
                ButtonSegment<ContentSourceMode>(
                  value: ContentSourceMode.editor,
                  label: Text(l10n.editorContentLabel),
                  icon: NeumorphicIcon(
                    StrawIcons.editNote,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                ),
                ButtonSegment<ContentSourceMode>(
                  value: ContentSourceMode.fileUpload,
                  label: Text(l10n.fileUploadLabel),
                  icon: NeumorphicIcon(
                    StrawIcons.uploadFile,
                    size: 18,
                    color: tokens.textSecondary,
                  ),
                ),
              ],
              selected: {_contentSourceMode},
              onSelectionChanged: (selection) {
                final mode = selection.first;
                setState(() {
                  _contentSourceMode = mode;
                  if (mode == ContentSourceMode.editor) {
                    // 切换回编辑器模式时，清空已选文件
                    ref.read(pickedFileProvider.notifier).clear();
                  } else {
                    // 切换到文件上传模式时，强制导出格式为 .straw
                    _exportFormatValue = 'straw';
                  }
                });
                if (mode == ContentSourceMode.editor) {
                  // 恢复编辑器标题
                  final editorContent = ref.read(editorContentProvider);
                  final firstLine = _extractFirstLine(editorContent);
                  if (firstLine.isNotEmpty) {
                    _metaFormKey.currentState?.updateTitle(firstLine);
                  }
                }
              },
            ),
          ],

          // 文件选择区域（仅文件上传模式显示）
          if (_contentSourceMode == ContentSourceMode.fileUpload) ...[
            SizedBox(height: tokens.spaceSm),
            _buildFilePickerArea(pickedFile),
          ],

          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
          SizedBox(height: tokens.spaceSm),

          // 使用 MetaForm 组件替换内联表单代码
          MetaForm(
            key: _metaFormKey,
            // 表单变化回调（当前无需特殊处理）
            onChanged: () {},
          ),
          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
          SizedBox(height: tokens.spaceSm),

          // 加密模式选择
          Text(
            l10n.encryptionModeLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          RadioListTile<String>(
            title: Text(
              l10n.randomKeyMode,
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              l10n.randomKeyModeDesc,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            value: 'random',
            groupValue: _encryptionMode,
            onChanged: (value) =>
                setState(() => _encryptionMode = value ?? 'random'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            activeColor: tokens.inkPrimary,
          ),
          RadioListTile<String>(
            title: Text(
              l10n.negotiatedKeyMode,
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              l10n.negotiatedKeyModeDesc,
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            value: 'negotiated',
            groupValue: _encryptionMode,
            onChanged: (value) =>
                setState(() => _encryptionMode = value ?? 'random'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            dense: true,
            activeColor: tokens.inkPrimary,
          ),

          // 协商密钥模式：显示暗号输入组件
          if (_encryptionMode == 'negotiated') ...[
            SizedBox(height: tokens.spaceSm),
            PassphraseInput(key: _passphraseInputKey),
            SizedBox(height: tokens.spaceSm),
            Divider(height: 1, color: tokens.divider),
          ] else ...[
            SizedBox(height: tokens.spaceSm),
            Divider(height: 1, color: tokens.divider),
          ],

          SizedBox(height: tokens.spaceSm),
          // Export format selection
          // 文件上传模式下只能选择 .straw，隐藏格式选择
          if (!kIsWeb && _contentSourceMode == ContentSourceMode.editor) ...[
            Text(
              '导出格式：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            RadioListTile<String>(
              title: Text(
                '.straw 文件',
                style: TextStyle(color: tokens.textPrimary),
              ),
              subtitle: Text(
                '标准加密知识卡片文件，适合桌面端',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              value: 'straw',
              groupValue: _exportFormat,
              onChanged: (value) =>
                  setState(() => _exportFormat = value ?? 'straw'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: tokens.inkPrimary,
            ),
            RadioListTile<String>(
              title: Text(
                '.png 图片',
                style: TextStyle(color: tokens.textPrimary),
              ),
              subtitle: Text(
                '封面图内嵌加密数据，适合移动端分享',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              value: 'png',
              groupValue: _exportFormat,
              onChanged: (value) =>
                  setState(() => _exportFormat = value ?? 'straw'),
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              dense: true,
              activeColor: tokens.inkPrimary,
            ),
          ],

          // 文件上传模式下显示固定格式提示
          if (!kIsWeb &&
              _contentSourceMode == ContentSourceMode.fileUpload) ...[
            Text(
              '导出格式：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            ListTile(
              leading: NeumorphicIcon(
                StrawIcons.document,
                size: 20,
                color: tokens.textSecondary,
              ),
              title: Text(
                '.straw 文件',
                style: TextStyle(color: tokens.textPrimary),
              ),
              subtitle: Text(
                '文件加密模式仅支持 .straw 格式',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              contentPadding: EdgeInsets.zero,
              dense: true,
            ),
          ],

          if (_effectiveExportFormat == 'png') ...[
            SizedBox(height: tokens.spaceSm),
            Divider(height: 1, color: tokens.divider),
            SizedBox(height: tokens.spaceXs),
            Text(
              '封面图片：',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: tokens.textPrimary,
              ),
            ),
            SizedBox(height: tokens.spaceXs),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ChoiceChip(
                  label: const Text('使用元信息生成'),
                  selected: _customCoverBytes == null,
                  onSelected: (_) => setState(() => _customCoverBytes = null),
                  backgroundColor: tokens.surface,
                  side: BorderSide(color: tokens.surfaceAlt),
                  labelStyle: TextStyle(color: tokens.textPrimary),
                  selectedColor: tokens.inkWash,
                ),
                SizedBox(height: tokens.spaceXs),
                ChoiceChip(
                  label: const Text('上传自定义图片'),
                  selected: _customCoverBytes != null,
                  onSelected: (_) => _pickCoverImage(),
                  backgroundColor: tokens.surface,
                  side: BorderSide(color: tokens.surfaceAlt),
                  labelStyle: TextStyle(color: tokens.textPrimary),
                  selectedColor: tokens.inkWash,
                ),
              ],
            ),
            if (_customCoverBytes != null) ...[
              SizedBox(height: tokens.spaceSm),
              NeumorphicContainer(
                shape: NeumorphicShape.flat,
                borderRadius: tokens.radiusSmall,
                padding: EdgeInsets.zero,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(tokens.radiusSmall),
                  child: SizedBox(
                    height: 120,
                    width: double.infinity,
                    child: Image.memory(
                      _customCoverBytes!,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            ],
          ],
          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
          // 导出密钥文件选项（仅随机密钥模式下可用）
          if (_encryptionMode == 'random')
            CheckboxListTile(
              title: Text(
                '导出 .key 文件',
                style: TextStyle(color: tokens.textPrimary),
              ),
              subtitle: Text(
                '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
                style: TextStyle(fontSize: 12, color: tokens.textSecondary),
              ),
              value: _exportKeyFile,
              onChanged: (value) =>
                  setState(() => _exportKeyFile = value ?? false),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
              activeColor: tokens.inkPrimary,
              checkColor: tokens.surface,
            ),
        ],
      ),
    );
  }

  /// 构建文件选择区域
  Widget _buildFilePickerArea(PickedFileInfo? pickedFile) {
    final tokens = NeumorphicTokens.ofContext(context);

    if (pickedFile != null) {
      // 已选择文件 - 显示文件信息
      final warning = _getFileSizeWarning(pickedFile.fileSize);

      return NeumorphicContainer(
        shape: NeumorphicShape.concave,
        borderRadius: tokens.radiusSmall,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.document,
                  size: 20,
                  color: tokens.inkPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickedFile.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                NeumorphicIconButton(
                  icon: StrawIcons.close,
                  size: 32,
                  iconSize: 16,
                  onPressed: () {
                    ref.read(pickedFileProvider.notifier).clear();
                    // 清空标题
                    _metaFormKey.currentState?.updateTitle('');
                  },
                  tooltip: '移除文件',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '大小：${_formatFileSize(pickedFile.fileSize)}',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            if (warning != null) ...[
              const SizedBox(height: 6),
              _buildFileSizeWarningChip(warning),
            ],
          ],
        ),
      );
    }

    // 未选择文件 - 显示选择按钮/拖放区
    final isDesktop = !kIsWeb &&
        defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS;

    final filePickerArea = InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: _isDragging
                ? tokens.inkSecondary
                : tokens.divider,
            width: _isDragging ? 1.5 : 1,
          ),
        ),
        child: NeumorphicContainer(
          shape: _isDragging ? NeumorphicShape.concave : NeumorphicShape.flat,
          borderRadius: tokens.radiusSmall,
          color: _isDragging ? tokens.inkWash.withValues(alpha: 0.08) : tokens.surface,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              NeumorphicIcon(
                _isDragging ? StrawIcons.fileDownload : StrawIcons.cloudUpload,
                size: 36,
                color: _isDragging ? tokens.inkPrimary : tokens.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                _isDragging ? '释放以添加文件' : '点击选择文件 或 拖拽文件到此处',
                style: TextStyle(
                  fontSize: 14,
                  color: _isDragging
                      ? tokens.inkPrimary
                      : tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '支持任意类型文件',
                style: TextStyle(fontSize: 12, color: tokens.textHint),
              ),
            ],
          ),
        ),
      ),
    );

    if (isDesktop) {
      return DropTarget(
        onDragEntered: (details) {
          setState(() => _isDragging = true);
        },
        onDragExited: (details) {
          setState(() => _isDragging = false);
        },
        onDragDone: (details) async {
          setState(() => _isDragging = false);
          if (details.files.isNotEmpty) {
            final droppedFile = details.files.first;
            try {
              final fileName = droppedFile.name;

              // 提取扩展名（不含点号）
              final dotIndex = fileName.lastIndexOf('.');
              final ext = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

              final filePath = droppedFile.path;
              final fileSize = await File(filePath).length();

              // 大文件：只保存路径，使用流式加密
              Uint8List? fileBytes;
              const largeFileThreshold = 10 * 1024 * 1024; // 10MB

              if (fileSize > largeFileThreshold) {
                // 大文件：不加载到内存，使用 filePath + encryptStream
              } else {
                fileBytes = await File(filePath).readAsBytes();
              }

              final info = PickedFileInfo(
                fileName: fileName,
                fileBytes: fileBytes,
                fileSize: fileSize,
                extension: ext,
                filePath: filePath,
              );

              ref.read(pickedFileProvider.notifier).setFile(info);

              // 自动填充标题：使用文件名（不含扩展名）
              final titleFromFileName =
                  dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
              _metaFormKey.currentState?.updateTitle(titleFromFileName);

              // 检查文件大小警告
              final warning = _getFileSizeWarning(fileSize);
              if (warning != null && mounted) {
                await _showFileSizeWarning(warning);
              }
            } on Exception catch (_) {
              if (mounted) {
                _showError('读取拖放文件失败');
              }
            }
          }
        },
        child: filePickerArea,
      );
    }

    return filePickerArea;
  }

  /// 构建文件大小警告提示芯片
  Widget _buildFileSizeWarningChip(_FileSizeWarning warning) {
    final tokens = NeumorphicTokens.ofContext(context);
    final colors = {
      _FileSizeWarningLevel.hint: tokens.inkSecondary,
      _FileSizeWarningLevel.warning: tokens.warning,
      _FileSizeWarningLevel.strongWarning: tokens.warning,
      _FileSizeWarningLevel.severe: tokens.error,
    };
    final icons = {
      _FileSizeWarningLevel.hint: StrawIcons.info,
      _FileSizeWarningLevel.warning: StrawIcons.warning,
      _FileSizeWarningLevel.strongWarning: StrawIcons.error,
      _FileSizeWarningLevel.severe: StrawIcons.error,
    };

    final color = colors[warning.level]!;
    final icon = icons[warning.level]!;

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      borderRadius: tokens.radiusSmall,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          NeumorphicIcon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              warning.message,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }

  /// 从编辑器内容中提取首行文本
  String _extractFirstLine(String deltaJson) {
    if (deltaJson.isEmpty) return '';
    try {
      final ops = jsonDecode(deltaJson) as List<dynamic>;
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
        // 首行判断：遇到换行就停止
        final text = buffer.toString();
        final newlineIndex = text.indexOf('\n');
        if (newlineIndex >= 0) {
          return text.substring(0, newlineIndex).trim();
        }
      }
      return buffer.toString().trim();
    } on Exception {
      return '';
    }
  }

  /// 构建密钥显示对话框
  ///
  /// 在发布成功后展示生成的密钥，并提供导出选项。
  /// 使用 KeyDisplay 和 ExportOptions 子组件。
  /// 协商密钥模式下显示暗号分享提示而非 KeyDisplay。
  Widget _buildKeyDisplayDialog() {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final isNegotiated = _encryptionMode == 'negotiated';

    return Dialog(
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
                    StrawIcons.check,
                    size: 22,
                    color: tokens.success,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      l10n.publishSuccessTitle,
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 成功提示
                      Text(
                        l10n.publishSuccessMessage,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: tokens.textPrimary,
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),

                      // 文件路径信息
                      Text(
                        l10n.filePathLabel,
                        style: TextStyle(
                          color: tokens.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                      Text(
                        _savedFilePath ?? l10n.unknownValue,
                        style: TextStyle(
                          fontSize: 12,
                          color: tokens.textHint,
                        ),
                      ),
                      SizedBox(height: tokens.spaceMd),
                      PublishSecurityNotices(
                        exportFormat: _effectiveExportFormat,
                        isNegotiated: isNegotiated,
                        keyBase64: _generatedKeyBase64,
                      ),
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
                    label: l10n.done,
                    style: NeumorphicButtonStyle.primary,
                    icon: StrawIcons.check,
                    onPressed: () {
                      Navigator.of(context).pop(); // 关闭 PublishDialog
                      // 使用 context.go 返回首页，避免 Navigator.pop 的问题
                      context.go('/');
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
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
class _PublishDialogMobile extends ConsumerStatefulWidget {
  final ContentSourceMode? initialMode;
  const _PublishDialogMobile({this.initialMode});

  @override
  ConsumerState<_PublishDialogMobile> createState() =>
      _PublishDialogMobileState();
}

class _PublishDialogMobileState extends ConsumerState<_PublishDialogMobile> {
  final _metaFormKey = GlobalKey<MetaFormState>();
  final _passphraseInputKey = GlobalKey<PassphraseInputState>();

  bool _isLoading = false;
  bool _isCancelling = false;
  CancellationToken? _cancellationToken;
  double _encryptProgress = 0.0;

  /// 进度回调 throttle：上一次 setState 时间，避免每块都触发 UI 重绘
  DateTime? _lastProgressUpdateTime;

  /// 节流式更新进度：每 100ms 或进度到达 1.0 时刷新 UI
  void _throttledSetProgress(double progress) {
    if (!mounted) return;
    final now = DateTime.now();
    final shouldUpdate = _lastProgressUpdateTime == null ||
        now.difference(_lastProgressUpdateTime!) >= const Duration(milliseconds: 100) ||
        progress >= 1.0;
    if (shouldUpdate) {
      _lastProgressUpdateTime = now;
      setState(() {
        _encryptProgress = progress;
      });
    }
  }

  @override
  void dispose() {
    _cancellationToken?.cancel();
    super.dispose();
  }

  /// 处理取消操作
  ///
  /// 非加载状态：关闭对话框。
  /// 加载状态：触发取消令牌，停止后续分块加密。
  void _handleCancel() {
    if (!_isLoading) {
      Navigator.pop(context);
      return;
    }
    if (_isCancelling) return;
    setState(() {
      _isCancelling = true;
    });
    _cancellationToken?.cancel();
  }

  bool _showKey = false;
  String? _generatedKeyBase64;
  String? _savedFilePath;
  bool _exportKeyFile = false;

  /// 内容来源模式
  late ContentSourceMode _contentSourceMode;

  /// 是否锁定内容来源模式
  bool get _isContentSourceLocked => widget.initialMode != null;

  String get _exportFormat => _exportFormatValue;
  String _exportFormatValue = 'straw';
  set _exportFormat(String value) => _exportFormatValue = value;

  /// 文件加密模式下只能选 .straw
  String get _effectiveExportFormat {
    if (_contentSourceMode == ContentSourceMode.fileUpload) {
      return 'straw';
    }
    return _exportFormat;
  }

  Uint8List? _customCoverBytes;
  String _encryptionMode = 'random';

  @override
  void initState() {
    super.initState();
    _contentSourceMode = widget.initialMode ?? ContentSourceMode.editor;
    if (widget.initialMode == ContentSourceMode.fileUpload) {
      _exportFormatValue = 'straw';
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    if (_showKey &&
        (_generatedKeyBase64 != null || _encryptionMode == 'negotiated')) {
      return _buildKeyDisplayScreen();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      appBar: AppBar(
        title: Text(
          '发布知识卡片',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        leading: NeumorphicIconButton(
          icon: StrawIcons.close,
          size: 40,
          iconSize: 20,
          onPressed: _isCancelling ? null : _handleCancel,
          tooltip: '取消',
        ),
      ),
      body: Column(
        children: [
          // Scrollable form content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                left: tokens.spaceMd,
                right: tokens.spaceMd,
                top: tokens.spaceMd,
                bottom: tokens.spaceMd,
              ),
              child: _buildMobileFormContent(),
            ),
          ),
          // Fixed bottom action bar
          NeumorphicContainer(
            shape: NeumorphicShape.flat,
            borderRadius: 0,
            padding: EdgeInsets.only(
              left: tokens.spaceMd,
              right: tokens.spaceMd,
              top: tokens.spaceSm,
              bottom: tokens.spaceSm + (bottomInset > 0 ? tokens.spaceSm : 0),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: _isLoading
                    ? Row(
                        children: [
                          Expanded(
                            child: NeumorphicButton(
                              label: _isCancelling
                                  ? '取消中...'
                                  : _encryptProgress > 0
                                      ? '${(_encryptProgress * 100).toInt()}%'
                                      : '加密中...',
                              style: NeumorphicButtonStyle.primary,
                              expanded: true,
                              onPressed: null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          NeumorphicButton(
                            label: '取消',
                            style: NeumorphicButtonStyle.flat,
                            onPressed: _isCancelling ? null : _handleCancel,
                          ),
                        ],
                      )
                    : NeumorphicButton(
                        label: '生成并加密',
                        style: NeumorphicButtonStyle.primary,
                        icon: StrawIcons.publish,
                        expanded: true,
                        onPressed: _handleMobilePublish,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 格式化文件大小为人类可读字符串
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// 获取文件大小警告级别
  _FileSizeWarning? _getFileSizeWarning(int fileSizeBytes) {
    const mb = 1024 * 1024;
    if (fileSizeBytes < 10 * mb) return null;
    if (fileSizeBytes < 50 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.hint,
        message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密可能需要较长时间',
      );
    }
    if (fileSizeBytes < 200 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.warning,
        message: '文件较大（${_formatFileSize(fileSizeBytes)}），加密/解密耗时较长，请耐心等待',
      );
    }
    if (fileSizeBytes < 1024 * mb) {
      return _FileSizeWarning(
        level: _FileSizeWarningLevel.strongWarning,
        message: '文件非常大（${_formatFileSize(fileSizeBytes)}），加密/解密将非常耗时，建议使用流式加密',
      );
    }
    return _FileSizeWarning(
      level: _FileSizeWarningLevel.severe,
      message: '文件极大（${_formatFileSize(fileSizeBytes)}），可能占用大量内存和时间，是否继续？',
    );
  }

  /// 选择文件
  Future<void> _pickFile() async {
    // 先不用 withData 获取文件信息（路径和大小）
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      withData: false,
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final fileName = file.name;

    // 提取扩展名（不含点号）
    final dotIndex = fileName.lastIndexOf('.');
    final ext = dotIndex > 0 ? fileName.substring(dotIndex + 1) : '';

    // 获取文件路径
    String? filePath = file.path;

    // 获取文件大小
    int fileSize = 0;
    if (filePath != null) {
      try {
        fileSize = await File(filePath).length();
      } on Exception catch (_) {
        // 路径不可访问，尝试其他方式
      }
    }

    // 如果路径不可用或大小未知，重新用 withData 选择
    // （安卓端某些 content:// URI 无法直接获取大小和路径）
    if (filePath == null || fileSize == 0) {
      // 回退：重新选择文件，这次 withData: true
      final resultWithData = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: true,
      );
      if (resultWithData == null || resultWithData.files.isEmpty) return;

      final fileWithData = resultWithData.files.first;
      final fileBytes = fileWithData.bytes;
      if (fileBytes == null) {
        if (mounted) _showMobileError('无法读取文件内容');
        return;
      }

      filePath = fileWithData.path;
      fileSize = fileBytes.length;

      final info = PickedFileInfo(
        fileName: fileWithData.name,
        fileBytes: fileBytes,
        fileSize: fileSize,
        extension: ext,
        filePath: filePath,
      );

      ref.read(pickedFileProvider.notifier).setFile(info);

      final titleFromFileName =
          dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
      _metaFormKey.currentState?.updateTitle(titleFromFileName);

      final warning = _getFileSizeWarning(fileSize);
      if (warning != null && mounted) {
        await _showMobileFileSizeWarning(warning);
      }
      return;
    }

    // 大文件：只保存路径
    const largeFileThreshold = 10 * 1024 * 1024; // 10MB
    Uint8List? fileBytes;

    if (fileSize > largeFileThreshold) {
      // 大文件：不加载字节，使用 encryptStream
    } else {
      // 小文件：读取字节
      try {
        fileBytes = await File(filePath).readAsBytes();
      } on Exception catch (_) {
        if (mounted) _showMobileError('读取文件失败');
        return;
      }
    }

    final info = PickedFileInfo(
      fileName: fileName,
      fileBytes: fileBytes,
      fileSize: fileSize,
      extension: ext,
      filePath: filePath,
    );

    ref.read(pickedFileProvider.notifier).setFile(info);

    // 自动填充标题
    final titleFromFileName =
        dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    _metaFormKey.currentState?.updateTitle(titleFromFileName);

    // 检查文件大小警告
    final warning = _getFileSizeWarning(fileSize);
    if (warning != null && mounted) {
      await _showMobileFileSizeWarning(warning);
    }
  }

  /// 显示移动端文件大小警告
  Future<void> _showMobileFileSizeWarning(_FileSizeWarning warning) async {
    final tokens = NeumorphicTokens.ofContext(context);
    final colors = {
      _FileSizeWarningLevel.hint: tokens.inkSecondary,
      _FileSizeWarningLevel.warning: tokens.warning,
      _FileSizeWarningLevel.strongWarning: tokens.warning,
      _FileSizeWarningLevel.severe: tokens.error,
    };
    final icons = {
      _FileSizeWarningLevel.hint: StrawIcons.info,
      _FileSizeWarningLevel.warning: StrawIcons.warning,
      _FileSizeWarningLevel.strongWarning: StrawIcons.error,
      _FileSizeWarningLevel.severe: StrawIcons.error,
    };

    final color = colors[warning.level]!;
    final icon = icons[warning.level]!;

    // 根据级别设置不同的标题和按钮文字
    String title;
    String cancelText;
    switch (warning.level) {
      case _FileSizeWarningLevel.hint:
        title = '文件较大';
        cancelText = '知道了';
        break;
      case _FileSizeWarningLevel.warning:
        title = '文件很大';
        cancelText = '返回';
        break;
      case _FileSizeWarningLevel.strongWarning:
        title = '文件超大';
        cancelText = '取消选择';
        break;
      case _FileSizeWarningLevel.severe:
        title = '文件极大';
        cancelText = '取消选择';
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(icon, size: 22, color: color),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(icon, size: 20, color: color),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        warning.message,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: cancelText,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: '继续',
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (confirmed != true) {
      ref.read(pickedFileProvider.notifier).clear();
    }
  }

  Widget _buildMobileFormContent() {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final pickedFile = ref.watch(pickedFileProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ===== 内容来源选择（仅从编辑器进入时显示） =====
        if (!_isContentSourceLocked) ...[
          Text(
            l10n.contentSourceLabel,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          SegmentedButton<ContentSourceMode>(
            segments: [
              ButtonSegment<ContentSourceMode>(
                value: ContentSourceMode.editor,
                label: Text(l10n.editorContentLabel),
                icon: NeumorphicIcon(
                  StrawIcons.editNote,
                  size: 18,
                  color: tokens.textSecondary,
                ),
              ),
              ButtonSegment<ContentSourceMode>(
                value: ContentSourceMode.fileUpload,
                label: Text(l10n.fileUploadLabel),
                icon: NeumorphicIcon(
                  StrawIcons.uploadFile,
                  size: 18,
                  color: tokens.textSecondary,
                ),
              ),
            ],
            selected: {_contentSourceMode},
            onSelectionChanged: (selection) {
              final mode = selection.first;
              setState(() {
                _contentSourceMode = mode;
                if (mode == ContentSourceMode.editor) {
                  ref.read(pickedFileProvider.notifier).clear();
                } else {
                  _exportFormatValue = 'straw';
                }
              });
              if (mode == ContentSourceMode.editor) {
                final editorContent = ref.read(editorContentProvider);
                final firstLine = _extractFirstLine(editorContent);
                if (firstLine.isNotEmpty) {
                  _metaFormKey.currentState?.updateTitle(firstLine);
                }
              }
            },
          ),
        ],

        // 文件选择区域（仅文件上传模式显示）
        if (_contentSourceMode == ContentSourceMode.fileUpload) ...[
          SizedBox(height: tokens.spaceSm),
          _buildMobileFilePickerArea(pickedFile),
        ],

        SizedBox(height: tokens.spaceMd),
        Divider(height: 1, color: tokens.divider),
        SizedBox(height: tokens.spaceSm),

        MetaForm(key: _metaFormKey, onChanged: () {}),
        SizedBox(height: tokens.spaceMd),
        Divider(height: 1, color: tokens.divider),
        SizedBox(height: tokens.spaceSm),

        // Encryption mode selection
        Text(
          l10n.encryptionModeLabel,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        RadioListTile<String>(
          title: Text(
            l10n.randomKeyMode,
            style: TextStyle(color: tokens.textPrimary),
          ),
          subtitle: Text(
            l10n.randomKeyModeDesc,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          value: 'random',
          groupValue: _encryptionMode,
          onChanged: (value) =>
              setState(() => _encryptionMode = value ?? 'random'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
          activeColor: tokens.inkPrimary,
        ),
        RadioListTile<String>(
          title: Text(
            l10n.negotiatedKeyMode,
            style: TextStyle(color: tokens.textPrimary),
          ),
          subtitle: Text(
            l10n.negotiatedKeyModeDesc,
            style: TextStyle(fontSize: 12, color: tokens.textSecondary),
          ),
          value: 'negotiated',
          groupValue: _encryptionMode,
          onChanged: (value) =>
              setState(() => _encryptionMode = value ?? 'random'),
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          visualDensity: VisualDensity.compact,
          activeColor: tokens.inkPrimary,
        ),

        if (_encryptionMode == 'negotiated') ...[
          SizedBox(height: tokens.spaceSm),
          PassphraseInput(key: _passphraseInputKey),
          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
        ] else ...[
          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
        ],

        SizedBox(height: tokens.spaceSm),
        // Export format selection
        // 文件上传模式下只能选择 .straw
        if (!kIsWeb && _contentSourceMode == ContentSourceMode.editor) ...[
          Text(
            '导出格式：',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          RadioListTile<String>(
            title: Text(
              '.straw 文件',
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              '标准加密知识卡片文件，适合桌面端',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            value: 'straw',
            groupValue: _exportFormat,
            onChanged: (value) =>
                setState(() => _exportFormat = value ?? 'straw'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
            activeColor: tokens.inkPrimary,
          ),
          RadioListTile<String>(
            title: Text(
              '.png 图片',
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              '封面图内嵌加密数据，适合移动端分享',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            value: 'png',
            groupValue: _exportFormat,
            onChanged: (value) =>
                setState(() => _exportFormat = value ?? 'straw'),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            visualDensity: VisualDensity.compact,
            activeColor: tokens.inkPrimary,
          ),
        ],

        // 文件上传模式下显示固定格式提示
        if (!kIsWeb && _contentSourceMode == ContentSourceMode.fileUpload) ...[
          Text(
            '导出格式：',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          ListTile(
            leading: NeumorphicIcon(
              StrawIcons.document,
              size: 20,
              color: tokens.textSecondary,
            ),
            title: Text(
              '.straw 文件',
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              '文件加密模式仅支持 .straw 格式',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            contentPadding: EdgeInsets.zero,
            dense: true,
          ),
        ],

        if (_effectiveExportFormat == 'png') ...[
          SizedBox(height: tokens.spaceSm),
          Divider(height: 1, color: tokens.divider),
          SizedBox(height: tokens.spaceXs),
          Text(
            '封面图片：',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: tokens.textPrimary,
            ),
          ),
          SizedBox(height: tokens.spaceXs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ChoiceChip(
                label: const Text('使用元信息生成'),
                selected: _customCoverBytes == null,
                onSelected: (_) => setState(() => _customCoverBytes = null),
                backgroundColor: tokens.surface,
                side: BorderSide(color: tokens.surfaceAlt),
                labelStyle: TextStyle(color: tokens.textPrimary),
                selectedColor: tokens.inkWash,
              ),
              SizedBox(height: tokens.spaceSm),
              ChoiceChip(
                label: const Text('上传自定义图片'),
                selected: _customCoverBytes != null,
                onSelected: (_) => _pickMobileCoverImage(),
                backgroundColor: tokens.surface,
                side: BorderSide(color: tokens.surfaceAlt),
                labelStyle: TextStyle(color: tokens.textPrimary),
                selectedColor: tokens.inkWash,
              ),
            ],
          ),
          if (_customCoverBytes != null) ...[
            SizedBox(height: tokens.spaceSm),
            NeumorphicContainer(
              shape: NeumorphicShape.flat,
              borderRadius: tokens.radiusSmall,
              padding: EdgeInsets.zero,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(tokens.radiusSmall),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: Image.memory(
                    _customCoverBytes!,
                    fit: BoxFit.cover,
                  ),
                ),
              ),
            ),
          ],
        ],
        SizedBox(height: tokens.spaceMd),
        Divider(height: 1, color: tokens.divider),
        // Export key file option (only in random key mode)
        if (_encryptionMode == 'random')
          CheckboxListTile(
            title: Text(
              '导出 .key 文件',
              style: TextStyle(color: tokens.textPrimary),
            ),
            subtitle: Text(
              '密钥文件可单独保存和传输，建议与 .straw 文件分开保管',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            value: _exportKeyFile,
            onChanged: (value) =>
                setState(() => _exportKeyFile = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            activeColor: tokens.inkPrimary,
            checkColor: tokens.surface,
          ),
      ],
    );
  }

  /// 构建移动端文件选择区域
  Widget _buildMobileFilePickerArea(PickedFileInfo? pickedFile) {
    final tokens = NeumorphicTokens.ofContext(context);

    if (pickedFile != null) {
      final warning = _getFileSizeWarning(pickedFile.fileSize);

      return NeumorphicContainer(
        shape: NeumorphicShape.concave,
        borderRadius: tokens.radiusSmall,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.document,
                  size: 20,
                  color: tokens.inkPrimary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pickedFile.fileName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: tokens.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                NeumorphicIconButton(
                  icon: StrawIcons.close,
                  size: 32,
                  iconSize: 16,
                  onPressed: () {
                    ref.read(pickedFileProvider.notifier).clear();
                    _metaFormKey.currentState?.updateTitle('');
                  },
                  tooltip: '移除文件',
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '大小：${_formatFileSize(pickedFile.fileSize)}',
              style: TextStyle(fontSize: 12, color: tokens.textSecondary),
            ),
            if (warning != null) ...[
              const SizedBox(height: 6),
              _buildMobileFileSizeWarningChip(warning),
            ],
          ],
        ),
      );
    }

    return InkWell(
      onTap: _pickFile,
      borderRadius: BorderRadius.circular(tokens.radiusSmall),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(tokens.radiusSmall),
          border: Border.all(
            color: tokens.divider,
            width: 1,
          ),
        ),
        child: NeumorphicContainer(
          shape: NeumorphicShape.flat,
          borderRadius: tokens.radiusSmall,
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            children: [
              NeumorphicIcon(
                StrawIcons.cloudUpload,
                size: 36,
                color: tokens.textSecondary,
              ),
              const SizedBox(height: 8),
              Text(
                '点击选择文件',
                style: TextStyle(fontSize: 14, color: tokens.textSecondary),
              ),
              const SizedBox(height: 4),
              Text(
                '支持任意类型文件',
                style: TextStyle(fontSize: 12, color: tokens.textHint),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建移动端文件大小警告提示芯片
  Widget _buildMobileFileSizeWarningChip(_FileSizeWarning warning) {
    final tokens = NeumorphicTokens.ofContext(context);
    final colors = {
      _FileSizeWarningLevel.hint: tokens.inkSecondary,
      _FileSizeWarningLevel.warning: tokens.warning,
      _FileSizeWarningLevel.strongWarning: tokens.warning,
      _FileSizeWarningLevel.severe: tokens.error,
    };
    final icons = {
      _FileSizeWarningLevel.hint: StrawIcons.info,
      _FileSizeWarningLevel.warning: StrawIcons.warning,
      _FileSizeWarningLevel.strongWarning: StrawIcons.error,
      _FileSizeWarningLevel.severe: StrawIcons.error,
    };

    final color = colors[warning.level]!;
    final icon = icons[warning.level]!;

    return NeumorphicContainer(
      shape: NeumorphicShape.flat,
      borderRadius: tokens.radiusSmall,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: Row(
        children: [
          NeumorphicIcon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              warning.message,
              style: TextStyle(fontSize: 11, color: color),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleMobilePublish() async {
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

    // 文件上传模式：验证已选文件
    if (_contentSourceMode == ContentSourceMode.fileUpload) {
      final pickedFile = ref.read(pickedFileProvider);
      if (pickedFile == null) {
        _showMobileError('请先选择要加密的文件');
        return;
      }
    }

    // 编辑器模式：检查内容是否为空
    if (_contentSourceMode == ContentSourceMode.editor) {
      final editorContent = ref.read(editorContentProvider);
      if (!_hasActualContent(editorContent)) {
        _showMobileError('编辑器内容为空，无法发布');
        return;
      }

      if (ImageService.isTotalContentExceeded(editorContent)) {
        final tokens = NeumorphicTokens.ofContext(context);
        final shouldProceed = await showDialog<bool>(
          context: context,
          builder: (context) => Dialog(
            backgroundColor: tokens.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusXLarge),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        NeumorphicIcon(
                          StrawIcons.warning,
                          size: 22,
                          color: tokens.warning,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '内容过大提示',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: tokens.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: tokens.spaceMd),
                    Text(
                      '当前卡片内容超过 10MB，可能影响加密/解密性能。是否继续发布？',
                      style: TextStyle(
                        fontSize: 14,
                        color: tokens.textSecondary,
                      ),
                    ),
                    SizedBox(height: tokens.spaceLg),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        NeumorphicButton(
                          label: '取消',
                          style: NeumorphicButtonStyle.flat,
                          onPressed: () => Navigator.pop(context, false),
                        ),
                        const SizedBox(width: 8),
                        NeumorphicButton(
                          label: '继续发布',
                          style: NeumorphicButtonStyle.primary,
                          onPressed: () => Navigator.pop(context, true),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        if (shouldProceed != true) {
          setState(() {
            _isLoading = false;
            _encryptProgress = 0.0;
          });
          return;
        }
      }
    }

    final cancellationToken = CancellationToken();
    _cancellationToken = cancellationToken;
    setState(() {
      _isLoading = true;
      _isCancelling = false;
      _encryptProgress = 0.0;
    });

    try {
      final cryptoService = ref.read(cryptoServiceProvider);
      final integrityService = ref.read(integrityServiceProvider);
      final fileIOService = ref.read(fileIOServiceProvider);
      final fileSelectionService = ref.read(fileSelectionServiceProvider);

      // 根据内容来源准备载荷数据和元数据
      final Uint8List? payloadBytes;
      final PayloadMetadata payloadMetadata;

      if (_contentSourceMode == ContentSourceMode.fileUpload) {
        final pickedFile = ref.read(pickedFileProvider)!;
        if (pickedFile.useStreamEncryption) {
          // 大文件：不使用内存加密，后续用 encryptStream
          payloadBytes = null;
        } else {
          payloadBytes = pickedFile.fileBytes;
        }
        payloadMetadata = PayloadMetadata(
          sourceType: SourceType.rawFile,
          originalExtension: pickedFile.extension,
          originalFileName: pickedFile.fileName,
        );
      } else {
        final editorContent = ref.read(editorContentProvider);
        payloadBytes = Uint8List.fromList(utf8.encode(editorContent));
        payloadMetadata = const PayloadMetadata(
          sourceType: SourceType.richText,
          originalExtension: 'delta',
        );
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

      // 加密载荷
      final EncryptResult encryptResult;
      if (_contentSourceMode == ContentSourceMode.fileUpload) {
        final pickedFile = ref.read(pickedFileProvider)!;
        if (pickedFile.useStreamEncryption) {
          // 大文件：使用流式加密
          encryptResult = await cryptoService.encryptStream(
            sourcePath: pickedFile.filePath!,
            payloadMetadata: payloadMetadata,
            key: keyBytes,
            cancellationToken: cancellationToken,
            onProgress: (current, total) {
              if (total > 0) {
                _throttledSetProgress(current / total);
              }
            },
          );
        } else {
          // 小文件：使用内存加密
          encryptResult = await cryptoService.encrypt(
            payloadBytes: payloadBytes!,
            payloadMetadata: payloadMetadata,
            key: keyBytes,
            cancellationToken: cancellationToken,
            onProgress: (current, total) {
              if (total > 0) {
                _throttledSetProgress(current / total);
              }
            },
          );
        }
      } else {
        // 编辑器内容：使用内存加密
        encryptResult = await cryptoService.encrypt(
          payloadBytes: payloadBytes!,
          payloadMetadata: payloadMetadata,
          key: keyBytes,
          cancellationToken: cancellationToken,
          onProgress: (current, total) {
            if (total > 0) {
              _throttledSetProgress(current / total);
            }
          },
        );
      }

      // 从 EncryptResult 构建 StrawContent
      final strawContent = StrawContent(
        encryptionAlgorithm: ENCRYPTION_ALGORITHM_AES_256_GCM,
        chunkSize: encryptResult.chunkSize,
        totalChunks: encryptResult.totalChunks,
        originalPayloadSize: encryptResult.originalPayloadSize,
        saltBase64: saltBase64,
        kdfAlgorithm: kdfAlgorithm,
        kdfIterations: kdfIterations,
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

      final strawFileForHash = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: meta,
        content: strawContent,
        integrity: IntegrityInfo(hash: '', hashAlgorithm: 'HMAC-SHA256'),
      );

      // 构建不含哈希的二进制字节，计算 HMAC-SHA256 完整性哈希
      final fileBytesWithoutHash = fileIOService.buildBinaryFileBytes(
        strawFile: strawFileForHash,
        chunks: encryptResult.chunks,
      );
      final hmacKey = cryptoService.deriveHmacKey(keyBytes);
      final hash = integrityService.computeHmacFromBytes(
        fileBytesWithoutHash,
        hmacKey,
      );
      MemoryUtils.wipeBytes(hmacKey);

      final strawFile = StrawFile(
        formatVersion: const FormatVersion(2, 1, 0),
        meta: meta,
        content: strawContent,
        integrity: IntegrityInfo(hash: hash, hashAlgorithm: 'HMAC-SHA256'),
      );

      // 构建二进制 .straw 数据
      final strawBinaryData = fileIOService.buildBinaryFileBytes(
        strawFile: strawFile,
        chunks: encryptResult.chunks,
      );

      String savePath;

      if (_effectiveExportFormat == 'png') {
        final pngBytes = await CoverImageService.createStrawPng(
          strawBinaryData: strawBinaryData,
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
            _encryptProgress = 0.0;
          });
          return;
        }

        if (defaultTargetPlatform == TargetPlatform.android) {
          await _notifyMediaStore(pngSavePath);
        }

        savePath = pngSavePath;
      } else {
        final strawSavePath = await fileSelectionService.saveFileBytes(
          fileName: '${meta.title}.straw',
          bytes: strawBinaryData,
          fileType: 'straw',
        );

        if (strawSavePath == null) {
          cryptoService.clearSensitiveData();
          setState(() {
            _isLoading = false;
            _encryptProgress = 0.0;
          });
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

      // Clear editor content (only in editor mode)
      if (_contentSourceMode == ContentSourceMode.editor && mounted) {
        ref.read(editorContentProvider.notifier).clear();
      }

      // Clear picked file (in file upload mode)
      if (_contentSourceMode == ContentSourceMode.fileUpload && mounted) {
        ref.read(pickedFileProvider.notifier).clear();
      }

      // 协商密钥模式：保存暗号引用（在清空之前）
      final negotiatedPassphrase = _encryptionMode == 'negotiated'
          ? _passphraseInputKey.currentState?.passphrase
          : null;

      if (_encryptionMode == 'negotiated') {
        _passphraseInputKey.currentState?.clear();
      }

      setState(() {
        _isLoading = false;
        _encryptProgress = 0.0;
        _showKey = true;
        _generatedKeyBase64 = keyBase64;
        _savedFilePath = savePath;
      });

      // 协商密钥模式发布成功后，提示保存暗号到保险库
      if (negotiatedPassphrase != null &&
          negotiatedPassphrase.isNotEmpty &&
          mounted) {
        final vaultService = ref.read(passphraseVaultServiceProvider);
        final alreadySaved = await vaultService.containsPassphrase(
          negotiatedPassphrase,
        );
        if (!alreadySaved && mounted) {
          final shouldSave = await _showMobileSavePassphrasePrompt();
          if (shouldSave == true && mounted) {
            final saved = await AddPassphraseDialog.show(
              context,
              initialPassphrase: negotiatedPassphrase,
            );
            if (saved == true) {
              ref.invalidate(passphraseEntriesProvider);
            }
          }
        }
      }

      // Show success message
      if (mounted) {
        String saveMessage;
        if (_effectiveExportFormat == 'png') {
          saveMessage = l10n.pngSavedToPhotos;
        } else {
          saveMessage = l10n.strawSavedToDownloads;
        }
        if (_exportKeyFile && _encryptionMode == 'random') {
          saveMessage = '$saveMessage\n${l10n.keySavedToDownloads}';
        }
        _showMobileSuccess(saveMessage);
      }
    } on OperationCancelledException {
      // 用户取消加密，不显示错误，静默恢复初始状态
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
      }
      setState(() {
        _isLoading = false;
        _isCancelling = false;
        _encryptProgress = 0.0;
      });
    } on Exception catch (e) {
      if (identical(_cancellationToken, cancellationToken)) {
        _cancellationToken = null;
      }
      _showMobileError(l10n.publishFailed(e.toString()));
      setState(() {
        _isLoading = false;
        _isCancelling = false;
        _encryptProgress = 0.0;
      });
    }
  }

  Future<bool> _showWeakPassphraseWarning() async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(
                      StrawIcons.warning,
                      size: 22,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.weakPassphraseTitle,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.warning,
                      size: 20,
                      color: tokens.warning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseWeakWarning,
                        style: TextStyle(
                          fontSize: 14,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    NeumorphicIcon(
                      StrawIcons.info,
                      size: 20,
                      color: tokens.inkSecondary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.passphraseWeakSuggestion,
                        style: TextStyle(
                          fontSize: 13,
                          color: tokens.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Text(
                  l10n.passphraseWeakConfirm,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: tokens.textPrimary,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: l10n.backToEdit,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: l10n.confirmContinue,
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return result ?? false;
  }

  /// 显示移动端发布后保存暗号提示对话框
  Future<bool?> _showMobileSavePassphrasePrompt() async {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    return showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    NeumorphicIcon(
                      StrawIcons.save,
                      size: 22,
                      color: tokens.inkPrimary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        l10n.saveAfterPublish,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: tokens.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceMd),
                Text(
                  l10n.saveAfterPublishDesc,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
                ),
                SizedBox(height: tokens.spaceLg),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    NeumorphicButton(
                      label: l10n.skipSave,
                      style: NeumorphicButtonStyle.flat,
                      onPressed: () => Navigator.pop(context, false),
                    ),
                    const SizedBox(width: 8),
                    NeumorphicButton(
                      label: l10n.savePassphraseAction,
                      style: NeumorphicButtonStyle.primary,
                      onPressed: () => Navigator.pop(context, true),
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

  /// 从编辑器内容中提取首行文本
  String _extractFirstLine(String deltaJson) {
    if (deltaJson.isEmpty) return '';
    try {
      final ops = jsonDecode(deltaJson) as List<dynamic>;
      final buffer = StringBuffer();
      for (final op in ops) {
        if (op is Map) {
          final insert = op['insert'];
          if (insert is String) {
            buffer.write(insert);
          }
        }
        final text = buffer.toString();
        final newlineIndex = text.indexOf('\n');
        if (newlineIndex >= 0) {
          return text.substring(0, newlineIndex).trim();
        }
      }
      return buffer.toString().trim();
    } on Exception {
      return '';
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
      (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
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
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
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
    final tokens = NeumorphicTokens.ofContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.error,
              size: 20,
              color: tokens.surface,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.error,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showMobileSuccess(String message) {
    if (!mounted) return;
    final tokens = NeumorphicTokens.ofContext(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeumorphicIcon(
              StrawIcons.check,
              size: 20,
              color: tokens.surface,
            ),
            const SizedBox(width: 8),
            Flexible(child: Text(message)),
          ],
        ),
        backgroundColor: tokens.success,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildKeyDisplayScreen() {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    final isNegotiated = _encryptionMode == 'negotiated';
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          l10n.publishSuccessTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: tokens.textPrimary,
          ),
        ),
        leading: const SizedBox.shrink(),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(tokens.spaceMd),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NeumorphicIcon(
                        StrawIcons.check,
                        size: 22,
                        color: tokens.success,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          l10n.publishSuccessMessage,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: tokens.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spaceMd),
                  Text(
                    l10n.filePathLabel,
                    style: TextStyle(
                      color: tokens.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    _savedFilePath ?? l10n.unknownValue,
                    style: TextStyle(fontSize: 12, color: tokens.textHint),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  PublishSecurityNotices(
                    exportFormat: _effectiveExportFormat,
                    isNegotiated: isNegotiated,
                    keyBase64: _generatedKeyBase64,
                  ),
                ],
              ),
            ),
          ),
          // Bottom action button
          NeumorphicContainer(
            shape: NeumorphicShape.flat,
            borderRadius: 0,
            padding: EdgeInsets.only(
              left: tokens.spaceMd,
              right: tokens.spaceMd,
              top: tokens.spaceSm,
              bottom: tokens.spaceSm + bottomInset,
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: NeumorphicButton(
                  label: l10n.done,
                  style: NeumorphicButtonStyle.primary,
                  icon: StrawIcons.check,
                  expanded: true,
                  onPressed: () {
                    Navigator.of(context).pop();
                    context.go('/');
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 文件大小警告级别
enum _FileSizeWarningLevel {
  /// 提示（10-50MB）
  hint,

  /// 警告（50-200MB）
  warning,

  /// 强烈警告（200MB-1GB）
  strongWarning,

  /// 严重警告（>= 1GB）
  severe,
}

/// 文件大小警告信息
class _FileSizeWarning {
  const _FileSizeWarning({required this.level, required this.message});

  final _FileSizeWarningLevel level;
  final String message;
}
