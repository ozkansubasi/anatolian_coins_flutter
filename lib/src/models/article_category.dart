/// Article category model
class ArticleCategory {
  final int id;
  final String name;
  final String slug;
  final String? description;

  const ArticleCategory({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
  });

  factory ArticleCategory.fromJson(Map<String, dynamic> json) {
    return ArticleCategory(
      id: json['id'] as int,
      name: json['name'] as String,
      slug: json['slug'] as String,
      description: json['description'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      if (description != null) 'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ArticleCategory && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
