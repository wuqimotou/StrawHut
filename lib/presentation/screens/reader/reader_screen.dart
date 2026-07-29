import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/core/crypto/crypto_models/content_type_classifier.dart';
import 'package:strawhut/core/crypto/crypto_models/encrypt_result.dart';
import 'package:strawhut/core/migration/migration_service.dart';
import 'package:strawhut/core/utils/temp_file_manager.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/decrypt_dialog.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
import 'package:strawhut/presentation/screens/reader/widgets/file_save_prompt.dart';
import 'package:strawhut/presentation/screens/reader/widgets/meta_preview.dart';
import 'package:strawhut/presentation/screens/reader/widgets/quill_viewer.dart';
import 'package:strawhut/presentation/screens/reader/widgets/text_viewer.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';

/// 旧版文件格式检测 Provider
///
/// 提供可覆写的旧版格式检测函数，默认使用 [MigrationService.isOldFormatFile]。
/// 在测试环境中可以覆写此 Provider 以避免真实的 dart:io 文件系统操作。
///
/// 使用方式：
/// ```dart
/// // 生产环境（默认）
/// final isOld = await ref.read(migrationCheckProvider)(filePath);
///
/// // 测试环境覆写
/// container = ProviderContainer(overrides: [
///   migrationCheckProvider.overrideWith((ref) => (_, __) async => false),
/// ]);
/// ```
final migrationCheckProvider = Provider<Future<bool> Function(String)>((ref) {
  return MigrationService.isOldFormatFile;
});

/// Loads a streamed text payload and removes its temporary file.
///
/// Exposed as a provider so Reader integration tests can avoid depending on a
/// platform filesystem implementation while exercising the same state flow.
final streamedTextPayloadLoaderProvider =
    Provider<Future<Uint8List> Function(String)>((ref) {
  return (filePath) async {
    final payloadBytes = await File(filePath).readAsBytes();
    await TempFileManager.deleteTempFile(filePath);
    return payloadBytes;
  };
});

/// 阅读器状态枚举
///
/// 用于跟踪 ReaderScreen 当前的解密状态。
enum ReaderStatus {
  /// 正在加载文件
  loading,

  /// 文件加载失败
  error,

  /// 文件已加载但尚未解密
  metaOnly,

  /// 解密成功，展示内容
  decrypted,
}

