import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// Antik yerleşim ya da darphane — sitedeki `/tr/antik-harita` ile aynı kaynak
/// (`/v1/locations`). Liste açıklama taşımaz; özet dokununca [MapLocationsApi.summary]
/// ile çekilir (site de böyle yapıyor).
class MapLocation {
  final String id;
  final double lat;
  final double lng;
  final String name;

  /// Bu yerleşim sikke basmış (darphane) mı?
  final bool hasCoins;

  /// Sitedeki makale adresi: `…/<kategori>/<makaleId>-<alias>`.
  final String? url;

  const MapLocation({
    required this.id,
    required this.lat,
    required this.lng,
    required this.name,
    required this.hasCoins,
    this.url,
  });

  factory MapLocation.fromJson(Map<String, dynamic> j) => MapLocation(
        id: '${j['id'] ?? ''}',
        lat: (j['lat'] as num?)?.toDouble() ?? 0,
        lng: (j['lng'] as num?)?.toDouble() ?? 0,
        name: '${j['name'] ?? ''}',
        hasCoins: j['has_coins'] == true || j['has_coins'] == 1,
        url: j['url'] as String?,
      );

  /// Makale kimliği (uygulama içi `/article/:id`); adres beklenen biçimde değilse null.
  int? get articleId {
    final u = url;
    if (u == null) return null;
    final m = RegExp(r'/(\d+)-[^/]*/?$').firstMatch(u);
    return m == null ? null : int.tryParse(m.group(1)!);
  }
}

class MapLocationsApi {
  MapLocationsApi(this._client);

  final ApiClient _client;

  /// Oturum içi önbellek: aynı bölgeye dönüşte istek atılmaz.
  static final _summaries = <String, String>{};

  /// Görünen alandaki yerleşimler (site ile aynı uç ve sınır: `limit=2000`).
  Future<List<MapLocation>> inBounds({
    required double swLat,
    required double swLng,
    required double neLat,
    required double neLng,
    required String lang,
  }) async {
    try {
      final response = await _client.dio.get('/locations', queryParameters: {
        'ne_lat': neLat,
        'ne_lng': neLng,
        'sw_lat': swLat,
        'sw_lng': swLng,
        'lang': lang,
        'limit': 2000,
      });
      final data = response.data;
      if (data is Map && data['data'] is List) {
        return (data['data'] as List)
            .whereType<Map>()
            .map((e) => MapLocation.fromJson(Map<String, dynamic>.from(e)))
            .where((l) => l.id.isNotEmpty && l.name.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('❌ locations: $e');
    }
    return const [];
  }

  /// Yerleşimin kısa özeti (sitedeki açılır kartın metni). Yoksa ya da hata olursa null.
  Future<String?> summary(String id, String lang) async {
    final key = '$lang|$id';
    final cached = _summaries[key];
    if (cached != null) return cached;
    try {
      final response = await _client.dio.get('/locations/${Uri.encodeComponent(id)}',
          queryParameters: {'lang': lang});
      final data = response.data;
      final s = (data is Map && data['data'] is Map) ? data['data']['summary'] : null;
      if (s is String && s.trim().isNotEmpty) {
        _summaries[key] = s.trim();
        return s.trim();
      }
    } catch (e) {
      debugPrint('❌ location summary: $e');
    }
    return null;
  }
}

final mapLocationsApiProvider = Provider<MapLocationsApi>((ref) {
  return MapLocationsApi(ref.watch(apiClientProvider));
});
