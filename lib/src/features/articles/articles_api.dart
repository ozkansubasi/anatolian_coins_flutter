import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../models/article.dart';
import '../../models/article_category.dart';

/// API service for blog articles
class ArticlesApi {
  final ApiClient _apiClient;

  ArticlesApi(this._apiClient);

  /// Get daily featured article
  Future<Article> getFeaturedArticle() async {
    final response = await _apiClient.dio.get('/articles/featured');
    final data = response.data['data'] as Map<String, dynamic>;
    return Article.fromJson(data);
  }

  /// Get list of articles with optional category filter
  Future<List<Article>> getArticles({int? categoryId, int page = 1, int limit = 20}) async {
    final queryParams = <String, dynamic>{
      'page': page,
      'limit': limit,
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
    final response = await _apiClient.dio.get('/articles/categories');
    final data = response.data['data'] as List;
    return data.map((json) => ArticleCategory.fromJson(json as Map<String, dynamic>)).toList();
  }

  /// Get article by ID
  Future<Article> getArticle(int articleId) async {
    final response = await _apiClient.dio.get('/articles/$articleId');
    final data = response.data['data'] as Map<String, dynamic>;
    return Article.fromJson(data);
  }
}

/// Provider for ArticlesApi
final articlesApiProvider = Provider<ArticlesApi>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return ArticlesApi(apiClient);
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