/// 阅读器界面
///
/// 知识卡片的阅读页面，负责展示解密后的知识内容。
///
/// 页面结构：
/// - AppBar：标题（卡片标题）+ 返回按钮
/// - 如果未解密：展示 MetaPreview + 弹出 DecryptDialog
/// - 如果已解密：根据内容类型展示不同查看器
///   - richText → QuillViewer（富文本渲染）
///   - text → TextViewer（纯文本展示）
///   - markdown → TextViewer（Markdown 渲染）
///   - image/audio/video/pdf/other → FileSavePrompt（选择保存位置下载）
///
/// 架构位置：应用层（Presentation Layer）
/// 路由路径：'/reader'（由 go_router 配置，通过 query 参数 path 传入文件路径）
/// 依赖 Provider：CurrentCard（加载文件）、CryptoService（解密操作）
///
/// 状态管理流程：
/// 1. 从 HomeScreen 传入文件路径（路由 query 参数）
/// 2. loadFile() -> 读取并解析 .straw 文件
/// 3. 展示元数据预览（MetaPreview）
/// 4. 自动弹出解密对话框（DecryptDialog）
/// 5. 用户输入密钥 -> decrypt() -> 解密 + 完整性校验
/// 6. 解密成功 -> 根据 ContentType 分类 -> 渲染对应内容
/// 7. 需要临时文件的类型（image/audio/video/pdf/other）写入临时文件
/// 8. 非文本类型统一展示 FileSavePrompt，用户选择保存位置下载
/// 9. 离开页面时清理临时文件和敏感数据
///
/// 使用场景：
/// - 用户从 HomeScreen 点击"打开知识卡片"选择 .straw 文件
/// - 用户拖入 .straw 文件到 HomeScreen 的 DropZone
/// - 解密成功后根据内容类型展示对应查看器
class ReaderScreen extends ConsumerStatefulWidget {
  /// 创建阅读器页面实例
  const ReaderScreen({super.key});

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

/// ReaderScreen 的状态管理类
///
/// 负责管理阅读器页面的完整生命周期和解密流程：
/// - 从路由参数获取文件路径
/// - 加载 .straw 文件
/// - 自动弹出解密对话框
/// - 处理解密成功/失败的状态切换
/// - 根据内容类型分类展示不同查看器
/// - 管理临时文件的生命周期
class _ReaderScreenState extends ConsumerState<ReaderScreen>
    with WidgetsBindingObserver {
  /// 当前阅读器状态
  ReaderStatus _status = ReaderStatus.loading;

  /// 解密结果（包含 PayloadMetadata + payloadBytes）
  DecryptResult? _decryptResult;

  /// 分类后的内容类型
  ContentType? _contentType;

  /// 临时文件路径（用于 audio/video/pdf/other 类型）
  String? _tempFilePath;

  /// 当前加载的知识卡片文件对象
  ParsedStrawFile? _strawFile;

  /// 错误消息
  String? _errorMessage;

  /// 标记是否已弹出解密对话框
  bool _hasShownDecryptDialog = false;

  /// 当前 .straw 文件路径，用于流式解密大文件
  String? _filePath;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 在初始化完成后加载文件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFile();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // 清理临时文件
    _cleanupTempFile();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      // 清理临时文件（包含敏感解密数据）
      _cleanupTempFile();
    }
  }

  /// 清理临时文件
  ///
  /// 删除临时文件并重置路径引用。
  void _cleanupTempFile() {
    if (_tempFilePath != null) {
      final filePath = _tempFilePath!;
      _tempFilePath = null;
      TempFileManager.deleteTempFile(filePath);
    }
  }

  /// 显示旧版文件格式迁移提示对话框
  ///
  /// 当检测到文件为旧版 JSON 格式时弹出，询问用户是否进行迁移。
  /// 返回 true 表示用户选择迁移，false 表示取消。
  Future<bool?> _showMigrationDialog() {
    final l10n = AppLocalizations.of(context)!;
    final tokens = NeumorphicTokens.ofContext(context);
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: tokens.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusXLarge),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.legacyFileFormatTitle,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: tokens.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.legacyFileFormatMessage,
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  NeumorphicButton(
                    label: l10n.cancel,
                    style: NeumorphicButtonStyle.flat,
                    onPressed: () => Navigator.of(dialogContext).pop(false),
                  ),
                  const SizedBox(width: 8),
                  NeumorphicButton(
                    label: l10n.migrate,
                    style: NeumorphicButtonStyle.primary,
                    onPressed: () => Navigator.of(dialogContext).pop(true),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 加载知识卡片文件
  ///
  /// 从路由参数中获取文件路径，然后调用 CurrentCard Provider 加载文件。
  /// 支持两种加载方式：
  /// 1. 字节流加载（Android content:// URI / Intent 接收的文件）
  /// 2. 路径加载（Windows 桌面端 / 已知文件路径）
  ///
  /// 流程：
  /// 1. 检查 pendingFileBytesProvider 是否有待处理的字节
  /// 2. 如果有字节，调用 loadFileFromBytes()
  /// 3. 如果没有字节，从 go_router 的 state.uri.queryParameters 获取 path 参数
  /// 4. 调用 ref.read(currentCardProvider.notifier).loadFile(filePath)
  /// 5. 监听文件加载结果，更新 UI 状态
  Future<void> _loadFile() async {
    // 优先检查是否有待处理的字节（来自 Intent 或文件选择器）
    final pendingData = ref.read(pendingFileBytesProvider);
    if (pendingData != null) {
      final bytes = pendingData.$1;
      final fileName = pendingData.$2;

      // Check if old format
      if (MigrationService.isOldFormat(bytes)) {
        if (mounted) {
          final shouldMigrate = await _showMigrationDialog();
          if (shouldMigrate == true) {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.legacyFileMigrationRequired)),
            );
            if (mounted) context.go('/');
          } else {
            if (mounted) context.go('/');
          }
        }
        return;
      }

      // 从字节流加载（Android content:// URI / Intent 接收）
      try {
        final strawFile = await ref
            .read(currentCardProvider.notifier)
            .loadFileFromBytes(bytes, fileName: fileName);

        // 清除待处理的字节
        ref.read(pendingFileBytesProvider.notifier).state = null;

        if (mounted) {
          if (strawFile != null) {
            setState(() {
              _strawFile = strawFile;
              _status = ReaderStatus.metaOnly;
            });
            _showDecryptDialog();
          } else {
            setState(() {
              _status = ReaderStatus.error;
              _errorMessage = '文件加载失败：文件内容为空';
            });
          }
        }
      } on Exception catch (e) {
        if (mounted) {
          setState(() {
            _status = ReaderStatus.error;
            _errorMessage = '文件加载异常：$e';
          });
        }
      }
      return;
    }

    // 从路由参数中获取文件路径
    final state = GoRouterState.of(context);
    final filePath = state.uri.queryParameters['path'];

    // 验证路径是否为空
    if (filePath == null || filePath.isEmpty) {
      if (mounted) {
        setState(() {
          _status = ReaderStatus.error;
          _errorMessage = '未提供有效的文件路径';
        });
      }
      return;
    }

    // 保存文件路径，用于后续流式解密
    _filePath = filePath;

    // 使用 CurrentCard Provider 加载文件
    try {
      // 使用 migrationCheckProvider 检查是否为旧版文件格式
      // 通过 Provider 注入，允许在测试环境中覆写以避免 dart:io 文件操作
      final isOldFormatCheck = ref.read(migrationCheckProvider);
      final isOldFormat = await isOldFormatCheck(filePath);
      if (isOldFormat) {
        if (mounted) {
          final shouldMigrate = await _showMigrationDialog();
          if (shouldMigrate != true) {
            if (mounted) context.go('/');
          } else {
            final l10n = AppLocalizations.of(context)!;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.legacyFileMigrationRequired)),
            );
            if (mounted) context.go('/');
          }
        }
        return;
      }

      // 判断是否使用流式头部加载（.straw 大文件场景）
      // 对 .straw 文件使用流式头部加载，避免将整个文件加载到内存
      final extension = filePath.split('.').last.toLowerCase();
      ParsedStrawFile? strawFile;
      if (extension == 'straw') {
        // .straw 文件：使用流式头部加载，避免将整个文件加载到内存
        strawFile = await ref
            .read(currentCardProvider.notifier)
            .loadFileHeader(filePath);
      } else {
        // .png 文件：仍然全量加载（PNG 文件通常不会很大）
        strawFile =
            await ref.read(currentCardProvider.notifier).loadFile(filePath);
      }

      if (mounted) {
        if (strawFile != null) {
          setState(() {
            _strawFile = strawFile;
            _status = ReaderStatus.metaOnly;
          });
          _showDecryptDialog();
        } else {
          setState(() {
            _status = ReaderStatus.error;
            _errorMessage = '文件加载失败：文件内容为空';
          });
        }
      }
    } on Exception catch (e) {
      if (mounted) {
        setState(() {
          _status = ReaderStatus.error;
          _errorMessage = '文件加载异常：$e';
        });
      }
    }
  }

  /// 处理解密成功回调
  ///
  /// 从 DecryptResult 中提取 PayloadMetadata，分类内容类型，
  /// 并在需要时写入临时文件。
  /// 非文本类型统一展示 FileSavePrompt，用户选择保存位置下载。
  ///
  /// 流式解密时 [DecryptResult.decryptedFilePath] 非空，
  /// 文件已经写入临时目录，直接使用而无需再次写入。
  Future<void> _handleDecryptSuccess(DecryptResult result) async {
    final metadata = result.payloadMetadata;

    // 根据来源类型和原始后缀分类内容类型
    final contentType = ContentTypeClassifier.classify(
      sourceType: metadata.sourceType,
      originalExtension: metadata.originalExtension,
    );

    // 判断是否需要临时文件（image/audio/video/pdf/other 需要临时文件以便保存）
    final needsTemp = contentType != ContentType.richText &&
        contentType != ContentType.text &&
        contentType != ContentType.markdown;

    // 如果需要临时文件，先写入内部临时目录
    String? tempFilePath;
    var displayResult = result;
    if (needsTemp) {
      if (result.decryptedFilePath != null) {
        // 流式解密：文件已经写入临时目录，直接使用
        tempFilePath = result.decryptedFilePath;
      } else {
        // 内存解密：将 payloadBytes 写入临时文件
        try {
          tempFilePath = await TempFileManager.createTempFile(
            extension: metadata.originalExtension,
            bytes: result.payloadBytes,
          );
        } on Exception catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('创建临时文件失败：$e'),
                duration: const Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }
    } else if (result.decryptedFilePath != null) {
      // Path-based .straw files are decrypted to a temporary file even when
      // their payload is text. Read that file before handing the result to the
      // text viewers; the stream result intentionally has empty payloadBytes.
      try {
        final payloadBytes = await ref.read(streamedTextPayloadLoaderProvider)(
          result.decryptedFilePath!,
        );
        displayResult = DecryptResult(
          payloadMetadata: result.payloadMetadata,
          payloadBytes: payloadBytes,
        );
      } on Exception catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('读取解密内容失败：$e'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }
    }

    if (mounted) {
      setState(() {
        _decryptResult = displayResult;
        _contentType = contentType;
        _tempFilePath = tempFilePath;
        _status = ReaderStatus.decrypted;
      });
    }
  }

  /// 弹出解密对话框
  ///
  /// 自动弹出 DecryptDialog，让用户输入密钥进行解密。
  ///
  /// 暗号模式和随机密钥模式都进入同一个显式解密界面。暗号模式
  /// 可以手动输入，也可以由用户从保险库中选择一条记录；不会自动
  /// 遍历或尝试保险库内容。
  void _showDecryptDialog() {
    // 防止重复弹出对话框
    if (_hasShownDecryptDialog || _strawFile == null) {
      return;
    }
    _hasShownDecryptDialog = true;

    final strawFile = _strawFile!;

    DecryptDialog.show(
      context,
      strawFile: strawFile.strawFile,
      parsedFile: strawFile,
      strawFilePath: _filePath,
      onDecryptSuccess: (result) {
        _handleDecryptSuccess(result);
      },
    );
  }

  /// 处理返回按钮
  ///
  /// 清理解密状态并返回到首页。
  void _handleBack() {
    _clearDecryptedState();
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }

  /// 清理解密状态
  void _clearDecryptedState() {
    // 清理临时文件
    _cleanupTempFile();
    setState(() {
      _status = ReaderStatus.loading;
      _decryptResult = null;
      _contentType = null;
      _tempFilePath = null;
      _strawFile = null;
      _errorMessage = null;
      _hasShownDecryptDialog = false;
    });
  }

  /// 处理错误状态下的重试
  ///
  /// 重新加载文件，尝试恢复。
  void _handleRetry() {
    setState(() {
      _status = ReaderStatus.loading;
      _errorMessage = null;
    });
    _loadFile();
  }

  /// 保存文件到用户指定位置
  Future<void> _handleSaveFile() async {
    final result = _decryptResult;
    if (result == null) return;

    final metadata = result.payloadMetadata;
    final originalFileName = metadata.originalFileName;
    final originalExtension = metadata.originalExtension;

    // 确定默认文件名：优先使用 originalFileName，否则使用卡片标题
    String defaultFileName;
    if (originalFileName != null && originalFileName.isNotEmpty) {
      defaultFileName = originalFileName;
    } else {
      final title = _strawFile?.strawFile.meta.title ?? 'unknown';
      defaultFileName =
          originalExtension.isNotEmpty ? '$title.$originalExtension' : title;
    }

    // 获取文件内容字节
    Uint8List fileBytes;
    if (_tempFilePath != null) {
      final sourceFile = File(_tempFilePath!);
      if (!await sourceFile.exists()) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('临时文件已丢失，请重新解密')));
        }
        return;
      }
      fileBytes = await sourceFile.readAsBytes();
    } else if (result.payloadBytes.isNotEmpty) {
      fileBytes = result.payloadBytes;
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无可保存的文件内容')));
      }
      return;
    }

    // 使用 FileSelectionService 让用户选择保存位置
    final fileSelectionService = ref.read(fileSelectionServiceProvider);
    // 从扩展名推断 fileType 用于桌面端过滤器
    final ext = defaultFileName.lastIndexOf('.') > 0
        ? defaultFileName.substring(defaultFileName.lastIndexOf('.') + 1)
        : '';
    final fileType = ext.isEmpty ? 'any' : ext;

    final savedPath = await fileSelectionService.saveFileBytes(
      fileName: defaultFileName,
      bytes: fileBytes,
      fileType: fileType,
    );

    if (savedPath != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('文件已保存至：$savedPath'),
          duration: const Duration(seconds: 3),
        ),
      );
      // 保存成功后清理临时文件
      _cleanupTempFile();
    }
  }

  /// 构建页面主体内容
  ///
  /// 根据当前状态展示不同的内容：
  /// - loading: 加载指示器
  /// - error: 错误提示和重试按钮
  /// - metaOnly: 元数据预览
  /// - decrypted: 根据内容类型展示对应查看器
  Widget _buildBody() {
    final tokens = NeumorphicTokens.ofContext(context);
    switch (_status) {
      case ReaderStatus.loading:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // 凹陷凹槽内的软质进度
              NeumorphicContainer(
                shape: NeumorphicShape.concave,
                borderRadius: tokens.radiusLarge,
                padding: const EdgeInsets.all(24),
                child: CircularProgressIndicator(
                  color: tokens.inkPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '正在加载知识卡片...',
                style: TextStyle(
                  fontSize: 14,
                  color: tokens.textSecondary,
                ),
              ),
            ],
          ),
        );

      case ReaderStatus.error:
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                NeumorphicIcon(
                  StrawIcons.error,
                  size: 64,
                  color: tokens.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: tokens.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                NeumorphicButton(
                  label: '重试',
                  icon: StrawIcons.refresh,
                  style: NeumorphicButtonStyle.primary,
                  onPressed: _handleRetry,
                ),
              ],
            ),
          ),
        );

      case ReaderStatus.metaOnly:
        return _buildMetaOnlyContent();

      case ReaderStatus.decrypted:
        return _buildDecryptedContent();
    }
  }

  /// 构建未解密状态下的页面内容
  ///
  /// 展示 MetaPreview 组件，并提示用户进行解密。
  Widget _buildMetaOnlyContent() {
    final tokens = NeumorphicTokens.ofContext(context);
    final strawFile = _strawFile;
    if (strawFile == null) {
      return Center(
        child: Text(
          '文件数据丢失',
          style: TextStyle(color: tokens.textSecondary),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MetaPreview(strawFile: strawFile.strawFile),
          const SizedBox(height: 16),
          Text(
            '该卡片已加密，请在对话框中输入密钥以解密查看完整内容。',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: tokens.textHint,
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建解密成功后的页面内容
  ///
  /// 根据 ContentType 展示不同的查看器组件：
  /// - richText → QuillViewer
  /// - text → TextViewer
  /// - markdown → TextViewer（isMarkdown=true）
  /// - image/audio/video/pdf/other → FileSavePrompt（选择保存位置下载）
  Widget _buildDecryptedContent() {
    final result = _decryptResult;
    final contentType = _contentType;
    if (result == null || contentType == null) {
      return const Center(child: Text('解密内容为空'));
    }

    final tokens = NeumorphicTokens.ofContext(context);
    final meta = _strawFile?.strawFile.meta;

    // 构建元数据头部
    Widget buildMetaHeader() {
      if (meta == null) return const SizedBox.shrink();
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              children: [
                NeumorphicIcon(
                  StrawIcons.person,
                  size: 16,
                  color: tokens.textSecondary,
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    meta.publisherAlias,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      color: tokens.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                NeumorphicIcon(
                  StrawIcons.calendar,
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
          ),
          Divider(height: 1, color: tokens.divider),
        ],
      );
    }

    // 根据内容类型选择查看器
    Widget contentWidget;
    switch (contentType) {
      case ContentType.richText:
        // 富文本：从 payloadBytes 解析 Delta JSON
        final deltaJson = utf8.decode(result.payloadBytes);
        contentWidget = QuillViewer(deltaJson: deltaJson);

      case ContentType.text:
        // 纯文本
        final textContent = utf8.decode(result.payloadBytes);
        contentWidget = TextViewer(text: textContent);

      case ContentType.markdown:
        // Markdown
        final markdownContent = utf8.decode(result.payloadBytes);
        contentWidget = TextViewer(text: markdownContent, isMarkdown: true);

      case ContentType.image:
      case ContentType.audio:
      case ContentType.video:
      case ContentType.pdf:
      case ContentType.other:
        // 非文本类型统一展示 FileSavePrompt，用户选择保存位置下载
        contentWidget = FileSavePrompt(
          metadata: result.payloadMetadata,
          tempFilePath: _tempFilePath,
          contentType: contentType,
          onSave: _handleSaveFile,
        );
    }

    // 文本类型使用 SingleChildScrollView 包裹元数据头部和内容
    if (contentType == ContentType.richText ||
        contentType == ContentType.text ||
        contentType == ContentType.markdown) {
      return SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [buildMetaHeader(), contentWidget],
          ),
        ),
      );
    }

    // 非文本类型使用 Column 布局
    return Column(
      children: [
        buildMetaHeader(),
        Expanded(child: contentWidget),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final tokens = NeumorphicTokens.ofContext(context);
    // 获取卡片标题用于 AppBar
    String appBarTitle;
    if (_strawFile != null) {
      appBarTitle = _strawFile!.strawFile.meta.title;
    } else {
      appBarTitle = '阅读器';
    }

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _clearDecryptedState();
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/');
        }
      },
      child: Scaffold(
        backgroundColor: tokens.surface,
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight + 8),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  NeumorphicIconButton(
                    icon: StrawIcons.arrowBack,
                    size: 44,
                    iconSize: 20,
                    tooltip: '返回首页',
                    onPressed: _handleBack,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      appBarTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: tokens.textPrimary,
                      ),
                    ),
                  ),
                  // 保存文件按钮（多媒体/PDF/其他）
                  if (_status == ReaderStatus.decrypted &&
                      _contentType != null &&
                      _contentType != ContentType.richText &&
                      _contentType != ContentType.text &&
                      _contentType != ContentType.markdown)
                    NeumorphicIconButton(
                      icon: StrawIcons.saveAlt,
                      size: 44,
                      iconSize: 20,
                      tooltip: '保存文件',
                      onPressed: _handleSaveFile,
                    ),
                  // 重新解密按钮
                  if (_status == ReaderStatus.decrypted) ...[
                    const SizedBox(width: 8),
                    NeumorphicIconButton(
                      icon: StrawIcons.unlock,
                      size: 44,
                      iconSize: 20,
                      tooltip: '重新解密',
                      onPressed: () {
                        _cleanupTempFile();
                        setState(() {
                          _hasShownDecryptDialog = false;
                          _decryptResult = null;
                          _contentType = null;
                          _tempFilePath = null;
                        });
                        _showDecryptDialog();
                      },
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
        body: _buildBody(),
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
