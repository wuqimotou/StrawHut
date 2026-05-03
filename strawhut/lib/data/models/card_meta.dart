import 'package:flutter/foundation.dart';

/// 卡片元数据模型
///
/// 封装 .straw 知识卡片的公开可见元数据（未加密）。
/// 对应 .straw 文件中 `meta` 对象的结构。
///
/// 字段说明：
/// - [publisherAlias]: 发布者代号，匿名模式下为 "Anonymous_xxxx"
/// - [publishDate]: 发布日期（ISO 8601 UTC 格式）
/// - [title]: 知识卡片标题（必填）
/// - [tags]: 标签列表（可选，最多 10 个，每个最多 20 字符）
/// - [description]: 简要描述（可选，最多 200 字符）
/// - [isAnonymous]: 是否为纯匿名模式
/// - [customAnnotations]: 自定义键值对标注（可选）
///
/// 设计特点：
/// - 不可变对象（所有字段为 final）
/// - 提供 fromJson/toJson 用于文件序列化和反序列化
///
/// .straw 文件中 meta 对象示例：
/// ```json
/// {
///   "publisher_alias": "Anonymous",
///   "publish_date": "2026-05-01T12:00:00Z",
///   "title": "网络安全入门指南",
///   "tags": ["安全", "入门", "笔记"],
///   "description": "一份关于网络安全基础知识的入门笔记",
///   "is_anonymous": true,
///   "custom_annotations": {}
/// }
/// ```
@immutable
class CardMeta {
  /// 创建卡片元数据实例
  ///
  /// 参数说明：
  /// - [publisherAlias]: 发布者代号，必填
  /// - [publishDate]: 发布日期，必填
  /// - [title]: 标题，必填
  /// - [isAnonymous]: 是否匿名，必填
  /// - [tags]: 标签列表，可选，默认为空
  /// - [description]: 描述，可选
  /// - [customAnnotations]: 自定义标注，可选
  const CardMeta({
    required this.publisherAlias,
    required this.publishDate,
    required this.title,
    required this.isAnonymous,
    this.tags = const [],
    this.description,
    this.customAnnotations,
  });

  /// 从 JSON 映射反序列化元数据
  ///
  /// 参数：[json] - .straw 文件中的 `meta` 对象
  /// 返回：解析后的 CardMeta 实例
  ///
  /// 注意事项：
  /// - tags 字段不存在时默认为空列表
  /// - 必填字段缺失时会抛出类型转换异常
  factory CardMeta.fromJson(Map<String, dynamic> json) {
    return CardMeta(
      publisherAlias: json['publisher_alias'] as String,
      publishDate: json['publish_date'] as String,
      title: json['title'] as String,
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ??
              [],
      description: json['description'] as String?,
      isAnonymous: json['is_anonymous'] as bool,
      customAnnotations: json['custom_annotations'] as Map<String, dynamic>?,
    );
  }

  /// 发布者代号
  ///
  /// 非匿名模式下由用户手动输入。
  /// 匿名模式下由系统自动生成，固定为 "Anonymous"。
  /// 示例："Alice"、"Anonymous"
  final String publisherAlias;

  /// 发布日期（ISO 8601 UTC 格式）
  ///
  /// 卡片发布时的 UTC 时间戳，使用 ISO 8601 标准格式。
  /// 示例："2026-05-01T12:00:00Z"
  ///
  /// 注意：即使在匿名模式下也会记录发布日期，
  /// 因为这是卡片的自然属性，不会泄露用户身份。
  final String publishDate;

  /// 知识卡片标题
  ///
  /// 必填字段，用于在阅读器中展示和识别卡片。
  /// 发布对话框中自动填充当前编辑器内容的首行文本。
  final String title;

  /// 标签列表
  ///
  /// 可选字段，用于分类和检索知识卡片。
  /// 限制：
  /// - 最多 10 个标签（MAX_TAGS_COUNT）
  /// - 每个标签最长 20 字符（MAX_TAG_LENGTH）
  ///
  /// 默认值为空列表 []。
  final List<String> tags;

  /// 简要描述
  ///
  /// 可选字段，用于未解密状态下帮助用户识别卡片内容。
  /// 最长 200 字符（MAX_DESCRIPTION_LENGTH）。
  ///
  /// 注意：描述内容未加密，任何人打开 .straw 文件都能看到。
  final String? description;

  /// 是否为纯匿名模式
  ///
  /// true 表示发布者使用匿名身份发布，
  /// publisher_alias 由系统自动生成（Anonymous_xxxx）。
  ///
  /// false 表示发布者使用自定义代号。
  final bool isAnonymous;

  /// 自定义键值对标注
  ///
  /// 可选字段，允许用户添加额外的键值对信息。
  /// 限制：
  /// - 键最长 50 字符
  /// - 值最长 500 字符
  ///
  /// 匿名模式下应过滤可能暴露身份的信息。
  final Map<String, dynamic>? customAnnotations;

  /// 判断两个 CardMeta 对象是否相等
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CardMeta &&
          runtimeType == other.runtimeType &&
          publisherAlias == other.publisherAlias &&
          publishDate == other.publishDate &&
          title == other.title &&
          isAnonymous == other.isAnonymous &&
          _listEquals(tags, other.tags) &&
          description == other.description &&
          _mapEquals(customAnnotations, other.customAnnotations);

  static bool _listEquals(List<String>? a, List<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  static bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  /// 计算 CardMeta 对象的哈希值
  @override
  int get hashCode => Object.hash(
        publisherAlias,
        publishDate,
        title,
        isAnonymous,
        Object.hashAll(tags),
        description,
        customAnnotations != null ? _mapHash(customAnnotations!) : 0,
      );

  static int _mapHash(Map<String, dynamic> map) {
    var hash = 0;
    for (final entry in map.entries) {
      hash = hash ^ Object.hash(entry.key, entry.value);
    }
    return hash;
  }

  /// 将元数据序列化为 JSON 映射
  ///
  /// 返回的 Map 可直接嵌入 .straw 文件的 `meta` 字段。
  /// 可选字段（description, customAnnotations）为 null 时不会出现在 JSON 中。
  Map<String, dynamic> toJson() => {
        'publisher_alias': publisherAlias,
        'publish_date': publishDate,
        'title': title,
        'tags': tags,
        if (description != null) 'description': description,
        'is_anonymous': isAnonymous,
        if (customAnnotations != null) 'custom_annotations': customAnnotations,
      };
}
