class VariantImage {
  final int imageId;
  final int variantId;
  final String? type;
  final String? weight;
  final String? diameter;
  final int? ordering;
  final String url;
  final String urlRaw;
  final String? remoteUrl;

  VariantImage({
    required this.imageId,
    required this.variantId,
    this.type,
    this.weight,
    this.diameter,
    this.ordering,
    required this.url,
    required this.urlRaw,
    this.remoteUrl,
  });

  factory VariantImage.fromJson(Map<String, dynamic> j) {
    String url = j['url'] ?? '';
    String urlRaw = j['url_raw'] ?? '';
    String? remoteUrl = j['remote_url'];

    // Eğer relative URL ise absolute yap
    if (url.startsWith('/')) {
      url = 'https://www.numistr.org$url';
    }
    if (urlRaw.startsWith('/')) {
      urlRaw = 'https://www.numistr.org$urlRaw';
    }

    return VariantImage(
      imageId: j['image_id'] ?? 0,
      variantId: j['variant_id'] ?? 0,
      type: j['type'],
      weight: j['weight'],
      diameter: j['diameter'],
      ordering: j['ordering'],
      url: url,
      urlRaw: urlRaw,
      remoteUrl: remoteUrl,
    );
  }
}