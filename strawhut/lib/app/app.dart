import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:strawhut/app/routes.dart';
import 'package:strawhut/app/theme.dart';
import 'package:strawhut/presentation/providers/locale_provider.dart';
import 'package:strawhut/presentation/providers/theme_provider.dart';

/// StrawHut 应用主组件
///
/// 应用的根 Widget，配置全局主题、路由、国际化等核心功能。
///
/// 架构位置：应用层 → 应用入口
///
/// 配置内容：
/// - 应用标题：'StrawHut'
/// - 亮色主题：AppTheme.lightTheme（Material 3）
/// - 暗色主题：AppTheme.darkTheme（Material 3）
/// - 主题模式：ThemeMode.system（跟随系统自动切换）
/// - 路由配置：使用 go_router（appRouter）实现声明式路由
/// - 国际化：支持中英文本地化
///
/// 设计特点：
/// - 使用 MaterialApp.router 提供完整的路由支持
/// - 支持系统级亮色/暗色主题自动切换
/// - 集成 flutter_localizations 实现多语言支持
/// - 遵循 Material 3 设计规范
///
/// 生命周期：
/// 1. main.dart 初始化后调用 runApp(StrawHutApp())
/// 2. MaterialApp 使用 appRouter 导航到初始路由 '/'
/// 3. 显示 HomeScreen
/// 4. 用户通过 context.go() 或 context.push() 进行页面导航
class StrawHutApp extends ConsumerWidget {
  /// 创建应用主组件实例
  const StrawHutApp({super.key});

  /// 构建应用 UI
  ///
  /// 返回配置完整的 MaterialApp.router 实例。
  /// 使用 routerConfig 参数接入 go_router 路由系统。
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 监听 Provider 状态，主题/语言变化时自动重建 UI
    final themeMode = ref.watch(appThemeModeProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      // 应用标题，显示在操作系统任务栏和浏览器标签页
      title: 'StrawHut',

      // 亮色主题配置
      theme: AppTheme.lightTheme,

      // 暗色主题配置
      darkTheme: AppTheme.darkTheme,

      // 主题模式：由 Provider 动态管理，支持 system/light/dark
      themeMode: themeMode,

      // 动态绑定语言 Provider
      locale: locale,

      // go_router 路由配置
      // 使用声明式路由，URL 与页面状态保持同步
      routerConfig: appRouter,

      // 国际化本地化委托
      // 支持 Material 组件的本地化文本（如日期选择器、对话框按钮等）
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],

      // 支持的语言列表
      // 当前支持中文（简体、繁体）和英文
      supportedLocales: const [
        Locale('zh', 'CN'), // 简体中文
        Locale('zh', 'TW'), // 繁体中文
        Locale('en', ''), // 英文
      ],

      // 调试模式下显示的横幅（生产环境应隐藏）
      debugShowCheckedModeBanner: false,
    );
  }
}
