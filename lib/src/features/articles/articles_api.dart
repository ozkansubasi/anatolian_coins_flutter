import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/locale_provider.dart';
import '../../models/article.dart';
import '../../models/article_category.dart';

/// API service for blog articles
class ArticlesApi {
  final ApiClient _apiClient;

  /// Arayüz dili (`tr`, `en`…): sunucu o dildeki blog ağacını döner
  /// (plugin 1.16.0 `?lang=`; o dilde blog yoksa TR).
  final String _lang;

  ArticlesApi(this._apiClient, this._lang);

  /// Get daily featured article
  Future<Article> getFeaturedArticle() async {
    final response = await _apiClient.dio.get('/articles/featured', queryParameters: {'lang': _lang});
    final data = response.data['data'] as Map<String, dynamic>;
    return Article.fromJson(data);
  }

  /// Get list of articles with optional category filter
  Future<List<Article>> getArticles({int? categoryId, int page = 1, int limit = 20}) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
      'lang': _lang,
    };
    if (categoryId != null) {
      queryParams['category_id'] = categoryId;
    }

    final response = await _apiClient.dio.get('/articles', queryParameters: queryParams);
    final data = response.data['data'] as List;
    return data.map((json) => Article.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get list of blog categories
  Future<List<ArticleCategory>> getCategories() async {
    final response = await _apiClient.dio.get('/articles/categories', queryParameters: {'lang': _lang});
    final data = response.data['data'] as List;
    return data.map((json) => ArticleCategory.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get article by ID
  Future<Article> getArticle(int articleId) async {
    final response = await _apiClient.dio.get('/articles/$articleId');
    final data = response.data['data'] as Map<String, dynamic>;
    return Article.fromJson(data);
  }

  /// Sikkenin hikâyeleri (API 1.31.0): darphane / hükümdar etiketli blog yazıları, sitedeki
  /// "İlgili yazılar" kuralıyla (dönem süzgeci + sıra). Bağ yoksa boş liste.
  Future<List<Article>> getCoinStories(int variantId, {int limit = 3}) =>
      _list('/variants/$variantId/articles', limit);

  /// Yerleşimin hikâyeleri (API 1.31.0): yerleşimin darphanelerine bağlı blog yazıları.
  Future<List<Article>> getPlaceStories(String locId, {int limit = 3}) =>
      _list('/locations/${Uri.encodeComponent(locId)}/articles', limit);

  Future<List<Article>> _list(String path, int limit) async {
    final response = await _apiClient.dio.get(path, queryParameters: {'lang': _lang, 'limit': limit});
    final data = response.data['data'];
    if (data is! List) return const [];
    return data.whereType<Map>().map((j) => Article.fromJson(Map<String, dynamic>.from(j))).toList();
  }
}

/// Sikke detayı Kaynak sekmesi: sikkenin hikâyeleri. Hata olursa bölüm gizlenir (boş liste).
final coinStoriesProvider = FutureProvider.autoDispose.family<List<Article>, int>((ref, variantId) async {
  try {
    return await ref.watch(articlesApiProvider).getCoinStories(variantId);
  } catch (_) {
    return const [];
  }
});

/// Harita bilgi ekranı: yerleşimin hikâyeleri (en çok 2, kart küçük). Hata olursa gizlenir.
final placeStoriesProvider = FutureProvider.autoDispose.family<List<Article>, String>((ref, locId) async {
  try {
    return await ref.watch(articlesApiProvider).getPlaceStories(locId, limit: 2);
  } catch (_) {
    return const [];
  }
});

/// Provider for ArticlesApi
/// Dil değişince yeniden kurulur; onu izleyen sağlayıcılar (öne çıkan yazı)
/// yeni dilde yeniden çeker.
final articlesApiProvider = Provider<ArticlesApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ArticlesApi(apiClient, ref.watch(localeProvider).languageCode);
});

/// Gunun one cikan yazisi.
///
/// AYRI PROVIDER OLMASININ SEBEBI (2026-09-20): EditorsPickCard bu Future'i
/// `build()` govdesinde kuruyordu. Dashboard cok sik rebuild oluyor (auth durumu,
/// favori sayisi, banner kaydirma, alt menu setState), her rebuild YENI bir Future
/// uretiyor ve FutureBuilder hic `waiting` durumundan cikmiyordu: blok sonsuza kadar
/// iskelet gosteriyor, kullaniciya BOS gorunuyordu -- ustelik her rebuild'de API'ye
/// yeni istek gidiyordu. Provider sonucu onbellekliyor; yenileme
/// `ref.invalidate(featuredArticleProvider)` ile acikca yapilir.
final featuredArticleProvider = FutureProvider<Article>((ref) async {
  return ref.watch(articlesApiProvider).getFeaturedArticle();
});
