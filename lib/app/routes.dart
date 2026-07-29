import 'package:go_router/go_router.dart';

import 'package:flutter/material.dart';
import 'package:strawhut/presentation/screens/editor/editor_screen.dart';
import 'package:strawhut/presentation/screens/home/home_screen.dart';
import 'package:strawhut/presentation/screens/reader/reader_screen.dart';

/// 应用路由配置
///
/// 使用 go_router 包配置 StrawHut 的所有页面路由。
///
/// 路由列表：
/// - [/]            → HomeScreen    首页，应用启动后默认显示的路由，展示核心操作按钮
/// - [/editor]      → EditorScreen  编辑器页面，知识卡片编辑，提供富文本编辑功能
/// - [/reader]      → ReaderScreen  阅读器页面，展示解密后的知识内容，可接收文件路径参数
///
/// 架构位置：应用层 → 路由配置
/// 使用方式：
///   - 在 MaterialApp 中通过 routerConfig 参数传入
///   - 使用 context.go('/path') 进行路由跳转
///   - 使用 context.pop() 返回上一页
///
/// go_router 优势：
/// - 支持声明式路由，URL 与页面状态同步
/// - 支持浏览器 URL 管理（Web 平台）
/// - 支持深层链接和路径参数
/// - 更好的导航守卫和重定向能力

/// 获取 GoRouter 实例
///
/// 返回配置完整的 GoRouter 对象，供 MaterialApp 使用。
/// 在应用生命周期中只应创建一次，因此设计为 getter 返回新实例。
///
/// 使用示例：
/// ```dart
/// MaterialApp.router(
///   routerConfig: AppRouter.router,
///   ...
/// )
/// ```
final GoRouter appRouter = GoRouter(
  // 初始路由路径，应用启动后首先显示的页面
  initialLocation: '/',

  // 路由配置列表
  routes: <RouteBase>[
    /// 首页路由
    ///
    /// 路径：'/'
    /// 页面：HomeScreen
    /// 说明：应用入口页面，展示新建/打开知识卡片等操作按钮
    GoRoute(
      path: '/',
      name: 'home',
      builder: (BuildContext context, GoRouterState state) {
        return const HomeScreen();
      },
    ),

    /// 编辑器路由
    ///
    /// 路径：'/editor'
    /// 页面：EditorScreen
    /// 说明：知识卡片编辑页面，提供富文本编辑功能
    /// 使用场景：用户从首页点击"新建知识卡片"进入
    GoRoute(
      path: '/editor',
      name: 'editor',
      builder: (BuildContext context, GoRouterState state) {
        return const EditorScreen();
      },
    ),

    /// 阅读器路由
    ///
    /// 路径：'/reader'
    /// 页面：ReaderScreen
    /// 说明：知识卡片阅读页面，展示解密后的内容
    /// 路由参数：可通过 query 参数传入文件路径（如 /reader?path=xxx.straw）
    /// 使用场景：用户从首页选择文件后进入，或拖拽文件后进入
    GoRoute(
      path: '/reader',
      name: 'reader',
      builder: (BuildContext context, GoRouterState state) {
        return const ReaderScreen();
      },
    ),
  ],
);
