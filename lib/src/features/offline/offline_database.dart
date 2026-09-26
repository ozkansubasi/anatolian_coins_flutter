import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';

class OfflineDatabase {
  static Database? _database;
  static const String _dbName = 'anatolian_coins_offline.db';
  static const int _dbVersion = 5; // images: credit + license (görsel atfı)

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final documentsDirectory = await getApplicationDocumentsDirectory();
    final path = join(documentsDirectory.path, _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Variants tablosu
    await db.execute('''
      CREATE TABLE variants (
        article_id INTEGER PRIMARY KEY,
        uid TEXT NOT NULL,
        slug TEXT NOT NULL,
        title_tr TEXT,
        title_en TEXT,
        region_code TEXT,
        material TEXT,
        date_from INTEGER,
        date_to INTEGER,
        mint_name TEXT,
        mint_uri TEXT,
        authority_name TEXT,
        authority_uri TEXT,
        denomination_name TEXT,
        denomination_uri TEXT,
        obverse_desc TEXT,
        obverse_desc_tr TEXT,
        reverse_desc TEXT,
        reverse_desc_tr TEXT,
        findspot_name TEXT,
        findspot_uri TEXT,
        coordinates TEXT,
        source_citation TEXT,
        downloaded_at INTEGER NOT NULL
      )
    ''');

    // Images tablosu
    await db.execute('''
      CREATE TABLE images (
        image_id INTEGER PRIMARY KEY,
        variant_id INTEGER NOT NULL,
        type TEXT,
        weight TEXT,
        diameter TEXT,
        ordering INTEGER,
        url TEXT NOT NULL,
        url_raw TEXT NOT NULL,
        credit TEXT,
        license TEXT,
        local_path TEXT,
        downloaded_at INTEGER,
        FOREIGN KEY (variant_id) REFERENCES variants (article_id)
      )
    ''');

    // Download queue tablosu (indirilecekler kuyruğu)
    await db.execute('''
      CREATE TABLE download_queue (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'pending',
        added_at INTEGER NOT NULL,
        started_at INTEGER,
        completed_at INTEGER,
        error TEXT
      )
    ''');

    // Favorites tablosu
    await db.execute('''
      CREATE TABLE favorites (
        variant_id INTEGER PRIMARY KEY,
        added_at INTEGER NOT NULL,
        synced_offline INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // View history tablosu
    await db.execute('''
      CREATE TABLE view_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        variant_id INTEGER NOT NULL,
        viewed_at INTEGER NOT NULL
      )
    ''');

    // Tarama geçmişi tablosu (AI tanıma sonuçları)
    await db.execute('''
      CREATE TABLE scan_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        scanned_at INTEGER NOT NULL,
        image_path TEXT,
        reverse_image_path TEXT,
        top_article_id INTEGER,
        top_title TEXT,
        top_confidence REAL,
        match_count INTEGER NOT NULL DEFAULT 0,
        matches_json TEXT
      )
    ''');

    // Collections tablosu
    await db.execute('''
      CREATE TABLE collections (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Collection items (many-to-many relationship)
    await db.execute('''
      CREATE TABLE collection_items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        collection_id INTEGER NOT NULL,
        variant_id INTEGER NOT NULL,
        notes TEXT,
        added_at INTEGER NOT NULL,
        FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
        UNIQUE(collection_id, variant_id)
      )
    ''');

    // İndeksler
    await db.execute('CREATE INDEX idx_variants_slug ON variants(slug)');
    await db.execute('CREATE INDEX idx_images_variant ON images(variant_id)');
    await db.execute('CREATE INDEX idx_queue_status ON download_queue(status)');
    await db.execute('CREATE INDEX idx_favorites_added ON favorites(added_at DESC)');
    await db.execute('CREATE INDEX idx_history_viewed ON view_history(viewed_at DESC)');
    await db.execute('CREATE INDEX idx_history_variant ON view_history(variant_id)');
    await db.execute('CREATE INDEX idx_scan_history_scanned ON scan_history(scanned_at DESC)');
    await db.execute('CREATE INDEX idx_collections_created ON collections(created_at DESC)');
    await db.execute('CREATE INDEX idx_collection_items_collection ON collection_items(collection_id)');
    await db.execute('CREATE INDEX idx_collection_items_variant ON collection_items(variant_id)');
    await db.execute('CREATE INDEX idx_collection_items_added ON collection_items(added_at DESC)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Favorites tablosu ekle
      await db.execute('''
        CREATE TABLE favorites (
          variant_id INTEGER PRIMARY KEY,
          added_at INTEGER NOT NULL,
          synced_offline INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // View history tablosu ekle
      await db.execute('''
        CREATE TABLE view_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          variant_id INTEGER NOT NULL,
          viewed_at INTEGER NOT NULL
        )
      ''');

      // Yeni indeksler
      await db.execute('CREATE INDEX idx_favorites_added ON favorites(added_at DESC)');
      await db.execute('CREATE INDEX idx_history_viewed ON view_history(viewed_at DESC)');
      await db.execute('CREATE INDEX idx_history_variant ON view_history(variant_id)');
    }

    if (oldVersion < 3) {
      // Collections tablosu ekle
      await db.execute('''
        CREATE TABLE collections (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          description TEXT,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');

      // Collection items tablosu ekle
      await db.execute('''
        CREATE TABLE collection_items (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          collection_id INTEGER NOT NULL,
          variant_id INTEGER NOT NULL,
          notes TEXT,
          added_at INTEGER NOT NULL,
          FOREIGN KEY (collection_id) REFERENCES collections (id) ON DELETE CASCADE,
          UNIQUE(collection_id, variant_id)
        )
      ''');

      // Collections için indeksler
      await db.execute('CREATE INDEX idx_collections_created ON collections(created_at DESC)');
      await db.execute('CREATE INDEX idx_collection_items_collection ON collection_items(collection_id)');
      await db.execute('CREATE INDEX idx_collection_items_variant ON collection_items(variant_id)');
      await db.execute('CREATE INDEX idx_collection_items_added ON collection_items(added_at DESC)');
    }

    if (oldVersion < 4) {
      // Tarama geçmişi tablosu ekle
      await db.execute('''
        CREATE TABLE scan_history (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          scanned_at INTEGER NOT NULL,
          image_path TEXT,
          reverse_image_path TEXT,
          top_article_id INTEGER,
          top_title TEXT,
          top_confidence REAL,
          match_count INTEGER NOT NULL DEFAULT 0,
          matches_json TEXT
        )
      ''');
      await db.execute('CREATE INDEX idx_scan_history_scanned ON scan_history(scanned_at DESC)');
    }
    if (oldVersion < 5) {
      // Görsel atfı (ADR-008): indirilen görsellerin kaynağı ve lisansı.
      // Eski satırlarda boş kalır; sikke yeniden indirilince dolar.
      await db.execute('ALTER TABLE images ADD COLUMN credit TEXT');
      await db.execute('ALTER TABLE images ADD COLUMN license TEXT');
    }
  }

  // ========== VARIANT İŞLEMLERİ ==========

  Future<void> saveVariant(Variant variant) async {
    final db = await database;
    await db.insert(
      'variants',
      {
        'article_id': variant.articleId,
        'uid': variant.uid,
        'slug': variant.slug,
        'title_tr': variant.titleTr,
        'title_en': variant.titleEn,
        'region_code': variant.regionCode,
        'material': variant.material,
        'date_from': variant.dateFrom,
        'date_to': variant.dateTo,
        'mint_name': variant.mintName,
        'mint_uri': variant.mintUri,
        'authority_name': variant.authorityName,
        'authority_uri': variant.authorityUri,
        'denomination_name': variant.denominationName,
        'denomination_uri': variant.denominationUri,
        'obverse_desc': variant.obverseDesc,
        'obverse_desc_tr': variant.obverseDescTr,
        'reverse_desc': variant.reverseDesc,
        'reverse_desc_tr': variant.reverseDescTr,
        'findspot_name': variant.findspotName,
        'findspot_uri': variant.findspotUri,
        'coordinates': variant.coordinates,
        'source_citation': variant.sourceCitation,
        'downloaded_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Variant?> getVariant(int articleId) async {
    final db = await database;
    final maps = await db.query(
      'variants',
      where: 'article_id = ?',
      whereArgs: [articleId],
    );

    if (maps.isEmpty) return null;
    return Variant.fromJson(maps.first);
  }

  Future<List<Variant>> getAllVariants() async {
    final db = await database;
    final maps = await db.query('variants', orderBy: 'downloaded_at DESC');
    return maps.map((map) => Variant.fromJson(map)).toList();
  }

  Future<void> deleteVariant(int articleId) async {
    final db = await database;
    await db.delete('variants', where: 'article_id = ?', whereArgs: [articleId]);
    await db.delete('images', where: 'variant_id = ?', whereArgs: [articleId]);
  }

  // ========== IMAGE İŞLEMLERİ ==========

  Future<void> saveImage(VariantImage image, {String? localPath}) async {
    final db = await database;
    await db.insert(
      'images',
      {
        'image_id': image.imageId,
        'variant_id': image.variantId,
        'type': image.type,
        'weight': image.weight,
        'diameter': image.diameter,
        'ordering': image.ordering,
        'url': image.url,
        'url_raw': image.urlRaw,
        'credit': image.credit,
        'license': image.license,
        'local_path': localPath,
        'downloaded_at': localPath != null 
            ? DateTime.now().millisecondsSinceEpoch 
            : null,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VariantImage>> getImages(int variantId) async {
    final db = await database;
    final maps = await db.query(
      'images',
      where: 'variant_id = ?',
      whereArgs: [variantId],
      orderBy: 'ordering ASC',
    );
    return maps.map((map) => VariantImage.fromJson(map)).toList();
  }

  // ========== DOWNLOAD QUEUE İŞLEMLERİ ==========

  Future<void> addToDownloadQueue(int variantId) async {
    final db = await database;
    await db.insert('download_queue', {
      'variant_id': variantId,
      'status': 'pending',
      'added_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> getPendingDownloads() async {
    final db = await database;
    return await db.query(
      'download_queue',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'added_at ASC',
    );
  }

  Future<void> updateDownloadStatus(
    int queueId,
    String status, {
    String? error,
  }) async {
    final db = await database;
    final data = <String, dynamic>{
      'status': status,
    };
    
    if (status == 'downloading') {
      data['started_at'] = DateTime.now().millisecondsSinceEpoch;
    } else if (status == 'completed' || status == 'failed') {
      data['completed_at'] = DateTime.now().millisecondsSinceEpoch;
      if (error != null) data['error'] = error;
    }

    await db.update(
      'download_queue',
      data,
      where: 'id = ?',
      whereArgs: [queueId],
    );
  }

  // ========== İSTATİSTİKLER ==========

  Future<Map<String, int>> getStats() async {
    final db = await database;
    
    final variantCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM variants'),
    ) ?? 0;
    
    final imageCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM images WHERE local_path IS NOT NULL'),
    ) ?? 0;
    
    final pendingCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM download_queue WHERE status = ?', ['pending']),
    ) ?? 0;

    return {
      'variants': variantCount,
      'images': imageCount,
      'pending': pendingCount,
    };
  }

  // ========== FAVORİLER İŞLEMLERİ ==========

  /// Favorilere ekle
  Future<void> addFavorite(int variantId) async {
    final db = await database;
    await db.insert(
      'favorites',
      {
        'variant_id': variantId,
        'added_at': DateTime.now().millisecondsSinceEpoch,
        'synced_offline': 0,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Favorilerden çıkar
  Future<void> removeFavorite(int variantId) async {
    final db = await database;
    await db.delete('favorites', where: 'variant_id = ?', whereArgs: [variantId]);
  }

  /// Favori mi kontrol et
  Future<bool> isFavorite(int variantId) async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'variant_id = ?',
      whereArgs: [variantId],
    );
    return result.isNotEmpty;
  }

  /// Tüm favorileri getir
  Future<List<int>> getAllFavorites() async {
    final db = await database;
    final result = await db.query('favorites', orderBy: 'added_at DESC');
    return result.map((row) => row['variant_id'] as int).toList();
  }

  /// Çevrim dışı senkronize edilmemiş favorileri getir
  Future<List<int>> getUnsyncedFavorites() async {
    final db = await database;
    final result = await db.query(
      'favorites',
      where: 'synced_offline = ?',
      whereArgs: [0],
      orderBy: 'added_at ASC',
    );
    return result.map((row) => row['variant_id'] as int).toList();
  }

  /// Favoriyi çevrim dışı senkronize edildi olarak işaretle
  Future<void> markFavoriteSynced(int variantId) async {
    final db = await database;
    await db.update(
      'favorites',
      {'synced_offline': 1},
      where: 'variant_id = ?',
      whereArgs: [variantId],
    );
  }

  // ========== GÖRÜNTÜLEME GEÇMİŞİ İŞLEMLERİ ==========

  /// Görüntüleme geçmişine ekle
  Future<void> addToViewHistory(int variantId) async {
    final db = await database;
    await db.insert('view_history', {
      'variant_id': variantId,
      'viewed_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  /// Son görüntülenen sikkeleri getir (benzersiz, sıralı)
  Future<List<int>> getRecentlyViewed({int limit = 50}) async {
    final db = await database;
    final result = await db.rawQuery('''
      SELECT DISTINCT variant_id
      FROM view_history
      ORDER BY viewed_at DESC
      LIMIT ?
    ''', [limit]);
    return result.map((row) => row['variant_id'] as int).toList();
  }

  /// Belirli bir sikkenin görüntüleme sayısını getir
  Future<int> getViewCount(int variantId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM view_history WHERE variant_id = ?',
      [variantId],
    );
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Eski görüntüleme kayıtlarını temizle (son 100 hariç)
  Future<void> cleanOldViewHistory({int keepRecent = 100}) async {
    final db = await database;
    await db.rawDelete('''
      DELETE FROM view_history
      WHERE id NOT IN (
        SELECT id FROM view_history
        ORDER BY viewed_at DESC
        LIMIT ?
      )
    ''', [keepRecent]);
  }

  // ========== TARAMA GEÇMİŞİ İŞLEMLERİ ==========

  /// Tarama kaydı ekle, kayıt id'sini döndür
  Future<int> addScanRecord({
    String? imagePath,
    String? reverseImagePath,
    int? topArticleId,
    String? topTitle,
    double? topConfidence,
    required int matchCount,
    String? matchesJson,
  }) async {
    final db = await database;
    return await db.insert('scan_history', {
      'scanned_at': DateTime.now().millisecondsSinceEpoch,
      'image_path': imagePath,
      'reverse_image_path': reverseImagePath,
      'top_article_id': topArticleId,
      'top_title': topTitle,
      'top_confidence': topConfidence,
      'match_count': matchCount,
      'matches_json': matchesJson,
    });
  }

  /// Tarama geçmişini getir (yeniden eskiye)
  Future<List<Map<String, dynamic>>> getScanHistory({int limit = 100}) async {
    final db = await database;
    return await db.query(
      'scan_history',
      orderBy: 'scanned_at DESC',
      limit: limit,
    );
  }

  /// Tek tarama kaydını sil
  Future<void> deleteScanRecord(int id) async {
    final db = await database;
    await db.delete('scan_history', where: 'id = ?', whereArgs: [id]);
  }

  /// Tüm tarama geçmişini sil
  Future<void> clearScanHistory() async {
    final db = await database;
    await db.delete('scan_history');
  }

  // ========== KOLEKSİYONLAR İŞLEMLERİ ==========

  /// Yeni koleksiyon oluştur
  Future<int> createCollection(String name, {String? description}) async {
    final db = await database;
    final now = DateTime.now().millisecondsSinceEpoch;
    return await db.insert('collections', {
      'name': name,
      'description': description,
      'created_at': now,
      'updated_at': now,
    });
  }

  /// Koleksiyon güncelle
  Future<void> updateCollection(int collectionId, {String? name, String? description}) async {
    final db = await database;
    final updates = <String, dynamic>{
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (name != null) updates['name'] = name;
    if (description != null) updates['description'] = description;

    await db.update(
      'collections',
      updates,
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  /// Koleksiyon sil (CASCADE ile collection_items da silinir)
  Future<void> deleteCollection(int collectionId) async {
    final db = await database;
    await db.delete('collections', where: 'id = ?', whereArgs: [collectionId]);
  }

  /// Tüm koleksiyonları getir
  Future<List<Map<String, dynamic>>> getAllCollections() async {
    final db = await database;
    final collections = await db.query('collections', orderBy: 'created_at DESC');

    // Her koleksiyon için item sayısını ekle
    final result = <Map<String, dynamic>>[];
    for (final collection in collections) {
      final itemCount = Sqflite.firstIntValue(
        await db.rawQuery(
          'SELECT COUNT(*) FROM collection_items WHERE collection_id = ?',
          [collection['id']],
        ),
      ) ?? 0;

      result.add({
        ...collection,
        'item_count': itemCount,
      });
    }
    return result;
  }

  /// Belirli bir koleksiyonu getir
  Future<Map<String, dynamic>?> getCollection(int collectionId) async {
    final db = await database;
    final result = await db.query(
      'collections',
      where: 'id = ?',
      whereArgs: [collectionId],
    );

    if (result.isEmpty) return null;

    final collection = result.first;
    final itemCount = Sqflite.firstIntValue(
      await db.rawQuery(
        'SELECT COUNT(*) FROM collection_items WHERE collection_id = ?',
        [collectionId],
      ),
    ) ?? 0;

    return {
      ...collection,
      'item_count': itemCount,
    };
  }

  /// Koleksiyona sikke ekle
  Future<void> addToCollection(int collectionId, int variantId, {String? notes}) async {
    final db = await database;
    await db.insert(
      'collection_items',
      {
        'collection_id': collectionId,
        'variant_id': variantId,
        'notes': notes,
        'added_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Koleksiyon updated_at güncelle
    await db.update(
      'collections',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  /// Koleksiyondan sikke çıkar
  Future<void> removeFromCollection(int collectionId, int variantId) async {
    final db = await database;
    await db.delete(
      'collection_items',
      where: 'collection_id = ? AND variant_id = ?',
      whereArgs: [collectionId, variantId],
    );

    // Koleksiyon updated_at güncelle
    await db.update(
      'collections',
      {'updated_at': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [collectionId],
    );
  }

  /// Koleksiyon item notunu güncelle
  Future<void> updateCollectionItemNotes(int collectionId, int variantId, String? notes) async {
    final db = await database;
    await db.update(
      'collection_items',
      {'notes': notes},
      where: 'collection_id = ? AND variant_id = ?',
      whereArgs: [collectionId, variantId],
    );
  }

  /// Belirli bir koleksiyondaki sikkeleri getir
  Future<List<int>> getCollectionItems(int collectionId) async {
    final db = await database;
    final result = await db.query(
      'collection_items',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'added_at DESC',
    );
    return result.map((row) => row['variant_id'] as int).toList();
  }

  /// Belirli bir koleksiyondaki sikkeleri detaylı getir (notes ile)
  Future<List<Map<String, dynamic>>> getCollectionItemsWithNotes(int collectionId) async {
    final db = await database;
    return await db.query(
      'collection_items',
      where: 'collection_id = ?',
      whereArgs: [collectionId],
      orderBy: 'added_at DESC',
    );
  }

  /// Bir sikke hangi koleksiyonlarda var
  Future<List<int>> getCollectionsForVariant(int variantId) async {
    final db = await database;
    final result = await db.query(
      'collection_items',
      columns: ['collection_id'],
      where: 'variant_id = ?',
      whereArgs: [variantId],
    );
    return result.map((row) => row['collection_id'] as int).toList();
  }

  /// Bir sikke belirli bir koleksiyonda mı kontrol et
  Future<bool> isInCollection(int collectionId, int variantId) async {
    final db = await database;
    final result = await db.query(
      'collection_items',
      where: 'collection_id = ? AND variant_id = ?',
      whereArgs: [collectionId, variantId],
    );
    return result.isNotEmpty;
  }

  // ========== TEMİZLEME ==========

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('variants');
    await db.delete('images');
    await db.delete('download_queue');
    await db.delete('favorites');
    await db.delete('view_history');
    await db.delete('scan_history');
    await db.delete('collections');
    await db.delete('collection_items');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}