import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

class FavoritesApi {
  final ApiClient _client;
  FavoritesApi(Ref ref) : _client = ApiClient(ref);

  /// Kullanıcının favorilerini getir
  Future<List<int>> getFavorites() async {
    try {
      final res = await _client.dio.get('/favorites');
      final data = (res.data['data'] as List?) ?? [];
      return data.map((e) => (e['article_id'] ?? 0) as int).toList();
    } catch (e) {
      // Backend henüz hazır değilse veya hata varsa boş liste döndür
      print('⚠️ Favorites API error (ignoring): $e');
      return [];
    }
  }

  /// Favorilere ekle
  Future<void> addFavorite(int articleId) async {
    try {
      await _client.dio.post('/favorites', data: {
        'article_id': articleId,
      });
    } catch (e) {
      print('⚠️ Add favorite error: $e');
      rethrow;
    }
  }

  /// Favorilerden çıkar
  Future<void> removeFavorite(int articleId) async {
    try {
      await _client.dio.delete('/favorites/$articleId');
    } catch (e) {
      print('⚠️ Remove favorite error: $e');
      rethrow;
    }
  }

  /// Favori mi kontrol et (local cache kullanarak)
  Future<bool> isFavorite(int articleId) async {
    final favorites = await getFavorites();
    return favorites.contains(articleId);
  }
}

final favoritesApiProvider = Provider<FavoritesApi>((ref) => FavoritesApi(ref));

/// Favoriler state yönetimi
class FavoritesController extends StateNotifier<Set<int>> {
  final FavoritesApi _api;

  FavoritesController(this._api) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    try {
      final favorites = await _api.getFavorites();
      state = favorites.toSet();
    } catch (e) {
      // Hata durumunda mevcut state'i koru
    }
  }

  Future<void> toggleFavorite(int articleId) async {
    final isFav = state.contains(articleId);
    
    if (isFav) {
      // Önce UI'dan kaldır
      state = {...state}..remove(articleId);
      try {
        await _api.removeFavorite(articleId);
      } catch (e) {
        // Hata olursa geri ekle
        state = {...state, articleId};
        rethrow;
      }
    } else {
      // Önce UI'a ekle
      state = {...state, articleId};
      try {
        await _api.addFavorite(articleId);
      } catch (e) {
        // Hata olursa geri çıkar
        state = {...state}..remove(articleId);
        rethrow;
      }
    }
  }

  bool isFavorite(int articleId) => state.contains(articleId);

  Future<void> refresh() => _loadFavorites();
}

final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, Set<int>>((ref) {
  final api = ref.watch(favoritesApiProvider);
  return FavoritesController(api);
});