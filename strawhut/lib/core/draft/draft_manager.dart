/// 草稿管理器接口
abstract class IDraftManager {
  void saveToDraft(String deltaJson);
  String? loadFromDraft();
  void clearDraft();
  bool hasDraft();
}

/// 草稿管理器实现（Phase 0 占位实现）
class DraftManager implements IDraftManager {
  @override
  void saveToDraft(String deltaJson) {
    // TODO: 实现真实的草稿保存
    throw UnimplementedError('DraftManager.saveToDraft 尚未实现');
  }

  @override
  String? loadFromDraft() {
    // TODO: 实现真实的草稿加载
    throw UnimplementedError('DraftManager.loadFromDraft 尚未实现');
  }

  @override
  void clearDraft() {
    // TODO: 实现真实的草稿清除
    throw UnimplementedError('DraftManager.clearDraft 尚未实现');
  }

  @override
  bool hasDraft() {
    // TODO: 实现真实的草稿检查
    throw UnimplementedError('DraftManager.hasDraft 尚未实现');
  }
}
