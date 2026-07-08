import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../offline/offline_database.dart';
import '../offline/offline_service.dart';
import '../recognition/recognition_service.dart';

/// Tek bir tarama kaydı (scan_history satırı)
class ScanRecord {
  final int id;
  final DateTime scannedAt;
  final String? imagePath;
  final String? reverseImagePath;
  final int? topArticleId;
  final String? topTitle;
  final double? topConfidence;
  final int matchCount;
  final List<CoinMatch> matches;

  ScanRecord({
    required this.id,
    required this.scannedAt,
    this.imagePath,
    this.reverseImagePath,
    this.topArticleId,
    this.topTitle,
    this.topConfidence,
    required this.matchCount,
    required this.matches,
  });

  factory ScanRecord.fromRow(Map<String, dynamic> row) {
    var matches = <CoinMatch>[];
    final matchesJson = row['matches_json'] as String?;
    if (matchesJson != null && matchesJson.isNotEmpty) {
      try {
        matches = (jsonDecode(matchesJson) as List<dynamic>)
            .map((m) => CoinMatch.fromJson(m as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('ScanRecord: matches_json parse hatası: $e');
      }
    }

    return ScanRecord(
      id: row['id'] as int,
      scannedAt:
          DateTime.fromMillisecondsSinceEpoch(row['scanned_at'] as int),
      imagePath: row['image_path'] as String?,
      reverseImagePath: row['reverse_image_path'] as String?,
      topArticleId: row['top_article_id'] as int?,
      topTitle: row['top_title'] as String?,
      topConfidence: (row['top_confidence'] as num?)?.toDouble(),
      matchCount: row['match_count'] as int? ?? 0,
      matches: matches,
    );
  }
}

/// Tanıma sonuçlarını kalıcı tarama geçmişine yazar/okur.
/// Görseller silinen temp dosyalardan {docs}/scan_images/ altına kopyalanır.
class ScanHistoryService {
  final OfflineDatabase _db;

  ScanHistoryService(this._db);

  /// Başarılı bir tanıma sonucunu kaydet.
  /// Kayıt hatası tanıma akışını bozmasın diye exception fırlatmaz.
  Future<void> recordScan({
    required File obverseImage,
    File? reverseImage,
    required RecognitionResponse response,
  }) async {
    try {
      final imagesDir = await _scanImagesDir();
      final stamp = DateTime.now().millisecondsSinceEpoch;

      final obversePath = await _copyImage(obverseImage, imagesDir, '${stamp}_obv');
      final reversePath = reverseImage != null
          ? await _copyImage(reverseImage, imagesDir, '${stamp}_rev')
          : null;

      final top = response.matches.isNotEmpty ? response.matches.first : null;

      await _db.addScanRecord(
        imagePath: obversePath,
        reverseImagePath: reversePath,
        topArticleId: top?.articleId,
        topTitle: top?.title,
        topConfidence: top?.confidence,
        matchCount: response.matches.length,
        matchesJson: jsonEncode(
          response.matches.map((m) => m.toJson()).toList(),
        ),
      );
    } catch (e) {
      debugPrint('ScanHistoryService: tarama kaydedilemedi: $e');
    }
  }

  Future<List<ScanRecord>> getScans({int limit = 100}) async {
    final rows = await _db.getScanHistory(limit: limit);
    return rows.map(ScanRecord.fromRow).toList();
  }

  Future<void> deleteScan(ScanRecord record) async {
    await _db.deleteScanRecord(record.id);
    await _deleteFileIfExists(record.imagePath);
    await _deleteFileIfExists(record.reverseImagePath);
  }

  Future<void> clearAll() async {
    final rows = await _db.getScanHistory(limit: 10000);
    await _db.clearScanHistory();
    for (final row in rows) {
      await _deleteFileIfExists(row['image_path'] as String?);
      await _deleteFileIfExists(row['reverse_image_path'] as String?);
    }
  }

  Future<Directory> _scanImagesDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'scan_images'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<String?> _copyImage(File source, Directory dir, String name) async {
    try {
      if (!await source.exists()) return null;
      final ext = p.extension(source.path).isNotEmpty
          ? p.extension(source.path)
          : '.jpg';
      final target = File(p.join(dir.path, '$name$ext'));
      await source.copy(target.path);
      return target.path;
    } catch (e) {
      debugPrint('ScanHistoryService: görsel kopyalanamadı: $e');
      return null;
    }
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // Dosya silinemese de kayıt silinmiş sayılır
    }
  }
}

final scanHistoryServiceProvider = Provider<ScanHistoryService>((ref) {
  return ScanHistoryService(ref.watch(offlineDatabaseProvider));
});
