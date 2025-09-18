class VariantImage {
  final int imageId;
  final int variantId;
  final String? type;
  final String? weight;
  final String? diameter;
  final int? ordering;
  final String url;
  final String urlRaw;

  VariantImage({
    required this.imageId,
    required this.variantId,
    this.type,
    this.weight,
    this.diameter,
    this.ordering,
    required this.url,
    required this.urlRaw,
  });

  factory VariantImage.fromJson(Map<String, dynamic> j) {
    return VariantImage(
      imageId: j['image_id'] ?? 0,
      variantId: j['variant_id'] ?? 0,
      type: j['type'],
      weight: j['weight'],
      diameter: j['diameter'],
      ordering: j['ordering'],
      url: j['url'] ?? '',
      urlRaw: j['url_raw'] ?? '',
    );
  }
}
