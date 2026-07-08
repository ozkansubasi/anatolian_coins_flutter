/// Collection model for organizing coins
class Collection {
  final int id;
  final String name;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int itemCount;

  const Collection({
    required this.id,
    required this.name,
    this.description,
    required this.createdAt,
    required this.updatedAt,
    this.itemCount = 0,
  });

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(json['created_at'] as int),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(json['updated_at'] as int),
      itemCount: json['item_count'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
      'item_count': itemCount,
    };
  }

  Collection copyWith({
    int? id,
    String? name,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? itemCount,
  }) {
    return Collection(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      itemCount: itemCount ?? this.itemCount,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Collection && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Collection(id: $id, name: $name, itemCount: $itemCount)';
  }
}

/// Collection item with notes
class CollectionItem {
  final int id;
  final int collectionId;
  final int variantId;
  final String? notes;
  final DateTime addedAt;

  const CollectionItem({
    required this.id,
    required this.collectionId,
    required this.variantId,
    this.notes,
    required this.addedAt,
  });

  factory CollectionItem.fromJson(Map<String, dynamic> json) {
    return CollectionItem(
      id: json['id'] as int,
      collectionId: json['collection_id'] as int,
      variantId: json['variant_id'] as int,
      notes: json['notes'] as String?,
      addedAt: DateTime.fromMillisecondsSinceEpoch(json['added_at'] as int),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'collection_id': collectionId,
      'variant_id': variantId,
      'notes': notes,
      'added_at': addedAt.millisecondsSinceEpoch,
    };
  }

  CollectionItem copyWith({
    int? id,
    int? collectionId,
    int? variantId,
    String? notes,
    DateTime? addedAt,
  }) {
    return CollectionItem(
      id: id ?? this.id,
      collectionId: collectionId ?? this.collectionId,
      variantId: variantId ?? this.variantId,
      notes: notes ?? this.notes,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CollectionItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'CollectionItem(id: $id, collectionId: $collectionId, variantId: $variantId)';
  }
}
