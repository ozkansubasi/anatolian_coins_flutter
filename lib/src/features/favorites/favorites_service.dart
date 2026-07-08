import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_database.dart';
import '../offline/offline_service.dart';
import '../../models/variant.dart';
import '../variants/variants_api.dart';
import '../settings/settings_provider.dart';

/// Favorites Service - Pro özelliği
/// Favorileri yönetir ve otomatik çevrim dışı senkronizasyon sağlar
class FavoritesService {
  final OfflineDatabase _db;
  final OfflineService _offlineService;
  final VariantsApi _api;

  FavoritesService(this._db, this._offlineService, this._api);

  /// Favorilere ekle
  Future<void> addFavorite(int variantId, {bool syncOffline = true}) async {
    await _db.addFavorite(variantId);

    // Pro kullanıcı için otomatik çevrim dışı senkronizasyon
    if (syncOffline) {
      await _queueOfflineSync(variantId);
    }
  }

  /// Favorilerden çıkar
  Future<void> removeFavorite(int variantId) async {
    await _db.removeFavorite(variantId);
    // Çevrim dışı verileri de sil
    await _offlineService.deleteVariant(variantId);
  }

  /// Toggle favorite (ekle/çıkar)
  Future<void> toggleFavorite(int variantId, {bool syncOffline = true}) async {
    final isFav = await isFavorite(variantId);
    if (isFav) {
      await removeFavorite(variantId);
    } else {
      await addFavorite(variantId, syncOffline: syncOffline);
    }
  }

  /// Favori mi kontrol et
  Future<bool> isFavorite(int variantId) async {
    return await _db.isFavorite(variantId);
  }

  /// Tüm favorileri getir (ID listesi)
  Future<List<int>> getFavoriteIds() async {
    return await _db.getAllFavorites();
  }

  /// Tüm favorileri getir (Variant nesneleri)
  Future<List<Variant>> getFavoriteVariants() async {
    final ids = await getFavoriteIds();
    final variants = <Variant>[];

    for (final id in ids) {
      try {
        // Önce çevrim dışı veritabanından dene
        final offlineVariant = await _offlineService.getOfflineVariant(id);
        if (offlineVariant != null) {
          variants.add(offlineVariant);
        } else {
          // Online'dan çek
          final variant = await _api.getVariant(id);
          variants.add(variant);
        }
      } catch (e) {
        // Hata durumunda atla
        debugPrint('❌ Favorite variant $id could not be loaded: $e');
      }
    }

    return variants;
  }

  /// Senkronize edilmemiş favorileri getir ve indir
  Future<void> syncUnsyncedFavorites({
    required Function(int current, int total) onProgress,
  }) async {
    final unsyncedIds = await _db.getUnsyncedFavorites();

    if (unsyncedIds.isEmpty) {
      onProgress(0, 0);
      return;
    }

    for (var i = 0; i < unsyncedIds.length; i++) {
      final variantId = unsyncedIds[i];

      onProgress(i + 1, unsyncedIds.length);

      try {
        // Variant'ı indir
        await _offlineService.downloadVariant(
          variantId,
          onProgress: (progress) {
            // İç progress'i loglayabiliriz
            debugPrint('📥 Downloading favorite $variantId: ${(progress.progress * 100).toStringAsFixed(0)}%');
          },
        );

        // Senkronize edildi olarak işaretle
        await _db.markFavoriteSynced(variantId);
      } catch (e) {
        debugPrint('❌ Failed to sync favorite $variantId: $e');
        // Hata durumunda devam et
      }
    }
  }

  /// Çevrim dışı senkronizasyon kuyruğuna ekle
  Future<void> _queueOfflineSync(int variantId) async {
    await _db.addToDownloadQueue(variantId);
  }

  /// Favori sayısını getir
  Future<int> getFavoriteCount() async {
    final ids = await getFavoriteIds();
    return ids.length;
  }
}

/// Provider
final favoritesServiceProvider = Provider<FavoritesService>((ref) {
  final db = ref.watch(offlineDatabaseProvider);
  final offlineService = ref.watch(offlineServiceProvider);
  final api = ref.watch(variantsApiProvider);
  return FavoritesService(db, offlineService, api);
});

/// Favorite state notifier
class FavoritesController extends StateNotifier<Set<int>> {
  final FavoritesService _service;

  FavoritesController(this._service) : super({}) {
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    final ids = await _service.getFavoriteIds();
    state = Set.from(ids);
  }

  Future<void> toggle(int variantId, {bool syncOffline = true}) async {
    await _service.toggleFavorite(variantId, syncOffline: syncOffline);
    await _loadFavorites();
  }

  Future<void> add(int variantId, {bool syncOffline = true}) async {
    await _service.addFavorite(variantId, syncOffline: syncOffline);
    await _loadFavorites();
  }

  Future<void> remove(int variantId) async {
    await _service.removeFavorite(variantId);
    await _loadFavorites();
  }

  bool isFavorite(int variantId) => state.contains(variantId);
}

/// Controller provider
final favoritesControllerProvider =
    StateNotifierProvider<FavoritesController, Set<int>>((ref) {
  final service = ref.watch(favoritesServiceProvider);
  return FavoritesController(service);
});
