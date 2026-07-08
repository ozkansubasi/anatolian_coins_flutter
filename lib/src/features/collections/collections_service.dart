import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../offline/offline_database.dart';
import '../../models/collection.dart';

/// Provider for offline database
final _offlineDatabaseProvider = Provider<OfflineDatabase>((ref) {
  return OfflineDatabase();
});

/// Collections service for managing user collections
class CollectionsService {
  final OfflineDatabase _db;

  CollectionsService(this._db);

  /// Create a new collection
  Future<int> createCollection(String name, {String? description}) async {
    return await _db.createCollection(name, description: description);
  }

  /// Update collection details
  Future<void> updateCollection(int collectionId, {String? name, String? description}) async {
    await _db.updateCollection(collectionId, name: name, description: description);
  }

  /// Delete a collection
  Future<void> deleteCollection(int collectionId) async {
    await _db.deleteCollection(collectionId);
  }

  /// Get all collections
  Future<List<Collection>> getAllCollections() async {
    final rawCollections = await _db.getAllCollections();
    return rawCollections.map((json) => Collection.fromJson(json)).toList();
  }

  /// Get a specific collection
  Future<Collection?> getCollection(int collectionId) async {
    final json = await _db.getCollection(collectionId);
    if (json == null) return null;
    return Collection.fromJson(json);
  }

  /// Add a coin to a collection
  Future<void> addToCollection(int collectionId, int variantId, {String? notes}) async {
    await _db.addToCollection(collectionId, variantId, notes: notes);
  }

  /// Remove a coin from a collection
  Future<void> removeFromCollection(int collectionId, int variantId) async {
    await _db.removeFromCollection(collectionId, variantId);
  }

  /// Update notes for a collection item
  Future<void> updateItemNotes(int collectionId, int variantId, String? notes) async {
    await _db.updateCollectionItemNotes(collectionId, variantId, notes);
  }

  /// Get all coins in a collection (just IDs)
  Future<List<int>> getCollectionItems(int collectionId) async {
    return await _db.getCollectionItems(collectionId);
  }

  /// Get all coins in a collection with notes
  Future<List<CollectionItem>> getCollectionItemsWithNotes(int collectionId) async {
    final rawItems = await _db.getCollectionItemsWithNotes(collectionId);
    return rawItems.map((json) => CollectionItem.fromJson(json)).toList();
  }

  /// Get all collections containing a specific coin
  Future<List<int>> getCollectionsForVariant(int variantId) async {
    return await _db.getCollectionsForVariant(variantId);
  }

  /// Check if a coin is in a specific collection
  Future<bool> isInCollection(int collectionId, int variantId) async {
    return await _db.isInCollection(collectionId, variantId);
  }
}

/// Provider for collections service
final collectionsServiceProvider = Provider<CollectionsService>((ref) {
  final db = ref.watch(_offlineDatabaseProvider);
  return CollectionsService(db);
});

/// State notifier for collections list
class CollectionsController extends StateNotifier<AsyncValue<List<Collection>>> {
  final CollectionsService _service;

  CollectionsController(this._service) : super(const AsyncValue.loading()) {
    loadCollections();
  }

  /// Load all collections
  Future<void> loadCollections() async {
    state = const AsyncValue.loading();
    try {
      final collections = await _service.getAllCollections();
      state = AsyncValue.data(collections);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  /// Create a new collection
  Future<int?> createCollection(String name, {String? description}) async {
    try {
      final id = await _service.createCollection(name, description: description);
      await loadCollections(); // Refresh list
      return id;
    } catch (e) {
      debugPrint('Failed to create collection: $e');
      return null;
    }
  }

  /// Update a collection
  Future<bool> updateCollection(int collectionId, {String? name, String? description}) async {
    try {
      await _service.updateCollection(collectionId, name: name, description: description);
      await loadCollections(); // Refresh list
      return true;
    } catch (e) {
      debugPrint('Failed to update collection: $e');
      return false;
    }
  }

  /// Delete a collection
  Future<bool> deleteCollection(int collectionId) async {
    try {
      await _service.deleteCollection(collectionId);
      await loadCollections(); // Refresh list
      return true;
    } catch (e) {
      debugPrint('Failed to delete collection: $e');
      return false;
    }
  }
}

/// Provider for collections controller
final collectionsControllerProvider = StateNotifierProvider<CollectionsController, AsyncValue<List<Collection>>>((ref) {
  final service = ref.watch(collectionsServiceProvider);
  return CollectionsController(service);
});

/// Provider for a specific collection's items
final collectionItemsProvider = FutureProvider.family<List<int>, int>((ref, collectionId) async {
  final service = ref.watch(collectionsServiceProvider);
  return await service.getCollectionItems(collectionId);
});

/// Provider for a specific collection's items with notes
final collectionItemsWithNotesProvider = FutureProvider.family<List<CollectionItem>, int>((ref, collectionId) async {
  final service = ref.watch(collectionsServiceProvider);
  return await service.getCollectionItemsWithNotes(collectionId);
});

/// Provider to check if a variant is in a collection
final isInCollectionProvider = FutureProvider.family<bool, ({int collectionId, int variantId})>((ref, params) async {
  final service = ref.watch(collectionsServiceProvider);
  return await service.isInCollection(params.collectionId, params.variantId);
});

/// Provider to get all collections containing a variant
final collectionsForVariantProvider = FutureProvider.family<List<int>, int>((ref, variantId) async {
  final service = ref.watch(collectionsServiceProvider);
  return await service.getCollectionsForVariant(variantId);
});
