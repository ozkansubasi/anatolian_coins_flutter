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

  factory Variant.fromJson(Map<String, dynamic> j) {
    return Variant(
      articleId: j['article_id'] ?? j['variant_id'] ?? 0, // variant_id de dene
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