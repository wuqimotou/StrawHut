import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

import 'package:strawhut/app/routes.dart';
import 'package:strawhut/app/theme.dart';
import 'package:strawhut/core/platform/intent_handler.dart';
import 'package:strawhut/l10n/l10n.dart';
import 'package:strawhut/presentation/providers/card_provider.dart';
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
/// - 全局默认字体：跨平台中文字体支持
/// - Android Intent 处理：接收外部应用分享的文件
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
/// 4. 用户通过 context.go() 或 context.push() 进行路由跳转
class StrawHutApp extends ConsumerStatefulWidget {
  /// 创建应用主组件实例
  const StrawHutApp({super.key});

  @override
  ConsumerState<StrawHutApp> createState() => _StrawHutAppState();
}

class _StrawHutAppState extends ConsumerState<StrawHutApp>
    with WidgetsBindingObserver {
  late final IntentHandler _intentHandler;
  StreamSubscription<List<SharedMediaFile>>? _intentStreamSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _intentHandler = IntentHandler();

    // Initialize intent handling after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeIntentHandler();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _intentStreamSubscription?.cancel();
    _intentHandler.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Future: handle lifecycle events at app level if needed
  }

  Future<void> _initializeIntentHandler() async {
    if (!mounted) return;

    await _intentHandler.initialize();

    // Handle initial shared files (app launched via intent)
    final initialFiles = _intentHandler.consumeInitialFiles();
    if (initialFiles != null && initialFiles.isNotEmpty) {
      await _handleSharedFiles(initialFiles);
    }

    // Listen for files shared while app is running
    _intentStreamSubscription = _intentHandler.sharedFilesStream.listen((
      List<SharedMediaFile> files,
    ) {
      if (mounted) {
        _handleSharedFiles(files);
      }
    });
  }

  /// Handle shared files received via Android Intent
  Future<void> _handleSharedFiles(List<SharedMediaFile> files) async {
    if (files.isEmpty || !mounted) return;

    final file = files.first;
    final fileName = _intentHandler.getFileName(file);
    final bytes = await _intentHandler.readFileBytes(file);

    if (bytes == null) {
      debugPrint('StrawHutApp: Failed to read shared file bytes: ${file.path}');
      return;
    }

    // Store file bytes in pendingFileBytesProvider
    ref.read(pendingFileBytesProvider.notifier).state = (bytes, fileName);

    // Load the file into CurrentCard provider
    final cardNotifier = ref.read(currentCardProvider.notifier);
    await cardNotifier.loadFileFromBytes(bytes, fileName: fileName);

    // Navigate to reader screen
    if (mounted) {
      context.go('/reader');
      // Clear pending bytes after navigation
      ref.read(pendingFileBytesProvider.notifier).state = null;
    }
  }

  /// 构建全局字体回退列表
  ///
  /// 根据运行平台返回最合适的中文字体及其回退列表。
  static List<String> _getFontFallbacks() {
    switch (defaultTargetPlatform) {
      case TargetPlatform.windows:
        return ['Microsoft YaHei', 'PingFang SC', 'Noto Sans CJK SC'];
      case TargetPlatform.macOS:
      case TargetPlatform.iOS:
        return ['PingFang SC', 'Microsoft YaHei', 'Noto Sans CJK SC'];
      case TargetPlatform.android:
        return ['Noto Sans CJK SC', 'PingFang SC', 'Microsoft YaHei'];
      case TargetPlatform.linux:
        return ['Noto Sans CJK SC', 'PingFang SC', 'Microsoft YaHei'];
      case TargetPlatform.fuchsia:
        return ['PingFang SC', 'Microsoft YaHei'];
    }
  }

  /// 构建全局默认 TextStyle
  static TextStyle _globalTextStyle() {
    final fonts = _getFontFallbacks();
    return TextStyle(
      fontFamily: fonts.first,
      fontFamilyFallback: fonts.skip(1).toList(),
    );
  }

  /// 构建应用 UI
  ///
  /// 返回配置完整的 MaterialApp.router 实例。
  /// 使用 routerConfig 参数接入 go_router 路由系统。
  /// 使用 builder 包裹 DefaultTextStyle 确保全局字体统一。
  @override
  Widget build(BuildContext context) {
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
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],

      supportedLocales: AppLocalizations.supportedLocales,

      // 调试模式下显示的横幅（生产环境应隐藏）
      debugShowCheckedModeBanner: false,

      // 全局字体统一配置
      // 使用 builder 在所有 Material 组件外层包裹 DefaultTextStyle，
      // 确保所有组件（包括按钮、对话框、导航栏等）都使用统一的中文字体。
      builder: (context, child) {
        return DefaultTextStyle(style: _globalTextStyle(), child: child!);
      },
    );
  }
}
