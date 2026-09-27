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
    final factTitle = json['fact_title'] ?? json['ancient_name'] ?? '';
    final factDescription = json['fact_description'] ?? json['modern_name'] ?? '';

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

  /// Oturum içi önbellek (bölge|kategori|dil|limit): bölge sayfasına her dönüşte
  /// ticker yeniden istenip birkaç saniye dönmesin. Sunucu da 24 sa önbelliyor;
  /// boş sonuç (hata dahil) saklanmaz, bir sonraki açılışta yeniden denenir.
  static final _cache = <String, List<TickerItem>>{};

  static String _key(String? region, String? category, String? language, int limit) =>
      '${region ?? ''}|${category ?? ''}|${language ?? ''}|$limit';

  /// Önbellekteki öğeler (yoksa null) — istek atmadan, eşzamanlı.
  List<TickerItem>? cachedItems({
    String? region,
    String? category,
    String? language,
    int limit = 20,
  }) =>
      _cache[_key(region, category, language, limit)];

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
    final key = _key(region, category, language, limit);
    final cached = _cache[key];
    if (cached != null) return cached;

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
      final response = await _client.dio.get(
        '/ticker',
        queryParameters: params,
      );

      final data = response.data;

      if (data is Map && data['data'] != null && data['data']['items'] != null) {
        final items = data['data']['items'] as List;
        final parsed = items.map((item) => TickerItem.fromJson(item)).toList();
        if (parsed.isNotEmpty) _cache[key] = parsed;
        return parsed;
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
