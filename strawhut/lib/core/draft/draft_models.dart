/// 草稿相关模型
class DraftInfo {
  final String content;
  final DateTime lastModified;

  const DraftInfo({
    required this.content,
    required this.lastModified,
  });
}
