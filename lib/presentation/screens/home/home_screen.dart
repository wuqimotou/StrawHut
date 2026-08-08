import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strawhut/app/neumorphic_tokens.dart';
import 'package:strawhut/core/utils/temp_file_manager.dart';
import 'package:strawhut/presentation/dialogs/passphrase_vault_dialog/passphrase_vault_dialog.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';
import 'package:strawhut/presentation/screens/home/widgets/help_dialog.dart';
import 'package:strawhut/presentation/widgets/neumorphic_button.dart';
import 'package:strawhut/presentation/widgets/neumorphic_container.dart';
import 'package:strawhut/presentation/widgets/neumorphic_icon.dart';
import 'package:strawhut/presentation/widgets/responsive_utils.dart';

/// 首页界面
///
/// StrawHut 应用的入口页面，提供以下功能：
/// - 展示应用标题和 Logo
/// - "新建知识卡片" 按钮 → 导航到 EditorScreen
/// - "打开知识卡片" 按钮 → 触发文件选择器
/// - 拖拽区域（仅 Windows 桌面端）→ 接受 .straw 文件拖入
///
/// 架构位置：应用层（Presentation Layer）
/// 路由路径：'/'（由 go_router 配置）
/// 依赖 Provider：CardProvider（加载文件时使用）
///
/// 设计特点：
/// - 简洁的布局，突出核心操作
/// - 使用 ConsumerStatefulWidget 支持 Android 返回键双击退出
/// - 拖拽功能仅 Windows 桌面端启用，移动端隐藏
///
/// 使用场景：
/// 1. 应用启动后显示此页面
/// 2. 用户点击"新建知识卡片" → 导航到 EditorScreen
/// 3. 用户点击"打开知识卡片" → 选择 .straw 文件 → 导航到 ReaderScreen
/// 4. 用户拖入 .straw 文件 → 解析后导航到 ReaderScreen
class HomeScreen extends ConsumerStatefulWidget {
  /// 创建首页实例
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with WidgetsBindingObserver {
  /// 上次按返回键的时间，用于双击退出逻辑
  DateTime? _lastBackPress;

  /// 软件版本号
  String _version = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clean up any residual temp files from previous sessions
    TempFileManager.cleanAll();
    _loadVersion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 在应用分离时清理临时文件（包含敏感解密数据）
    if (state == AppLifecycleState.detached) {
      TempFileManager.cleanAll();
    }
  }

  /// 加载软件版本号
  Future<void> _loadVersion() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      if (mounted) {
        setState(() {
          _version = 'v${packageInfo.version}';
        });
      }
    } on Exception catch (_) {
      // 忽略错误，版本号显示为空
    }
  }

  /// 处理 Android 返回键：双击退出应用
  Future<bool> _handleBack() async {
    final now = DateTime.now();
    if (_lastBackPress != null &&
        now.difference(_lastBackPress!) < const Duration(seconds: 2)) {
      return true; // Exit app
    }
    _lastBackPress = now;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('再次点击返回键退出应用'),
          duration: Duration(seconds: 2),
        ),
      );
    }
    return false; // Don't exit yet
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    final horizontalPadding = getHorizontalPadding(screenWidth);
    final tokens = NeumorphicTokens.ofContext(context);

    return PopScope(
      canPop: !isAndroid(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!isAndroid()) {
          if (context.canPop()) {
            context.pop();
          } else {
            await SystemNavigator.pop();
          }
          return;
        }
        final shouldExit = await _handleBack();
        if (shouldExit) {
          await SystemNavigator.pop();
        }
      },
      child: Scaffold(
        backgroundColor: tokens.surface,
        appBar: _buildSoftAppBar(context, tokens),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: tokens.spaceXl,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: 480,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),
                      // 应用 Logo：凸起圆形软质容器 + 应用图标（PNG 资源）
                      _buildLogo(tokens),
                      SizedBox(height: tokens.spaceXl),
                      // 欢迎标题
                      Text(
                        '欢迎使用 StrawHut',
                        style: Theme.of(context).textTheme.displaySmall,
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: tokens.spaceSm),
                      Text(
                        '创建加密知识卡片，安全分享你的知识',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: tokens.textSecondary,
                            ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: tokens.spaceXxl),
                      // 核心操作按钮组
                      const ActionButtons(),
                      SizedBox(height: tokens.spaceXl),
                      // 桌面端拖拽区域
                      const DropZone(),
                      // Android 分享提示
                      if (defaultTargetPlatform ==
                          TargetPlatform.android) ...[
                        SizedBox(height: tokens.spaceMd),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            '您也可以从其他应用分享文件到 StrawHut 打开',
                            textAlign: TextAlign.center,
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: tokens.textHint,
                                      fontStyle: FontStyle.italic,
                                    ),
                          ),
                        ),
                      ],
                      SizedBox(height: tokens.spaceLg),
                      // 版本号
                      if (_version.isNotEmpty)
                        Text(
                          _version,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: tokens.textHint,
                                  ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  /// 构建浮动软质应用栏
  ///
  /// 透明背景 + 凸起胶囊容器包裹标题与操作按钮，
  /// 悬浮于页面内容之上，无下边线。
  PreferredSize _buildSoftAppBar(
    BuildContext context,
    NeumorphicTokens tokens,
  ) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight + 16),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              // 左侧：品牌标识（凸起圆形软质图标）
              NeumorphicIconButton(
                icon: StrawIcons.lock,
                color: tokens.inkPrimary,
              ),
              const SizedBox(width: 12),
              // 标题
              Expanded(
                child: Text(
                  'StrawHut · 草棚',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: tokens.textPrimary,
                  ),
                ),
              ),
              // 右侧：暗号保险库
              NeumorphicIconButton(
                icon: StrawIcons.password,
                tooltip: '暗号保险库',
                onPressed: () => PassphraseVaultDialog.show(context),
              ),
              const SizedBox(width: 12),
              // 右侧：帮助（使用教程）
              NeumorphicIconButton(
                icon: StrawIcons.help,
                tooltip: '使用教程',
                onPressed: () => _showHelpDialog(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 构建应用 Logo（凸起圆形软质容器 + 应用图标 PNG 资源）
  Widget _buildLogo(NeumorphicTokens tokens) {
    return Center(
      child: NeumorphicContainer(
        intensity: NeumorphicIntensity.strong,
        borderRadius: 60,
        width: 120,
        height: 120,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(12),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(48),
          child: Image.asset(
            'assets/icons/app_icon.png',
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }

  /// 显示使用教程对话框
  void _showHelpDialog(BuildContext context) {
    if (shouldUseMobileDialog()) {
      showDialog<void>(
        context: context,
        builder: (context) => const HelpDialog(),
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (context) => const HelpDialog(),
      );
    }
  }
}
