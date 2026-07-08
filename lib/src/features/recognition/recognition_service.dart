import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/network_utils.dart';
import '../../auth/auth_controller.dart';
import '../../core/region_data.dart';

/// Recognition service for coin identification
/// Communicates with Joomla API (which proxies to AI service)
/// Handles authentication and quota management
class RecognitionService {
  final ApiClient _client;

  RecognitionService(this._client);

  /// Check if recognition service is available
  /// Returns null if available, or an error message if not
  Future<String?> checkServiceAvailability() async {
    // Check internet connectivity first
    final hasInternet = await NetworkUtils.hasInternetConnection();
    if (!hasInternet) {
      return 'İnternet bağlantısı yok';
    }

    // Check AI service health
    final health = await NetworkUtils.checkAiServiceHealth();
    if (!health.isHealthy) {
      return health.statusMessage;
    }

    return null; // Service is available
  }

  /// Pre-flight check before recognition
  /// Throws RecognitionException if service is not available
  Future<void> _preFlightCheck() async {
    debugPrint('🔵 [RecognitionService] Running pre-flight checks...');

    // Check internet connectivity
    final hasInternet = await NetworkUtils.hasInternetConnection();
    if (!hasInternet) {
      debugPrint('❌ [RecognitionService] No internet connection');
      throw RecognitionException(
        'İnternet bağlantısı yok',
        isServiceUnavailable: true,
      );
    }
    debugPrint('✅ [RecognitionService] Internet connection OK');

    // Check AI service health (with timeout)
    try {
      final health = await NetworkUtils.checkAiServiceHealth();
      if (!health.isHealthy) {
        debugPrint('❌ [RecognitionService] AI service not healthy: ${health.statusMessage}');
        throw RecognitionException(
          health.statusMessage,
          isServiceUnavailable: true,
        );
      }
      debugPrint('✅ [RecognitionService] AI service health OK');
    } catch (e) {
      if (e is RecognitionException) rethrow;
      debugPrint('⚠️ [RecognitionService] Health check failed, proceeding anyway: $e');
      // Don't block recognition if health check fails - let the actual request fail
    }
  }

