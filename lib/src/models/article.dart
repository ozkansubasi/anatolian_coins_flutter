/// Article model for blog content
class Article {
  final int id;
  final String title;
  final String? intro;
  final String? content;
  final String category;
  final int categoryId;
  final DateTime created;
  final DateTime? modified;

  const Article({
    required this.id,
    required this.title,
    this.intro,
    this.content,
    required this.category,
    required this.categoryId,
    required this.created,
    this.modified,
  });

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: json['id'] as int,
      title: json['title'] as String,
      intro: json['intro'] as String?,
      content: json['content'] as String?,
      category: json['category'] as String,
      categoryId: json['category_id'] as int,
      created: DateTime.parse(json['created'] as String),
      modified: json['modified'] != null
          ? DateTime.parse(json['modified'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (intro != null) 'intro': intro,
      if (content != null) 'content': content,
      'category': category,
      'category_id': categoryId,
      'created': created.toIso8601String(),
      if (modified != null) 'modified': modified!.toIso8601String(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Article && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
