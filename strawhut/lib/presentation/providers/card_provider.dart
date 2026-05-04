import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/data/models/straw_file.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
part 'card_provider.g.dart';

/// 当前加载的知识卡片 Provider
///
/// 使用 Riverpod 的 @Riverpod 注解定义，用于管理 ReaderScreen 中
/// 当前正在查看的知识卡片文件状态。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：AsyncValue<StrawFile?>（异步数据流，支持 loading/success/error 状态）
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
///   data: (strawFile) => showMeta(strawFile),
///   loading: () => showLoading(),
///   error: (e, st) => showError(e),
/// );
/// ```
@Riverpod(keepAlive: false)
class CurrentCard extends _$CurrentCard {
  /// 初始状态：返回 null 表示尚未加载任何文件
  @override
  AsyncValue<StrawFile?> build() {
    return const AsyncValue.data(null);
  }

  /// 加载知识卡片文件
  ///
  /// 从文件系统读取 .straw 文件并更新状态。
  ///
  /// 流程：
  /// 1. 设置状态为 loading
  /// 2. 调用 FileIOService.readStrawFile 读取文件
  /// 3. 成功 → 更新 state 为 AsyncValue.data(file)
  /// 4. 失败 → 更新 state 为 AsyncValue.error(e, st)
  ///
  /// 参数：[filePath] - .straw 文件的完整路径
  Future<StrawFile?> loadFile(String filePath) async {
    state = const AsyncValue.loading();
    try {
      final extension = filePath.split('.').last.toLowerCase();
      final fileIOService = ref.read(fileIOServiceProvider);
      final file = extension == 'png'
          ? await fileIOService.readStrawPng(filePath)
          : await fileIOService.readStrawFile(filePath);
      state = AsyncValue.data(file);
      return file;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }
}
