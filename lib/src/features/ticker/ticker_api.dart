import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';

/// Ticker item model
class TickerItem {
  final int id;
  final String factTitle;
  final String factDescription;
  final String? regionCode;
  final String fullText;

  TickerItem({
    required this.id,
    required this.factTitle,
    required this.factDescription,
    this.regionCode,
    required this.fullText,
  });

  factory TickerItem.fromJson(Map<String, dynamic> json) {
    // Debug: Print all keys and values from JSON
    debugPrint('🎫 TickerItem.fromJson RAW JSON keys: ${json.keys.toList()}');
    debugPrint('🎫 TickerItem.fromJson fact_title: ${json['fact_title']}');
    debugPrint('🎫 TickerItem.fromJson fact_description: ${json['fact_description']}');
    debugPrint('🎫 TickerItem.fromJson title: ${json['title']}');
    debugPrint('🎫 TickerItem.fromJson introtext: ${json['introtext']}');

    final factTitle = json['fact_title'] ?? json['ancient_name'] ?? '';
    final factDescription = json['fact_description'] ?? json['modern_name'] ?? '';

    debugPrint('🎫 TickerItem PARSED - factTitle: "$factTitle", factDescription: "$factDescription"');

    return TickerItem(
      id: json['id'] ?? 0,
      factTitle: factTitle,
      factDescription: factDescription,
      regionCode: json['region_code'],
      fullText: json['full_text'] ?? '',
    );
  }
}

/// Ticker API service
class TickerApi {
  final ApiClient _client;

  TickerApi(this._client);

  /// Get ticker items
  /// [region] - Region code filter (e.g., 'lydia-coins')
  /// [category] - Category alias (default: 'darphane-isimleri')
  /// [language] - Language code (e.g., 'tr-TR', 'en-GB', '*' for all)
  /// [limit] - Number of items to return
  Future<List<TickerItem>> getTickerItems({
    String? region,
    String? category,
    String? language,
    int limit = 20,
  }) async {
    final params = <String, String>{
      'limit': limit.toString(),
    };

    if (region != null && region.isNotEmpty) {
      params['region'] = region;
    }

    if (category != null && category.isNotEmpty) {
      params['category'] = category;
    }

    if (language != null && language.isNotEmpty) {
      params['language'] = language;
    }

    try {
      debugPrint('🎫 Ticker API Request: /ticker with params: $params');
      final response = await _client.dio.get(
        '/ticker',
        queryParameters: params,
      );

      final data = response.data;
      debugPrint('🎫 Ticker API Response: ${data.runtimeType}');
      debugPrint('🎫 Ticker API Data: $data');

      if (data is Map && data['data'] != null && data['data']['items'] != null) {
        final items = data['data']['items'] as List;
        debugPrint('🎫 Ticker API Found ${items.length} items');
        return items.map((item) => TickerItem.fromJson(item)).toList();
      }
    } catch (e) {
      debugPrint('❌ Ticker API Error: $e');
    }

    return [];
  }
}

/// Provider for TickerApi
final tickerApiProvider = Provider<TickerApi>((ref) {
  final client = ref.watch(apiClientProvider);
  return TickerApi(client);
});
