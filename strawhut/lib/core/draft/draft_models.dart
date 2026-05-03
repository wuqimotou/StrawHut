/// 草稿相关数据模型
///
/// 封装草稿的元信息，包含草稿内容和最后修改时间。
///
/// 注意：当前版本 DraftManager 仅保存内容字符串，
/// DraftInfo 模型为未来扩展预留（如多草稿管理、草稿列表展示等）。
///
/// 使用场景：
/// - 展示草稿列表时显示最后修改时间
/// - 判断草稿的新鲜度（是否需要自动清除）
class DraftInfo {
  /// 草稿内容（Delta JSON 字符串）
  ///
  /// Quill 编辑器的 Delta 格式，可直接用于恢复编辑状态。
  final String content;

  /// 草稿最后修改时间（UTC）
  ///
  /// 记录用户最后一次编辑内容的时间戳。
  /// 用于：
  /// - 草稿列表中按时间排序
  /// - 判断草稿是否过期（未来功能）
  final DateTime lastModified;

  /// 创建草稿信息实例
  ///
  /// 参数说明：
  /// - [content]: 草稿的 Delta JSON 内容，不能为 null
  /// - [lastModified]: 最后修改时间，通常使用 DateTime.now().toUtc()
  const DraftInfo({
    required this.content,
    required this.lastModified,
  });
}
