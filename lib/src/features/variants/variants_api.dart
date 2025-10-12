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
    try {
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

      // Debug: API yanıtını göster
      print('🔍 API Response type: ${res.data.runtimeType}');
      print('🔍 API Response keys: ${res.data?.keys}');
      
      // Güvenli data parse
      final responseData = res.data;
      if (responseData is! Map<String, dynamic>) {
        throw Exception('Invalid response format: expected Map, got ${responseData.runtimeType}');
      }

      final dataList = responseData['data'];
      if (dataList is! List) {
        throw Exception('Invalid data format: expected List, got ${dataList.runtimeType}');
      }

      final variants = <Variant>[];
      for (var item in dataList) {
        try {
          if (item is Map<String, dynamic>) {
            variants.add(Variant.fromJson(item));
          }
        } catch (e) {
          print('⚠️ Failed to parse variant: $e');
          print('⚠️ Item: $item');
        }
      }

      final meta = Map<String, dynamic>.from(responseData['meta'] ?? {});
      return (variants, meta);
    } catch (e, stackTrace) {
      print('❌ API Error: $e');
      print('❌ Stack: $stackTrace');
      rethrow;
    }
  }

  Future<Variant> getVariant(int articleId, {bool includeImages = true}) async {
    final res = await _client.dio.get('/variants/$articleId', queryParameters: {
      if (includeImages) 'include': 'images',
    });
    final j = res.data['data'] as Map<String, dynamic>;
    return Variant.fromJson({...j, ...?j['_raw']});
  }

  Future<List<VariantImage>> images(int articleId, {bool wm = true, bool abs = true}) async {
    final res = await _client.dio.get('/variants/$articleId/images', queryParameters: {
      'wm': wm ? 1 : 0,
      'abs': abs ? 1 : 0,
    });
    return (res.data['data'] as List).map((e) => VariantImage.fromJson(e)).toList();
  }

  /// Liste için tek görsel çeker (thumbnail için)
  Future<String?> getFirstImageUrl(int articleId, {bool wm = true}) async {
    try {
      final imgs = await images(articleId, wm: wm, abs: true);
      return imgs.isNotEmpty ? imgs.first.url : null;
    } catch (e) {
      return null;
    }
  }
}

final variantsApiProvider = Provider<VariantsApi>((ref) => VariantsApi(ref));