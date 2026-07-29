import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:strawhut/presentation/providers/crypto_provider.dart';
part 'editor_provider.g.dart';

/// 编辑器内容 Provider
///
/// 使用 Riverpod 的 @Riverpod 注解定义，用于管理 EditorScreen 中
/// 当前编辑器的 Delta JSON 内容。
///
/// 架构位置：应用层 → Riverpod Provider
/// 状态类型：String（Delta JSON 格式）
/// keepAlive: true（确保无 watcher 时状态不丢失，页面销毁时需手动清理）
///
/// 使用场景：
/// - EditorScreen 监听编辑器内容变化时调用 updateContent
/// - 编辑器恢复草稿时调用 loadFromDraft
/// - 新建空白文档时调用 clear
///
/// 数据流：
/// 1. 用户输入文本 → QuillEditor.onChanged 触发
/// 2. 获取 Delta JSON 字符串
/// 3. 调用 updateContent(deltaJson) 更新 Provider 状态
/// 4. 同时调用 DraftManager.saveToDraft 保存草稿
///
/// 使用示例：
/// ```dart
/// // 更新内容
/// ref.read(editorContentProvider.notifier).updateContent(deltaJson);
/// // 监听内容
/// final content = ref.watch(editorContentProvider);
/// ```
@Riverpod(keepAlive: true)
class EditorContent extends _$EditorContent {
  /// 初始状态：空字符串表示编辑器无内容
  @override
  String build() {
    return '';
  }

  /// 更新编辑器内容
  ///
  /// 当用户在 Quill 编辑器中输入或修改内容时调用。
  /// 该方法同时会更新 Provider 状态并保存到内存草稿，
  /// 确保用户关闭编辑器后重新打开时能够恢复上次编辑的内容。
  ///
  /// 参数：[deltaJson] - 当前编辑器内容的 Delta JSON 字符串
  void updateContent(String deltaJson) {
    state = deltaJson;
    // 同步保存到草稿管理器，确保内容不丢失
    ref.read(draftManagerProvider).saveToDraft(deltaJson);
  }

  /// 从草稿加载内容
  ///
  /// 恢复上次编辑的草稿内容到编辑器。
  /// 从 DraftManager 读取草稿数据，如果存在草稿则更新 Provider 状态。
  ///
  /// 使用场景：
  /// - 用户重新打开编辑器时自动恢复上次编辑的内容
  /// - 应用会话期间（未关闭）草稿一直保留
  void loadFromDraft() {
    final draft = ref.read(draftManagerProvider).loadFromDraft();
    if (draft != null) {
      state = draft;
    }
  }

  /// 清空编辑器内容
  ///
  /// 将状态重置为空字符串，并同时清空内存草稿。
  /// 通常用于：
  /// - 发布成功后清空编辑器和草稿
  /// - 用户点击"新建文档"时重置状态
  void clear() {
    state = '';
    // 同步清空草稿，确保下次打开编辑器时是空白状态
    ref.read(draftManagerProvider).clearDraft();
  }
}
