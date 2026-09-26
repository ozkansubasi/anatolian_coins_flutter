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
  
  // Yeni alanlar
  final String? mintName;
  final String? mintUri;
  final String? authorityName;
  final String? authorityUri;
  final String? denominationName;
  final String? denominationUri;
  final String? obverseDesc;
  final String? obverseDescTr;
  final String? reverseDesc;
  final String? reverseDescTr;
  final String? findspotName;
  final String? findspotUri;
  final String? coordinates;
  final String? sourceCitation;

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
    this.mintName,
    this.mintUri,
    this.authorityName,
    this.authorityUri,
    this.denominationName,
    this.denominationUri,
    this.obverseDesc,
    this.obverseDescTr,
    this.reverseDesc,
    this.reverseDescTr,
    this.findspotName,
    this.findspotUri,
    this.coordinates,
    this.sourceCitation,
  });

  String get title => titleTr ?? titleEn ?? slug;

  /// Kimlik: `article_id` / `variant_id`; yoksa `uid`'den (`ntr:var:00003266`).
  ///
  /// Detay ucu (`/v1/variants/{id}`) `article_id` döndürmüyor → eskiden 0
  /// oluyordu: web bağlantısı `id=0` (404), Kaynak'ta sikke no "0", çevrimdışı
  /// indirmede her sikke kimlik 0 ile öncekinin üstüne yazılıyordu
  /// (2026-09-26 cihaz testi).
  static int _articleIdOf(Map<String, dynamic> j) {
    for (final key in const ['article_id', 'variant_id']) {
      final v = j[key];
      if (v is int && v > 0) return v;
      final parsed = int.tryParse('${v ?? ''}');
      if (parsed != null && parsed > 0) return parsed;
    }
    final m = RegExp(r'(\d+)$').firstMatch('${j['uid'] ?? ''}');
    return m == null ? 0 : int.parse(m.group(1)!);
  }

  factory Variant.fromJson(Map<String, dynamic> j) {
    return Variant(
      articleId: _articleIdOf(j),
      uid: j['uid'] ?? '',
      slug: j['slug'] ?? '',
      titleTr: j['title_tr'] ?? j['title'], // title de dene
      titleEn: j['title_en'],
      regionCode: j['region_code'] ?? j['region'], // region de dene
      material: j['material_value'] ?? j['material'] ?? j['metal'], // material/metal/material_value dene
      dateFrom: j['date_from'],
      dateTo: j['date_to'],
      updatedAt: j['updated_at'],
      mintName: j['mint_name'] ?? j['mint'], // mint de dene
      mintUri: j['mint_uri'],
      authorityName: j['authority_name'] ?? j['authority'], // authority de dene
      authorityUri: j['authority_uri'],
      denominationName: j['denomination_name'],
      denominationUri: j['denomination_uri'],
      obverseDesc: j['obverse_desc'],
      obverseDescTr: j['obverse_desc_tr'],
      reverseDesc: j['reverse_desc'],
      reverseDescTr: j['reverse_desc_tr'],
      findspotName: j['findspot_name'],
      findspotUri: j['findspot_uri'],
      coordinates: j['coordinates'] ?? (j['latitude'] != null && j['longitude'] != null 
          ? '${j['latitude']},${j['longitude']}' 
          : null), // latitude/longitude varsa birleştir
      sourceCitation: j['source_citation'],
    );
  }
}