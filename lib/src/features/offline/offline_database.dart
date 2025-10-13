import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';

class OfflineDatabase {
  static Database? _database;
  static const String _dbName = 'anatolian_coins_offline.db';
  static const int _dbVersion = 1;

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

    // İndeksler
    await db.execute('CREATE INDEX idx_variants_slug ON variants(slug)');
    await db.execute('CREATE INDEX idx_images_variant ON images(variant_id)');
    await db.execute('CREATE INDEX idx_queue_status ON download_queue(status)');
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

  // ========== TEMİZLEME ==========

  Future<void> clearAll() async {
    final db = await database;
    await db.delete('variants');
    await db.delete('images');
    await db.delete('download_queue');
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}