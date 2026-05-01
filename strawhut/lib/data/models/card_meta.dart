/// 卡片元数据模型
class CardMeta {
  final String publisherAlias;
  final String publishDate;
  final String title;
  final List<String> tags;
  final String? description;
  final bool isAnonymous;
  final Map<String, dynamic>? customAnnotations;

  const CardMeta({
    required this.publisherAlias,
    required this.publishDate,
    required this.title,
    this.tags = const [],
    this.description,
    required this.isAnonymous,
    this.customAnnotations,
  });

  Map<String, dynamic> toJson() => {
    'publisher_alias': publisherAlias,
    'publish_date': publishDate,
    'title': title,
    'tags': tags,
    if (description != null) 'description': description,
    'is_anonymous': isAnonymous,
    if (customAnnotations != null) 'custom_annotations': customAnnotations,
  };

  factory CardMeta.fromJson(Map<String, dynamic> json) {
    return CardMeta(
      publisherAlias: json['publisher_alias'] as String,
      publishDate: json['publish_date'] as String,
      title: json['title'] as String,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      description: json['description'] as String?,
      isAnonymous: json['is_anonymous'] as bool,
      customAnnotations: json['custom_annotations'] as Map<String, dynamic>?,
    );
  }
}
