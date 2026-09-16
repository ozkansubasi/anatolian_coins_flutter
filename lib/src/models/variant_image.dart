class VariantImage {
  final int imageId;
  final int variantId;
  final String? type;
  final String? weight;
  final String? diameter;
  final int? ordering;
  final String url;
  final String urlRaw;
  /// ADR-006 Faz 2: Pro + Bearer ile gelen, süreli imzalı filigransız URL (yoksa null)
  final String? urlHd;
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
    this.urlHd,
    this.remoteUrl,
  });

  factory VariantImage.fromJson(Map<String, dynamic> j) {
    String url = j['url'] ?? '';
    String urlRaw = j['url_raw'] ?? '';
    String? urlHd = j['url_hd'];
    String? remoteUrl = j['remote_url'];

    // Eğer relative URL ise absolute yap
    if (url.startsWith('/')) {
      url = 'https://www.numistr.org$url';
    }
    if (urlRaw.startsWith('/')) {
      urlRaw = 'https://www.numistr.org$urlRaw';
    }
    if (urlHd != null && urlHd.startsWith('/')) {
      urlHd = 'https://www.numistr.org$urlHd';
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
      urlHd: (urlHd == null || urlHd.isEmpty) ? null : urlHd,
      remoteUrl: remoteUrl,
    );
  }
}