  /// Upload single image and get recognition results
  /// Returns list of matching coins with confidence scores
  /// Uses Joomla API endpoint which proxies to AI service
  Future<RecognitionResponse> recognize(File imageFile, {bool skipPreFlight = false}) async {
    try {
      // Pre-flight check (can be skipped for retry attempts)
      if (!skipPreFlight) {
        await _preFlightCheck();
      }

      debugPrint('🔵 [RecognitionService] Starting single-image recognition...');
      debugPrint('🔵 [RecognitionService] Image path: ${imageFile.path}');
      debugPrint('🔵 [RecognitionService] Image exists: ${await imageFile.exists()}');
      debugPrint('🔵 [RecognitionService] Image size: ${await imageFile.length()} bytes');

      // Create multipart form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'coin.jpg',
        ),
      });

      debugPrint('🔵 [RecognitionService] Sending POST request to ${Env.baseUrl}/recognize...');

      // Send POST request to Joomla API (which proxies to AI service)
      // Auth token is automatically added by TokenInterceptor
      final response = await _client.dio.post(
        '/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      debugPrint('✅ [RecognitionService] Response received: ${response.statusCode}');
      debugPrint('🔵 [RecognitionService] Response data type: ${response.data.runtimeType}');

      // Parse response (ApiClient already handles JSON parsing)
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      debugPrint('🔵 [RecognitionService] Parsed data keys: ${data.keys}');
      final result = RecognitionResponse.fromJson(data);
      debugPrint('✅ [RecognitionService] Recognition successful! Matches: ${result.matches.length}');

      return result;
    } on DioException catch (e) {
      debugPrint('❌ [RecognitionService] DioException: ${e.type}');
      debugPrint('❌ [RecognitionService] Status code: ${e.response?.statusCode}');
      debugPrint('❌ [RecognitionService] Error message: ${e.message}');
      debugPrint('❌ [RecognitionService] Response data: ${e.response?.data}');

      if (e.response?.statusCode == 429) {
        throw RecognitionException(
          'Scan quota exceeded. Please upgrade to Pro or wait until next month.',
          isQuotaExceeded: true,
        );
      }
      if (e.response?.statusCode == 401) {
        throw RecognitionException(
          'Giriş yapmadan tanıma özelliği çalışmaz, lütfen giriş yapın',
          isAuthRequired: true,
        );
      }
      if (e.response?.statusCode == 503) {
        throw RecognitionException(
          'Recognition service temporarily unavailable. Please try again later.',
          isServiceUnavailable: true,
        );
      }
      throw RecognitionException('Recognition failed: ${e.message}');
    } catch (e, stack) {
      debugPrint('❌ [RecognitionService] Unexpected error: $e');
      debugPrint('❌ [RecognitionService] Stack trace: $stack');
      if (e is RecognitionException) rethrow;
      throw RecognitionException('Recognition failed: $e');
    }
  }

  /// Upload dual images (obverse + reverse) and get recognition results
  /// Returns list of matching coins with confidence scores
  /// Backend now supports dual images via 'image' (obverse) and 'reverse' fields
  Future<RecognitionResponse> recognizeDual(File obverseFile, File reverseFile, {bool skipPreFlight = false}) async {
    try {
      // Pre-flight check (can be skipped for retry attempts)
      if (!skipPreFlight) {
        await _preFlightCheck();
      }

      debugPrint('🔵 [RecognitionService] Starting dual-image recognition...');
      debugPrint('🔵 [RecognitionService] Obverse: ${obverseFile.path}');
      debugPrint('🔵 [RecognitionService] Reverse: ${reverseFile.path}');
      debugPrint('🔵 [RecognitionService] Obverse exists: ${await obverseFile.exists()}');
      debugPrint('🔵 [RecognitionService] Reverse exists: ${await reverseFile.exists()}');
      debugPrint('🔵 [RecognitionService] Obverse size: ${await obverseFile.length()} bytes');
      debugPrint('🔵 [RecognitionService] Reverse size: ${await reverseFile.length()} bytes');

      // Create multipart form data with both images
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          obverseFile.path,
          filename: 'coin_obverse.jpg',
        ),
        'reverse': await MultipartFile.fromFile(
          reverseFile.path,
          filename: 'coin_reverse.jpg',
        ),
      });

      debugPrint('🔵 [RecognitionService] Sending POST request to ${Env.baseUrl}/recognize (dual images)...');

      // Send POST request to Joomla API (which proxies to AI service)
      // Auth token is automatically added by TokenInterceptor
      final response = await _client.dio.post(
        '/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      debugPrint('✅ [RecognitionService] Response received: ${response.statusCode}');
      debugPrint('🔵 [RecognitionService] Response data type: ${response.data.runtimeType}');

      // Parse response (ApiClient already handles JSON parsing)
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      debugPrint('🔵 [RecognitionService] Parsed data keys: ${data.keys}');
      final result = RecognitionResponse.fromJson(data);
      debugPrint('✅ [RecognitionService] Recognition successful! Matches: ${result.matches.length}');

      return result;
    } on DioException catch (e) {
      debugPrint('❌ [RecognitionService] DioException: ${e.type}');
      debugPrint('❌ [RecognitionService] Status code: ${e.response?.statusCode}');
      debugPrint('❌ [RecognitionService] Error message: ${e.message}');
      debugPrint('❌ [RecognitionService] Response data: ${e.response?.data}');

      if (e.response?.statusCode == 429) {
        throw RecognitionException(
          'Scan quota exceeded. Please upgrade to Pro or wait until next month.',
          isQuotaExceeded: true,
        );
      }
      if (e.response?.statusCode == 401) {
        throw RecognitionException(
          'Giriş yapmadan tanıma özelliği çalışmaz, lütfen giriş yapın',
          isAuthRequired: true,
        );
      }
      if (e.response?.statusCode == 503) {
        throw RecognitionException(
          'Recognition service temporarily unavailable. Please try again later.',
          isServiceUnavailable: true,
        );
      }
      throw RecognitionException('Recognition failed: ${e.message}');
    } catch (e, stack) {
      debugPrint('❌ [RecognitionService] Unexpected error: $e');
      debugPrint('❌ [RecognitionService] Stack trace: $stack');
      if (e is RecognitionException) rethrow;
      throw RecognitionException('Recognition failed: $e');
    }
  }

  /// Check remaining scan quota
  Future<ScanQuota> getQuota() async {
    try {
      final response = await _client.dio.get('/user/scan-quota');

      // ApiClient already handles JSON parsing
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      return ScanQuota.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch scan quota: $e');
    }
  }
}

/// Custom exception for recognition errors
class RecognitionException implements Exception {
  final String message;
  final bool isQuotaExceeded;
  final bool isAuthRequired;
  final bool isServiceUnavailable;

  RecognitionException(
    this.message, {
    this.isQuotaExceeded = false,
    this.isAuthRequired = false,
    this.isServiceUnavailable = false,
  });

  @override
  String toString() => message;
}

/// Recognition response model
class RecognitionResponse {
  final List<CoinMatch> matches;
  final ScanQuota? quota;
  final int? processingTimeMs;
  final String? ocrText;
  final String? message;

  RecognitionResponse({
    required this.matches,
    this.quota,
    this.processingTimeMs,
    this.ocrText,
    this.message,
  });

  /// Convenience getter for remaining scans (backward compatibility)
  int get remainingScans => quota?.remaining ?? 0;

