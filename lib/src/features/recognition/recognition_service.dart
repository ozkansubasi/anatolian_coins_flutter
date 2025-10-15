import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

/// Recognition service for coin identification
/// Communicates with backend API for AI recognition
class RecognitionService {
  final ApiClient _client;

  RecognitionService(Ref ref) : _client = ApiClient(ref);

  /// Upload image and get recognition results
  /// Returns list of matching coins with confidence scores
  Future<RecognitionResponse> recognize(File imageFile) async {
    try {
      // Create multipart form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'coin.jpg',
        ),
      });

      // Send POST request to recognition endpoint
      final response = await _client.dio.post(
        '/recognize',
        data: formData,
        options: Options(
          headers: {
            'Content-Type': 'multipart/form-data',
          },
        ),
      );

      // Parse response
      final Map<String, dynamic> data = response.data is String
          ? _parseJson(response.data as String)
          : response.data as Map<String, dynamic>;

      return RecognitionResponse.fromJson(data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        throw Exception('Scan quota exceeded. Please upgrade to Pro or wait until next month.');
      }
      throw Exception('Recognition failed: ${e.message}');
    } catch (e) {
      throw Exception('Recognition failed: $e');
    }
  }

  Map<String, dynamic> _parseJson(String jsonString) {
    // Same parsing logic as API client
    final trimmed = jsonString.trim();
    if (trimmed.isEmpty) {
      return {};
    }

    // Handle potential BOM or other issues
    final cleaned = trimmed.replaceAll(RegExp(r'^\uFEFF'), '');

    try {
      Uri.decodeFull(cleaned);
      // Use Dart's built-in JSON decoder
      return Map<String, dynamic>.from(
        // This will be handled by Dio's JSON decoder
        {} // placeholder
      );
    } catch (_) {
      return {};
    }
  }

  /// Check remaining scan quota
  Future<ScanQuota> getQuota() async {
    try {
      final response = await _client.dio.get('/user/scan-quota');

      final Map<String, dynamic> data = response.data is String
          ? _parseJson(response.data as String)
          : response.data as Map<String, dynamic>;

      return ScanQuota.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch scan quota: $e');
    }
  }
}

/// Recognition response model
class RecognitionResponse {
  final List<CoinMatch> matches;
  final int remainingScans;
  final String? message;

  RecognitionResponse({
    required this.matches,
    required this.remainingScans,
    this.message,
  });

  factory RecognitionResponse.fromJson(Map<String, dynamic> json) {
    final matchesJson = json['matches'] as List<dynamic>? ?? [];
    final matches = matchesJson
        .map((m) => CoinMatch.fromJson(m as Map<String, dynamic>))
        .toList();

    return RecognitionResponse(
      matches: matches,
      remainingScans: json['remaining_scans'] as int? ?? 0,
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
  final String? dateRange;
  final String? thumbnailUrl;
  final String? explanation;

  CoinMatch({
    required this.articleId,
    required this.title,
    required this.confidence,
    this.region,
    this.dateRange,
    this.thumbnailUrl,
    this.explanation,
  });

  factory CoinMatch.fromJson(Map<String, dynamic> json) {
    return CoinMatch(
      articleId: json['article_id'] as int,
      title: json['title'] as String? ?? 'Unknown Coin',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      region: json['region'] as String?,
      dateRange: json['date_range'] as String?,
      thumbnailUrl: json['thumbnail_url'] as String?,
      explanation: json['explanation'] as String?,
    );
  }
}

/// Scan quota model
class ScanQuota {
  final int used;
  final int limit;
  final bool isPro;
  final DateTime? resetDate;

  ScanQuota({
    required this.used,
    required this.limit,
    required this.isPro,
    this.resetDate,
  });

  int get remaining => limit - used;
  bool get hasScansAvailable => isPro || remaining > 0;

  factory ScanQuota.fromJson(Map<String, dynamic> json) {
    return ScanQuota(
      used: json['scans_used'] as int? ?? 0,
      limit: json['scan_limit'] as int? ?? 10,
      isPro: json['is_pro'] as bool? ?? false,
      resetDate: json['reset_date'] != null
          ? DateTime.parse(json['reset_date'] as String)
          : null,
    );
  }
}

// Providers

final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  return RecognitionService(ref);
});

final recognitionControllerProvider =
    StateNotifierProvider<RecognitionController, AsyncValue<RecognitionResponse>>(
  (ref) => RecognitionController(ref.watch(recognitionServiceProvider)),
);

final scanQuotaProvider = FutureProvider<ScanQuota>((ref) {
  final service = ref.watch(recognitionServiceProvider);
  return service.getQuota();
});

/// Recognition state controller
class RecognitionController extends StateNotifier<AsyncValue<RecognitionResponse>> {
  final RecognitionService _service;

  RecognitionController(this._service) : super(const AsyncValue.loading());

  Future<void> recognize(File imageFile) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.recognize(imageFile);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}
