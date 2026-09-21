import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../../core/api_client.dart';
import '../../models/variant.dart';
import '../../models/variant_image.dart';

class VariantsApi {
  final ApiClient _client;
  VariantsApi(Ref ref) : _client = ApiClient(ref);

  Future<(List<Variant>, Map<String, dynamic>)> list({
    String? mint,
    String? authority,
    String? material,
    String? region,
    int? yearFrom,
    int? yearTo,
    bool hasImages = false,
    int page = 1,
    int perPage = 20,
    String sort = 'uid_asc',
  }) async {
    debugPrint('🔵 API Request - region: $region, mint: $mint');
    
    final res = await _client.dio.get('/variants', queryParameters: {
      if (mint != null && mint.isNotEmpty) 'filter[mint]': mint,
      if (authority != null && authority.isNotEmpty) 'filter[authority]': authority,
      if (material != null && material.isNotEmpty) 'filter[material]': material,
      if (region != null && region.isNotEmpty) 'filter[region]': region,
      if (yearFrom != null) 'filter[year_from]': yearFrom,
      if (yearTo != null) 'filter[year_to]': yearTo,
      if (hasImages) 'filter[has_images]': 1,
      'page': page,
      'per_page': perPage,
      'sort': sort,
    });
    
    debugPrint('🔍 API Response type: ${res.data.runtimeType}');
    
    if (res.data['data'] != null && (res.data['data'] as List).isNotEmpty) {
      debugPrint('🔍 First item keys: ${(res.data['data'] as List).first.keys.toList()}');
      debugPrint('🔍 First item region: ${(res.data['data'] as List).first['region_code']}');
    }
    
    final data = (res.data['data'] as List).map((e) => Variant.fromJson(e)).toList();
    return (data, Map<String, dynamic>.from(res.data['meta'] ?? {}));
  }

  Future<Variant> getVariant(int articleId, {bool includeImages = true}) async {
    debugPrint('🔵 GET variant: $articleId');
    
    final res = await _client.dio.get('/variants/$articleId', queryParameters: {
      if (includeImages) 'include': 'images',
    });
    
    debugPrint('🔍 Variant response type: ${res.data.runtimeType}');
    debugPrint('🔍 Variant response keys: ${(res.data as Map).keys.toList()}');
    
    final j = res.data['data'] as Map<String, dynamic>;
    
    debugPrint('📊 Raw data: article_id=${j['article_id']}, uid=${j['uid']}');
    debugPrint('📊 Raw data: region=${j['region_code']}, material=${j['material_value']}');
    
    return Variant.fromJson({...j, ...?j['_raw']});
  }

  Future<List<VariantImage>> images(int articleId, {bool wm = true, bool abs = true}) async {
    debugPrint('🔵 GET images: article_id=$articleId, wm=$wm, abs=$abs');
    
    final res = await _client.dio.get('/variants/$articleId/images', queryParameters: {
      'wm': wm ? 1 : 0,
      'abs': abs ? 1 : 0,
    });
    
    debugPrint('🔍 Images response type: ${res.data.runtimeType}');
    
    if (res.data is Map && res.data['data'] is List) {
      final imgList = res.data['data'] as List;
      debugPrint('🖼️ Images count in response: ${imgList.length}');
      
      if (imgList.isNotEmpty) {
        debugPrint('🔗 First image raw: ${imgList[0]}');
      }
      
      final images = imgList.map((e) => VariantImage.fromJson(e)).toList();
      
      if (images.isNotEmpty) {
        debugPrint('🔗 First image URL: ${images.first.url}');
        debugPrint('🔗 First image URL_RAW: ${images.first.urlRaw}');
      }
      
      return images;
    }
    
    debugPrint('⚠️ Unexpected response format for images');
    return [];
  }

  Future<String?> getFirstImageUrl(int articleId, {bool wm = true}) async {
    try {
      final imgs = await images(articleId, wm: wm, abs: true);
      if (imgs.isEmpty) return null;

      final firstImage = imgs.first;
      // Try primary URL first, fallback to remote URL
      if (firstImage.url.isNotEmpty) {
        return firstImage.url;
      } else if (firstImage.remoteUrl != null && firstImage.remoteUrl!.isNotEmpty) {
        debugPrint('🌐 Using remote URL for image_id=${firstImage.imageId}');
        return firstImage.remoteUrl;
      }
      return null;
    } catch (e) {
      debugPrint('⚠️ getFirstImageUrl error: $e');
      return null;
    }
  }

  /// Bölgedeki darphaneler ve sikke sayıları (yalnız sikkesi olanlar).
  /// `facet_limit` verilmezse sunucu 15'te keser (Karya'da 32 darphane var).
  Future<Map<String, int>> mintCounts(String region) async {
    final res = await _client.dio.get('/variants/facets', queryParameters: {
      'filter[region]': region,
      'facet_limit': 100,
    });
    final data = res.data;
    final facets = data is Map ? (data['facets'] ?? (data['data'] as Map?)?['facets']) : null;
    final list = facets is Map ? facets['mint'] : null;
    if (list is! List) return const {};
    return {
      for (final m in list)
        if (m is Map && m['name'] is String) m['name'] as String: (m['count'] as num?)?.toInt() ?? 0,
    };
  }
}

final variantsApiProvider = Provider<VariantsApi>((ref) => VariantsApi(ref));