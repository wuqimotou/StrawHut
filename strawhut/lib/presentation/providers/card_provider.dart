import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/data/models/parsed_straw_file.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
part 'card_provider.g.dart';

/// 当前加载的知识卡片 Provider
///
/// 使用 Riverpod 的 @Riverpod 注解定义，用于管理 ReaderScreen 中
/// 当前正在查看的知识卡片文件状态。
///
/// 架构位置：应用层 - Riverpod Provider
/// 状态类型：AsyncValue<ParsedStrawFile?>（异步数据流，支持 loading/success/error 状态）
/// keepAlive: false（页面销毁后自动清空，不保留缓存）
///
/// 使用场景：
/// - HomeScreen 用户选择 .straw 文件后调用 loadFile
/// - ReaderScreen 读取当前卡片数据展示元数据和内容
///
/// 使用示例：
/// ```dart
/// // 加载文件
/// await ref.read(currentCardProvider.notifier).loadFile(filePath);
/// // 读取状态
/// final cardAsync = ref.watch(currentCardProvider);
/// cardAsync.when(
///   data: (parsed) => showMeta(parsed?.strawFile),
///   loading: () => showLoading(),
///   error: (e, st) => showError(e),
/// );
/// ```
@Riverpod(keepAlive: false)
class CurrentCard extends _$CurrentCard {
  /// 初始状态：返回 null 表示尚未加载任何文件
  @override
  AsyncValue<ParsedStrawFile?> build() {
    return const AsyncValue.data(null);
  }

  /// 流式加载知识卡片文件头部（不加载分块数据）
  ///
  /// 只读取文件头部信息，不将加密分块加载到内存。
  /// 适用于大文件场景，解密时需使用 decryptStream()。
  ///
  /// 参数：[filePath] - .straw 或 .png 文件的完整路径
  Future<ParsedStrawFile?> loadFileHeader(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final extension = filePath.split('.').last.toLowerCase();
      final fileIOService = ref.read(fileIOServiceProvider);
      final parsedFile = extension == 'png'
          ? await fileIOService.readStrawPng(filePath) // PNG 仍全量加载
          : await fileIOService.readStrawFileHeader(filePath); // .straw 流式加载
      state = AsyncValue.data(parsedFile);
      return parsedFile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 加载知识卡片文件
  ///
  /// 从文件系统读取 .straw 文件并更新状态。
  ///
  /// 流程：
  /// 1. 设置状态为 loading
  /// 2. 调用 FileIOService.readStrawFile/readStrawPng 读取文件
  /// 3. 成功 - 更新 state 为 AsyncValue.data(parsedFile)
  /// 4. 失败 - 更新 state 为 AsyncValue.error(e, st)
  ///
  /// 参数：[filePath] - .straw 文件的完整路径
  Future<ParsedStrawFile?> loadFile(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final extension = filePath.split('.').last.toLowerCase();
      final fileIOService = ref.read(fileIOServiceProvider);
      final parsedFile = extension == 'png'
          ? await fileIOService.readStrawPng(filePath)
          : await fileIOService.readStrawFile(filePath);
      state = AsyncValue.data(parsedFile);
      return parsedFile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  /// 从字节数据加载知识卡片文件（Android content:// URI 支持）
  ///
  /// 从字节数据读取文件并更新状态。
  ///
  /// 流程：
  /// 1. 设置状态为 loading
  /// 2. 根据文件名判断是否为 PNG 文件
  /// 3. 调用 FileIOService.readStrawFileFromBytes 或 readStrawPngFromBytes
  /// 4. 成功 - 更新 state 为 AsyncValue.data(parsedFile)
  /// 5. 失败 - 更新 state 为 AsyncValue.error(e, st)
  ///
  /// 参数：
  /// - [bytes] - 文件字节数据
  /// - [fileName] - 文件名（用于判断文件类型）
  Future<ParsedStrawFile?> loadFileFromBytes(
    Uint8List bytes, {
    String? fileName,
  }) async {
    state = const AsyncValue.loading();
    try {
      final fileIOService = ref.read(fileIOServiceProvider);
      final isPng = fileName?.toLowerCase().endsWith('.png') ?? false;
      final parsedFile = isPng
          ? await fileIOService.readStrawPngFromBytes(bytes)
          : await fileIOService.readStrawFileFromBytes(bytes);
      state = AsyncValue.data(parsedFile);
      return parsedFile;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}

/// Provider for pending file bytes from file selection.
///
/// Used to pass file bytes from the file picker to the reader screen,
/// especially for Android content:// URIs where path-based access is not available.
final pendingFileBytesProvider =
    StateProvider<(Uint8List, String)?>((_) => null);
