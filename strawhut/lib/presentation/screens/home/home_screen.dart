import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';
import 'package:strawhut/presentation/screens/home/widgets/help_dialog.dart';
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

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// 上次按返回键的时间，用于双击退出逻辑
  DateTime? _lastBackPress;

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

    return PopScope(
      canPop: !isAndroid(),
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (!isAndroid()) {
          // Non-mobile: just pop
          if (context.canPop()) {
            context.pop();
          } else {
            SystemNavigator.pop();
          }
          return;
        }
        final shouldExit = await _handleBack();
        if (shouldExit) {
          SystemNavigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('StrawHut - 草棚'),
          centerTitle: true,
          actions: [
            // 帮助按钮
            IconButton(
              icon: const Icon(Icons.help_outline),
              onPressed: () => _showHelpDialog(context),
              tooltip: '使用教程',
            ),
          ],
        ),
        body: LayoutBuilder(
          builder: (context, constraints) {
            return Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: horizontalPadding,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 32),
                    // 应用 Logo 区域：显示大号加密锁图标
                    const Icon(
                      Icons.lock_outline_rounded,
                      size: 80,
                      color: Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    // 欢迎文字说明：引导用户操作
                    Text(
                      '欢迎使用 StrawHut',
                      style: Theme.of(context).textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '创建加密知识卡片，安全分享你的知识',
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // 核心操作按钮组：新建和打开卡片
                    const ActionButtons(),
                    const SizedBox(height: 32),
                    // 桌面端拖拽区域：仅 Windows 桌面端显示
                    // 移动端自动隐藏（通过 DropZone 内部条件判断）
                    const DropZone(),
                    // On Android, show a hint text about receiving shared files
                    if (defaultTargetPlatform == TargetPlatform.android) ...[
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '您也可以从其他应用分享文件到 StrawHut 打开',
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: Colors.grey[500],
                                    fontStyle: FontStyle.italic,
                                  ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            );
          },
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
