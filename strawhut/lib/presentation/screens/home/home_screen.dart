import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strawhut/presentation/screens/home/widgets/action_buttons.dart';
import 'package:strawhut/presentation/screens/home/widgets/drop_zone.dart';

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
/// - 使用 ConsumerWidget 订阅 Riverpod 状态
/// - 拖拽功能仅 Windows 桌面端启用，移动端隐藏
///
/// 使用场景：
/// 1. 应用启动后显示此页面
/// 2. 用户点击"新建知识卡片" → 导航到 EditorScreen
/// 3. 用户点击"打开知识卡片" → 选择 .straw 文件 → 导航到 ReaderScreen
/// 4. 用户拖入 .straw 文件 → 解析后导航到 ReaderScreen
class HomeScreen extends ConsumerWidget {
  /// 创建首页实例
  const HomeScreen({super.key});

  /// 构建首页 UI
  ///
  /// 布局结构：
  /// - Scaffold：页面容器
  /// - AppBar：应用标题 "StrawHut - 去中心化加密知识分享平台"
  /// - Body：居中布局，包含操作按钮组和拖拽区域
  ///   - Column 垂直排列：
  ///     1. 应用 Logo 图标（大号加密锁图标）
  ///     2. 欢迎文字说明
  ///     3. ActionButtons（操作按钮组）
  ///     4. DropZone（拖拽区域，仅桌面端显示）
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('StrawHut - 草棚'),
        centerTitle: true,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 600,
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
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Colors.grey[600],
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    // 核心操作按钮组：新建和打开卡片
                    const ActionButtons(),
                    const SizedBox(height: 32),
                    // 桌面端拖拽区域：仅 Windows 桌面端显示
                    // 移动端自动隐藏（通过条件判断）
                    const DropZone(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
