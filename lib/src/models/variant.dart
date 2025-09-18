class Variant {
  final int articleId;
  final String uid;
  final String slug;
  final String? titleTr;
  final String? titleEn;
  final String? regionCode;
  final String? material;
  final int? dateFrom;
  final int? dateTo;
  final String? updatedAt;

  Variant({
    required this.articleId,
    required this.uid,
    required this.slug,
    this.titleTr,
    this.titleEn,
    this.regionCode,
    this.material,
    this.dateFrom,
    this.dateTo,
    this.updatedAt,
  });

  String get title => titleTr ?? titleEn ?? slug;

  factory Variant.fromJson(Map<String, dynamic> j) {
    return Variant(
      articleId: j['article_id'] ?? j['id'] ?? 0,
      uid: j['uid'] ?? '',
      slug: j['slug'] ?? '',
      titleTr: j['title_tr'],
      titleEn: j['title_en'],
      regionCode: j['region_code'],
      material: j['material_value'] ?? j['metal'],
      dateFrom: j['date_from'],
      dateTo: j['date_to'],
      updatedAt: j['updated_at'],
    );
  }
}
