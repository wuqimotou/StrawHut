import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// Android Intent 处理器
///
/// 负责接收来自外部应用分享的文件（.straw / .png）。
/// 使用 receive_sharing_intent 包监听 Android Intent。
///
/// 使用场景：
/// - 应用运行时接收分享的文件（通过 getMediaStream）
/// - 应用通过 Intent 启动时获取初始分享文件（通过 getInitialMedia）
///
/// 架构位置：核心服务层 -> 平台桥接层
class IntentHandler {
  static final IntentHandler _instance = IntentHandler._internal();

  /// 获取 IntentHandler 单例实例
  factory IntentHandler() => _instance;

  IntentHandler._internal();

  /// 广播流，用于分发接收到的共享文件列表
  final _sharedFilesController = StreamController<List<SharedMediaFile>>.broadcast();

  /// 共享文件流，供外部监听
  Stream<List<SharedMediaFile>> get sharedFilesStream => _sharedFilesController.stream;

  StreamSubscription<List<SharedMediaFile>>? _mediaSubscription;

  /// 初始共享文件（应用通过 Intent 启动时获取）
  List<SharedMediaFile>? _initialFiles;

  /// 是否已初始化
  bool _isInitialized = false;

  /// 初始化 Intent 处理器
  ///
  /// 必须在应用启动后调用，且必须在 BuildContext 可用之后。
  /// 该方法应只调用一次。
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 监听应用运行时接收到的共享文件
    _mediaSubscription = ReceiveSharingIntent.instance.getMediaStream().listen(
      (List<SharedMediaFile> files) {
        if (files.isNotEmpty) {
          debugPrint('IntentHandler: Received ${files.length} shared file(s) while running');
          _sharedFilesController.add(files);
        }
      },
      onError: (Object err) {
        debugPrint('IntentHandler: Stream error: $err');
      },
    );

    // 获取应用通过 Intent 启动时的初始共享文件
    _initialFiles = await ReceiveSharingIntent.instance.getInitialMedia();
    if (_initialFiles != null && _initialFiles!.isNotEmpty) {
      debugPrint('IntentHandler: Got ${_initialFiles!.length} initial shared file(s)');
    }

    _isInitialized = true;
  }

  /// 获取并消费初始共享文件（仅调用一次）
  ///
  /// 返回初始共享文件列表并清空内部缓存，确保不会重复消费。
  List<SharedMediaFile>? consumeInitialFiles() {
    final files = _initialFiles;
    _initialFiles = null;
    return files;
  }

  /// 读取共享文件的字节数据
  ///
  /// 处理 file:// 和 content:// 两种 URI 格式。
  /// 对于 content:// URI，尝试直接通过文件路径读取（某些文件管理器会提供实际路径）。
  Future<Uint8List?> readFileBytes(SharedMediaFile file) async {
    try {
      final path = file.path;

      if (path.startsWith('content://')) {
        // content:// URI 无法直接通过 dart:io 读取。
        // receive_sharing_intent 在某些情况下会解析出实际文件路径。
        // 对于纯 content:// URI，需要在调用方使用 file_picker 的字节流 API 处理。
        debugPrint('IntentHandler: content:// URI detected, path-level read not supported: $path');
        return null;
      }

      // file:// 或普通文件路径
      final fileObj = File(path);
      if (await fileObj.exists()) {
        return await fileObj.readAsBytes();
      }

      debugPrint('IntentHandler: File does not exist: $path');
      return null;
    } catch (e) {
      debugPrint('IntentHandler: Error reading shared file bytes: $e');
      return null;
    }
  }

  /// 获取共享文件的文件名
  String getFileName(SharedMediaFile file) {
    final path = file.path;
    final segments = path.split('/');
    return segments.last;
  }

  /// 释放资源
  void dispose() {
    _mediaSubscription?.cancel();
    _sharedFilesController.close();
    _isInitialized = false;
  }
}
