import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../../models/variant.dart';
import '../../models/variant_image.dart';
import '../variants/variants_api.dart';
import 'offline_database.dart';

/// İndirme durumu
enum DownloadStatus {
  idle,
  downloading,
  completed,
  failed,
  paused,
}

/// İndirme progress state
class DownloadProgress {
  final int variantId;
  final DownloadStatus status;
  final int currentImage;
  final int totalImages;
  final double progress; // 0.0 - 1.0
  final String? error;

  DownloadProgress({
    required this.variantId,
    required this.status,
    this.currentImage = 0,
    this.totalImages = 0,
    this.progress = 0.0,
    this.error,
  });

  DownloadProgress copyWith({
    DownloadStatus? status,
    int? currentImage,
    int? totalImages,
    double? progress,
    String? error,
  }) {
    return DownloadProgress(
      variantId: variantId,
      status: status ?? this.status,
      currentImage: currentImage ?? this.currentImage,
      totalImages: totalImages ?? this.totalImages,
      progress: progress ?? this.progress,
      error: error ?? this.error,
    );
  }
}

class OfflineService {
  final VariantsApi _api;
  final OfflineDatabase _db;
  final Dio _dio;

  OfflineService(this._api, this._db) : _dio = Dio();

  /// Tek bir variant'ı indir (metadata + images)
  Future<void> downloadVariant(
    int articleId, {
    required Function(DownloadProgress) onProgress,
  }) async {
    try {
      // 1. Metadata'yı çek ve kaydet
      onProgress(DownloadProgress(
        variantId: articleId,
        status: DownloadStatus.downloading,
        progress: 0.1,
      ));

      final variant = await _api.getVariant(articleId, includeImages: true);
      await _db.saveVariant(variant);

      // 2. Görselleri çek
      final images = await _api.images(articleId, wm: false, abs: true);
      
      if (images.isEmpty) {
        onProgress(DownloadProgress(
          variantId: articleId,
          status: DownloadStatus.completed,
          progress: 1.0,
        ));
        return;
      }

      // 3. Her görseli indir
      final totalImages = images.length;
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        
        onProgress(DownloadProgress(
          variantId: articleId,
          status: DownloadStatus.downloading,
          currentImage: i + 1,
          totalImages: totalImages,
          progress: 0.1 + (0.9 * (i / totalImages)),
        ));

        try {
          final localPath = await _downloadImage(image.urlRaw, articleId, image.imageId);
          await _db.saveImage(image, localPath: localPath);
        } catch (e) {
          // Tek görsel hata verirse devam et
          await _db.saveImage(image); // localPath olmadan kaydet
        }
      }

      // 4. Tamamlandı
      onProgress(DownloadProgress(
        variantId: articleId,
        status: DownloadStatus.completed,
        currentImage: totalImages,
        totalImages: totalImages,
        progress: 1.0,
      ));
    } catch (e) {
      onProgress(DownloadProgress(
        variantId: articleId,
        status: DownloadStatus.failed,
        error: e.toString(),
      ));
      rethrow;
    }
  }

  /// Görseli indir ve local path döndür
  Future<String> _downloadImage(String url, int variantId, int imageId) async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/offline_images/$variantId');
    
    if (!await imagesDir.exists()) {
      await imagesDir.create(recursive: true);
    }

    final fileName = '$imageId.jpg';
    final filePath = path.join(imagesDir.path, fileName);

    await _dio.download(
      url,
      filePath,
      options: Options(
        responseType: ResponseType.bytes,
        followRedirects: true,
      ),
    );

    return filePath;
  }

  /// Variant'ın çevrimdışı olup olmadığını kontrol et
  Future<bool> isOfflineAvailable(int articleId) async {
    final variant = await _db.getVariant(articleId);
    return variant != null;
  }

  /// Çevrimdışı variant'ı getir
  Future<Variant?> getOfflineVariant(int articleId) async {
    return await _db.getVariant(articleId);
  }

  /// Çevrimdışı görselleri getir
  Future<List<VariantImage>> getOfflineImages(int articleId) async {
    return await _db.getImages(articleId);
  }

  /// Variant'ı sil (metadata + images + files)
  Future<void> deleteVariant(int articleId) async {
    // Dosyaları sil
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/offline_images/$articleId');
    
    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }

    // Veritabanından sil
    await _db.deleteVariant(articleId);
  }

  /// Tüm çevrimdışı verileri sil
  Future<void> clearAll() async {
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/offline_images');
    
    if (await imagesDir.exists()) {
      await imagesDir.delete(recursive: true);
    }

    await _db.clearAll();
  }

  /// İstatistikleri getir
  Future<Map<String, dynamic>> getStats() async {
    final dbStats = await _db.getStats();
    
    // Disk kullanımını hesapla
    final directory = await getApplicationDocumentsDirectory();
    final imagesDir = Directory('${directory.path}/offline_images');
    
    int totalSize = 0;
    if (await imagesDir.exists()) {
      await for (var entity in imagesDir.list(recursive: true)) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
    }

    return {
      ...dbStats,
      'diskUsageBytes': totalSize,
      'diskUsageMB': (totalSize / (1024 * 1024)).toStringAsFixed(2),
    };
  }
}

/// Provider
final offlineDatabaseProvider = Provider<OfflineDatabase>((ref) => OfflineDatabase());

final offlineServiceProvider = Provider<OfflineService>((ref) {
  final api = ref.watch(variantsApiProvider);
  final db = ref.watch(offlineDatabaseProvider);
  return OfflineService(api, db);
});

/// Download state yönetimi
class OfflineDownloadController extends StateNotifier<Map<int, DownloadProgress>> {
  final OfflineService _service;

  OfflineDownloadController(this._service) : super({});

  Future<void> downloadVariant(int articleId) async {
    if (state.containsKey(articleId) && 
        state[articleId]!.status == DownloadStatus.downloading) {
      return; // Zaten indiriliyor
    }

    await _service.downloadVariant(
      articleId,
      onProgress: (progress) {
        state = {...state, articleId: progress};
      },
    );
  }

  Future<void> deleteVariant(int articleId) async {
    await _service.deleteVariant(articleId);
    state = {...state}..remove(articleId);
  }

  Future<bool> isAvailable(int articleId) async {
    return await _service.isOfflineAvailable(articleId);
  }

  DownloadProgress? getProgress(int articleId) => state[articleId];
}

final offlineDownloadControllerProvider = 
    StateNotifierProvider<OfflineDownloadController, Map<int, DownloadProgress>>((ref) {
  final service = ref.watch(offlineServiceProvider);
  return OfflineDownloadController(service);
});