  factory RecognitionResponse.fromJson(Map<String, dynamic> json) {
    // Handle both direct response format and wrapped 'data' format from Joomla
    final data = json['data'] as Map<String, dynamic>? ?? json;

    final matchesJson = data['matches'] as List<dynamic>? ?? [];
    final matches = matchesJson
        .map((m) => CoinMatch.fromJson(m as Map<String, dynamic>))
        .toList();

    // Parse quota info if present (can be at top level or in data)
    ScanQuota? quota;
    if (json['quota'] != null) {
      quota = ScanQuota.fromJson(json['quota'] as Map<String, dynamic>);
    }

    return RecognitionResponse(
      matches: matches,
      quota: quota,
      processingTimeMs: data['processing_time_ms'] as int?,
      ocrText: data['ocr_text'] as String?,
      message: json['message'] as String?,
    );
  }
}

/// Coin match result model
class CoinMatch {
  final int articleId;
  final String title;
  final double confidence;
  final String? region;
  final String? regionName; // Category name instead of alias
  final String? mintName; // Mint name
  final String? dateRange;
  final String? thumbnailUrl;
  final String? explanation;

  CoinMatch({
    required this.articleId,
    required this.title,
    required this.confidence,
    this.region,
    this.regionName,
    this.mintName,
    this.dateRange,
    this.thumbnailUrl,
    this.explanation,
  });

  factory CoinMatch.fromJson(Map<String, dynamic> json) {
    final regionAlias = json['region'] as String?;

    // Construct date range from date_from and date_to
    String? dateRange;
    final dateFrom = json['date_from'];
    final dateTo = json['date_to'];
    if (dateFrom != null || dateTo != null) {
      dateRange = '${dateFrom ?? "?"} - ${dateTo ?? "?"}';
    }

    return CoinMatch(
      articleId: (json['article_id'] as num?)?.toInt() ??
          int.tryParse('${json['article_id']}') ??
          0,
      title: json['title'] as String? ?? 'Unknown Coin',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      region: regionAlias, // Alias (for compatibility)
      regionName: RegionData.getRegionName(regionAlias), // Client-side mapping
      mintName: json['mint_name'] as String?,
      dateRange: dateRange ?? json['date_range'] as String?, // Fallback to direct field
      thumbnailUrl: json['thumbnail_url'] as String?, // Not provided by AI service yet
      explanation: json['explanation'] as String?,
    );
  }

  /// Tarama geçmişine kaydetmek için; fromJson ile geri okunabilir.
  Map<String, dynamic> toJson() => {
        'article_id': articleId,
        'title': title,
        'confidence': confidence,
        'region': region,
        'mint_name': mintName,
        'date_range': dateRange,
        'thumbnail_url': thumbnailUrl,
        'explanation': explanation,
      };
}

/// Scan quota model
class ScanQuota {
  final int used;
  final int limit;
  final int _remaining; // Backend-provided remaining count
  final bool isPro;
  final DateTime? resetDate;

  ScanQuota({
    required this.used,
    required this.limit,
    required int remaining,
    required this.isPro,
    this.resetDate,
  }) : _remaining = remaining;

  /// Returns remaining scans. -1 means unlimited (Pro users)
  int get remaining => _remaining;

  /// Check if user has scans available
  bool get hasScansAvailable => isPro || _remaining > 0 || _remaining == -1;

  factory ScanQuota.fromJson(Map<String, dynamic> json) {
    final isPro = json['is_pro'] as bool? ?? false;
    final limit = json['scan_limit'] as int? ?? 10;
    final used = json['scans_used'] as int? ?? 0;

    // Use backend-provided remaining, or calculate if not provided
    int remaining;
    if (json['remaining'] != null) {
      remaining = json['remaining'] as int;
    } else {
      remaining = isPro ? -1 : (limit - used);
    }

    return ScanQuota(
      used: used,
      limit: limit,
      remaining: remaining,
      isPro: isPro,
      resetDate: json['reset_date'] != null
          ? DateTime.tryParse(json['reset_date'] as String)
          : null,
    );
  }
}

// Providers

final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  return RecognitionService(ref.watch(apiClientProvider));
});

final recognitionControllerProvider =
    StateNotifierProvider<RecognitionController, AsyncValue<RecognitionResponse>>(
  (ref) => RecognitionController(ref.watch(recognitionServiceProvider)),
);

final scanQuotaProvider = FutureProvider<ScanQuota>((ref) async {
  // Check if authenticated first
  final authController = ref.watch(authControllerProvider.notifier);
  final token = await authController.getValidAccessToken();

  if (token == null) {
    throw Exception('Authentication required');
  }

  final service = ref.watch(recognitionServiceProvider);
  return service.getQuota();
});

/// Recognition state controller
class RecognitionController extends StateNotifier<AsyncValue<RecognitionResponse>> {
  final RecognitionService _service;

  RecognitionController(this._service) : super(const AsyncValue.loading());

  Future<void> recognize(File imageFile, {bool skipPreFlight = false}) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.recognize(imageFile, skipPreFlight: skipPreFlight);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> recognizeDual(File obverseFile, File reverseFile, {bool skipPreFlight = false}) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.recognizeDual(obverseFile, reverseFile, skipPreFlight: skipPreFlight);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}
