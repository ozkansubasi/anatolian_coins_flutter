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
  
  // Ek detaylar
  final String? authority;
  final String? mint;
  final double? latitude;
  final double? longitude;
  final String? obverseDesc;
  final String? reverseDesc;
  final String? weight;
  final String? diameter;

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
    this.authority,
    this.mint,
    this.latitude,
    this.longitude,
    this.obverseDesc,
    this.reverseDesc,
    this.weight,
    this.diameter,
  });

  String get title => titleTr ?? titleEn ?? slug;

  factory Variant.fromJson(Map<String, dynamic> j) {
    int parseId(dynamic value) {
      if (value == null) return 0;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }

    int? parseYear(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }
    
    double? parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return Variant(
      articleId: parseId(j['article_id'] ?? j['id']),
      uid: j['uid']?.toString() ?? '',
      slug: j['slug']?.toString() ?? '',
      titleTr: j['title_tr']?.toString() ?? j['title']?.toString(),
      titleEn: j['title_en']?.toString() ?? j['title']?.toString(),
      regionCode: j['region_code']?.toString() ?? j['region']?.toString(),
      material: j['material']?.toString() ?? j['material_value']?.toString() ?? j['metal']?.toString(),
      dateFrom: parseYear(j['date_from']),
      dateTo: parseYear(j['date_to']),
      updatedAt: j['updated_at']?.toString(),
      
      // Ek alanlar
      authority: j['authority']?.toString() ?? j['authority_value']?.toString(),
      mint: j['mint']?.toString() ?? j['mint_value']?.toString() ?? j['mint_name']?.toString(),
      latitude: parseDouble(j['latitude'] ?? j['lat']),
      longitude: parseDouble(j['longitude'] ?? j['lng'] ?? j['lon']),
      obverseDesc: j['obverse_desc']?.toString() ?? j['obverse']?.toString(),
      reverseDesc: j['reverse_desc']?.toString() ?? j['reverse']?.toString(),
      weight: j['weight']?.toString() ?? j['weight_nominal']?.toString(),
      diameter: j['diameter']?.toString() ?? j['diameter_nominal']?.toString(),
    );
  }
}