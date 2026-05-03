import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/dialogs/decrypt_dialog/decrypt_dialog.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
import 'package:strawhut/presentation/screens/reader/widgets/meta_preview.dart';
import 'package:strawhut/presentation/screens/reader/widgets/quill_viewer.dart';

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
/// - 如果已解密：展示 QuillViewer（只读富文本渲染）
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
/// 6. 解密成功 -> 渲染富文本内容（QuillViewer）
/// 7. 清除敏感数据（CryptoService.clearSensitiveData）
///
/// 使用场景：
/// - 用户从 HomeScreen 点击"打开知识卡片"选择 .straw 文件
/// - 用户拖入 .straw 文件到 HomeScreen 的 DropZone
/// - 解密成功后展示知识内容
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
/// - 展示元数据预览或解密后的内容
class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// 当前阅读器状态
  ReaderStatus _status = ReaderStatus.loading;

  /// 解密后的 Delta JSON 内容
  String? _decryptedContent;

  /// 当前加载的知识卡片文件对象
  StrawFile? _strawFile;

  /// 错误消息
  String? _errorMessage;

  /// 标记是否已弹出解密对话框
  bool _hasShownDecryptDialog = false;

  @override
  void initState() {
    super.initState();
    // 在初始化完成后加载文件
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadFile();
    });
  }

  /// 加载知识卡片文件
  ///
  /// 从路由参数中获取文件路径，然后调用 CurrentCard Provider 加载文件。
  ///
  /// 流程：
  /// 1. 从 go_router 的 state.uri.queryParameters 获取 path 参数
  /// 2. 验证路径是否有效
  /// 3. 调用 ref.read(currentCardProvider.notifier).loadFile(filePath)
  /// 4. 监听文件加载结果，更新 UI 状态
  Future<void> _loadFile() async {
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

    // 使用 CurrentCard Provider 加载文件
    try {
      await ref.read(currentCardProvider.notifier).loadFile(filePath);

      // 检查加载结果
      if (mounted) {
        final cardState = ref.read(currentCardProvider);
        final strawFile = cardState.valueOrNull;
        if (cardState.hasError) {
          setState(() {
            _status = ReaderStatus.error;
            _errorMessage = '文件加载失败：${cardState.error}';
          });
        } else if (strawFile != null) {
          setState(() {
            _strawFile = strawFile;
            _status = ReaderStatus.metaOnly;
          });
          // 文件加载成功后，自动弹出解密对话框
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

  /// 弹出解密对话框
  ///
  /// 自动弹出 DecryptDialog，让用户输入密钥进行解密。
  ///
  /// 解密成功后的处理：
  /// 1. 保存解密后的 Delta JSON
  /// 2. 更新状态为 decrypted
  /// 3. 切换到 QuillViewer 展示内容
  void _showDecryptDialog() {
    // 防止重复弹出对话框
    if (_hasShownDecryptDialog || _strawFile == null) {
      return;
    }
    _hasShownDecryptDialog = true;

    DecryptDialog.show(
      context,
      strawFile: _strawFile!,
      onDecryptSuccess: (deltaJson) {
        // 解密成功后，保存解密内容并更新 UI
        if (mounted) {
          setState(() {
            _decryptedContent = deltaJson;
            _status = ReaderStatus.decrypted;
          });
        }
      },
    );
  }

  /// 处理返回按钮
  ///
  /// 返回到首页，并重置阅读器状态。
  void _handleBack() {
    // 清理状态
    setState(() {
      _status = ReaderStatus.loading;
      _decryptedContent = null;
      _strawFile = null;
      _errorMessage = null;
      _hasShownDecryptDialog = false;
    });
    // 返回上一页
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
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

  /// 构建页面主体内容
  ///
  /// 根据当前状态展示不同的内容：
  /// - loading: 加载指示器
  /// - error: 错误提示和重试按钮
  /// - metaOnly: 元数据预览
  /// - decrypted: 富文本查看器
  Widget _buildBody() {
    switch (_status) {
      case ReaderStatus.loading:
        // 加载中的提示
        return const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('正在加载知识卡片...'),
            ],
          ),
        );

      case ReaderStatus.error:
        // 错误提示
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 64,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(height: 16),
                Text(
                  '加载失败',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  _errorMessage ?? '未知错误',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _handleRetry,
                  icon: const Icon(Icons.refresh),
                  label: const Text('重试'),
                ),
              ],
            ),
          ),
        );

      case ReaderStatus.metaOnly:
        // 展示元数据预览
        return _buildMetaOnlyContent();

      case ReaderStatus.decrypted:
        // 展示解密后的内容
        return _buildDecryptedContent();
    }
  }

  /// 构建未解密状态下的页面内容
  ///
  /// 展示 MetaPreview 组件，并提示用户进行解密。
  Widget _buildMetaOnlyContent() {
    final strawFile = _strawFile;
    if (strawFile == null) {
      return const Center(child: Text('文件数据丢失'));
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 元数据预览卡片
          MetaPreview(strawFile: strawFile),
          const SizedBox(height: 16),
          // 解密提示
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '该卡片已加密，请在对话框中输入密钥以解密查看完整内容。',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  /// 构建解密成功后的页面内容
  ///
  /// 使用 QuillViewer 渲染解密后的富文本内容。
  Widget _buildDecryptedContent() {
    if (_decryptedContent == null) {
      return const Center(child: Text('解密内容为空'));
    }
    final meta = _strawFile?.meta;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (meta != null) ...[
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                child: Row(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _formatDate(meta.publishDate),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
            ],
            QuillViewer(deltaJson: _decryptedContent!),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // 获取卡片标题用于 AppBar
    String appBarTitle;
    if (_strawFile != null) {
      appBarTitle = _strawFile!.meta.title;
    } else {
      appBarTitle = '阅读器';
    }

    return Scaffold(
      // 顶部导航栏：卡片标题 + 返回按钮
      appBar: AppBar(
        title: Text(appBarTitle),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _handleBack,
          tooltip: '返回首页',
        ),
        actions: [
          // 在解密状态下，提供重新解密按钮（允许用户换一个密钥重新解密）
          if (_status == ReaderStatus.decrypted)
            IconButton(
              icon: const Icon(Icons.lock_open),
              onPressed: () {
                // 重置为未解密状态，重置对话框标记以便重新弹出
                setState(() {
                  _hasShownDecryptDialog = false;
                });
                _showDecryptDialog();
              },
              tooltip: '重新解密',
              iconSize: 20,
            ),
        ],
      ),
      // 主体内容：根据状态展示不同界面
      body: _buildBody(),
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
