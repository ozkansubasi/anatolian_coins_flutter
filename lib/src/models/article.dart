/// Yazıya ya da yerleşim sayfasına bağlı YouTube videosu (API 1.30.0 `videos`).
/// Uygulama videoyu gömmez: kart küçük resmi gösterir, dokununca YouTube açılır.
class ArticleVideo {
  final String youtubeId;

  /// `shorts` (9:16) | `video` (16:9)
  final String format;
  final String title;

  /// Görsel ve müzik künyesi (CC BY atfı); boş olabilir.
  final String credit;
  final int? durationSec;
  final String? thumbnailUrl;
  final String watchUrl;

  const ArticleVideo({
    required this.youtubeId,
    required this.format,
    required this.title,
    required this.credit,
    required this.watchUrl,
    this.durationSec,
    this.thumbnailUrl,
  });

  bool get isShorts => format != 'video';

  /// 52 → "0:52"; süre yoksa null.
  String? get durationLabel {
    final s = durationSec;
    if (s == null || s <= 0) return null;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  static final _id = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// Geçersiz kimlik ya da YouTube dışı izleme adresi → null (kart çizilmez).
  static ArticleVideo? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final id = '${j['youtube_id'] ?? ''}';
    final watch = '${j['watch_url'] ?? ''}';
    final host = Uri.tryParse(watch)?.host ?? '';
    if (!_id.hasMatch(id) || !(host == 'www.youtube.com' || host == 'youtube.com')) return null;
    final thumb = j['thumbnail_url'];
    return ArticleVideo(
      youtubeId: id,
      format: j['format'] == 'video' ? 'video' : 'shorts',
      title: '${j['title'] ?? ''}'.trim(),
      credit: '${j['credit'] ?? ''}'.trim(),
      durationSec: (j['duration_sec'] as num?)?.toInt(),
      thumbnailUrl: thumb is String && thumb.startsWith('https://') ? thumb : null,
      watchUrl: watch,
    );
  }

  Map<String, dynamic> toJson() => {
        'youtube_id': youtubeId,
        'format': format,
        'title': title,
        'credit': credit,
        if (durationSec != null) 'duration_sec': durationSec,
        if (thumbnailUrl != null) 'thumbnail_url': thumbnailUrl,
        'watch_url': watchUrl,
      };
}

/// Günün hikâyesinin sikkesi (API 1.31.0 `/articles/featured` → `coin`): yazıdaki ilk görselli sikke.
/// Kimlik TR katalog kimliğidir (`/variant/:id`); küçük görsel 480 px, filigransız.
class StoryCoin {
  final int id;
  final String title;
  final String? thumbUrl;

  const StoryCoin({required this.id, required this.title, this.thumbUrl});

  /// Geçersiz kimlik → null (blok çizilmez). Yalnız https küçük görsel kabul edilir.
  static StoryCoin? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final id = (j['id'] as num?)?.toInt() ?? 0;
    if (id <= 0) return null;
    final thumb = j['thumb_url'];
    return StoryCoin(
      id: id,
      title: '${j['title'] ?? ''}'.trim(),
      thumbUrl: thumb is String && thumb.startsWith('https://') ? thumb : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        if (thumbUrl != null) 'thumb_url': thumbUrl,
      };
}

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

  /// API 1.30.0: sayfaya bağlı YouTube videoları (yalnız ayrıntı ucunda; listede boş).
  final List<ArticleVideo> videos;

  /// API 1.31.0, yalnız günün hikâyesinde: yazıdaki ilk görselli sikke (yoksa null).
  final StoryCoin? coin;

  /// API 1.31.0, yalnız günün hikâyesinde: `today` (o sabah yayımlanan yazı) | `rotation` (günlük dönüşüm).
  final String? reason;

  const Article({
    required this.id,
    required this.title,
    this.intro,
    this.content,
    required this.category,
    required this.categoryId,
    required this.created,
    this.modified,
    this.videos = const [],
    this.coin,
    this.reason,
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
      videos: json['videos'] is List
          ? (json['videos'] as List).map(ArticleVideo.tryParse).whereType<ArticleVideo>().toList()
          : const [],
      coin: StoryCoin.tryParse(json['coin']),
      reason: json['reason'] is String ? json['reason'] as String : null,
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
      if (videos.isNotEmpty) 'videos': videos.map((v) => v.toJson()).toList(),
      if (coin != null) 'coin': coin!.toJson(),
      if (reason != null) 'reason': reason,
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
