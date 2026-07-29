/// 草稿管理器接口
///
/// 定义内存草稿管理的契约。草稿功能用于在编辑过程中自动保存内容，
/// 防止意外丢失编辑进度。
///
/// 设计原则：
/// - 纯内存存储，不写入磁盘
/// - 单次会话有效，应用关闭后自动清空（由 Dart GC 处理）
/// - 可主动清除（发布完成后调用 clearDraft）
///
/// 架构位置：核心服务层（Core Service Layer）
/// 被依赖方：EditorProvider（编辑器状态管理）
abstract class IDraftManager {
  /// 保存内容到内存草稿
  ///
  /// 将编辑器当前内容的 Delta JSON 字符串保存到内存变量中。
  /// 每次编辑都会调用此方法，覆盖之前的草稿内容。
  ///
  /// 参数：[deltaJson] - Quill 编辑器的 Delta JSON 字符串
  void saveToDraft(String deltaJson);

  /// 从内存草稿读取内容
  ///
  /// 返回最近保存的草稿内容。如果没有草稿，返回 null。
  ///
  /// 返回值：Delta JSON 字符串，或 null（无草稿时）
  String? loadFromDraft();

  /// 清除内存草稿
  ///
  /// 将草稿内容置 null，释放引用。
  /// 通常在以下情况调用：
  /// - 用户发布卡片成功后
  /// - 用户主动清除草稿
  /// - 新建空白文档时
  void clearDraft();

  /// 检查是否存在草稿
  ///
  /// 返回 true 表示有未发布的草稿内容。
  /// 用于在用户重新打开编辑器时提示"是否恢复上次编辑的内容"。
  ///
  /// 返回值：true = 有草稿，false = 无草稿
  bool hasDraft();
}

/// 草稿管理器实现
///
/// 实现 [IDraftManager] 接口，使用简单的内存变量存储草稿。
///
/// 设计特点：
/// - 使用私有变量 _draftContent 保存 Delta JSON 字符串
/// - 不依赖任何持久化存储，符合 StrawHut "零持久化" 原则
/// - 应用关闭后，变量随 Dart VM 销毁而自动清空
///
/// 使用场景：
/// 1. 用户在编辑器中输入内容 → EditorProvider 监听变化
/// 2. EditorProvider 调用 saveToDraft 保存当前内容
/// 3. 用户意外关闭编辑器页面
/// 4. 重新打开编辑器时，调用 hasDraft 检查 + loadFromDraft 恢复
/// 5. 用户发布成功后，调用 clearDraft 清除草稿
///
/// 内存安全说明：
/// - 草稿内容不包含密钥等敏感数据，仅为明文 Delta JSON
/// - 清除时直接置 null，等待 GC 回收
class DraftManager implements IDraftManager {
  /// 内存中的草稿内容（Delta JSON 字符串）
  ///
  /// 私有变量，外部无法直接访问，只能通过接口方法操作。
  String? _draftContent;

  /// 保存内容到内存草稿
  ///
  /// 实现说明：直接将参数赋值给 _draftContent。
  /// 每次调用会覆盖之前的草稿，不保留历史记录。
  ///
  /// 性能：O(1)，仅引用赋值
  @override
  void saveToDraft(String deltaJson) {
    _draftContent = deltaJson;
  }

  /// 从内存草稿读取内容
  ///
  /// 实现说明：返回 _draftContent，无草稿时为 null。
  ///
  /// 性能：O(1)
  @override
  String? loadFromDraft() {
    return _draftContent;
  }

  /// 清除内存草稿
  ///
  /// 实现说明：将 _draftContent 置 null，释放引用。
  /// Dart GC 会在适当时机回收原字符串占用的内存。
  ///
  /// 性能：O(1)
  @override
  void clearDraft() {
    _draftContent = null;
  }

  /// 检查是否存在草稿
  ///
  /// 实现说明：检查 _draftContent 是否非 null 且非空字符串。
  /// 空字符串不被视为有效草稿。
  ///
  /// 性能：O(1)
  @override
  bool hasDraft() {
    return _draftContent != null && _draftContent!.isNotEmpty;
  }
}
