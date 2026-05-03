import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:strawhut/app/app.dart';

/// StrawHut 应用入口点
///
/// 应用程序的启动函数，负责：
/// 1. 初始化 Flutter 框架
/// 2. 配置全局错误捕获机制
/// 3. 使用 ProviderScope 包裹应用以提供 Riverpod 状态管理
/// 4. 调用 runApp 启动 StrawHutApp
///
/// 生命周期：
/// 1. 操作系统启动此 Dart 程序
/// 2. main() 函数执行
/// 3. WidgetsFlutterBinding.ensureInitialized() 确保框架就绪
/// 4. 配置全局错误捕获（FlutterError.onError 等）
/// 5. ProviderScope 包裹应用根 Widget
/// 6. runApp 启动 StrawHutApp
/// 7. MaterialApp 通过 go_router 导航到 HomeScreen
///
/// 错误处理策略：
/// - FlutterError.onError：捕获 Flutter 框架层面的错误（如渲染错误）
/// - PlatformDispatcher.instance.onError：捕获 Dart 异步操作中的未处理错误
/// - 错误信息通过 debugPrint 输出，便于开发调试
/// - 生产环境可集成日志上报服务（如 Sentry、Firebase Crashlytics）
void main() {
  // 确保 Flutter 框架已初始化
  // 必须在调用任何 Flutter 相关 API 之前执行
  WidgetsFlutterBinding.ensureInitialized();

  // 配置 Flutter 框架层面的错误捕获
  // 用于捕获渲染过程中的异常、Widget 构建错误等
  FlutterError.onError = (FlutterErrorDetails details) {
    // 开发模式下直接输出错误信息
    FlutterError.presentError(details);

    // TODO: 生产环境可替换为日志上报服务
    // 例如：Sentry.captureException(details.exception, stackTrace: details.stack);
    debugPrint('Flutter 框架错误: ${details.exception}');
    debugPrint('错误堆栈: ${details.stack}');
  };

  // 配置 Dart 平台层面的未捕获错误处理
  // 用于捕获异步操作（Future、async/await）中的未处理异常
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    // 输出错误信息到调试控制台
    debugPrint('平台未捕获错误: $error');
    debugPrint('错误堆栈: $stack');

    // TODO: 生产环境可替换为日志上报服务
    // 返回 true 表示错误已处理，阻止应用崩溃
    return true;
  };

  // 启动应用
  // 使用 ProviderScope 包裹 StrawHutApp 以启用 Riverpod 状态管理
  // ProviderScope 是 Riverpod 的根 Widget，负责管理所有 Provider 的生命周期
  runApp(
    const ProviderScope(
      child: StrawHutApp(),
    ),
  );
}
