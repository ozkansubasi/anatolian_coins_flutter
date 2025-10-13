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
    
    print('🔍 List response type: ${res.data.runtimeType}');
    
    final data = (res.data['data'] as List).map((e) => Variant.fromJson(e)).toList();
    return (data, Map<String, dynamic>.from(res.data['meta'] ?? {}));
  }

  Future<Variant> getVariant(int articleId, {bool includeImages = true}) async {
    print('🔵 GET variant: $articleId');
    
    final res = await _client.dio.get('/variants/$articleId', queryParameters: {
      if (includeImages) 'include': 'images',
    });
    
    print('🔍 Variant response type: ${res.data.runtimeType}');
    print('🔍 Variant response keys: ${(res.data as Map).keys.toList()}');
    
    final j = res.data['data'] as Map<String, dynamic>;
    
    print('📊 Raw data: article_id=${j['article_id']}, uid=${j['uid']}');
    print('📊 Raw data: region=${j['region_code']}, material=${j['material_value']}');
    
    return Variant.fromJson({...j, ...?j['_raw']});
  }

  Future<List<VariantImage>> images(int articleId, {bool wm = true, bool abs = true}) async {
    print('🔵 GET images: article_id=$articleId, wm=$wm, abs=$abs');
    
    final res = await _client.dio.get('/variants/$articleId/images', queryParameters: {
      'wm': wm ? 1 : 0,
      'abs': abs ? 1 : 0, // ✅ Bu parametre doğru gönderiliyor
    });
    
    print('🔍 Images response type: ${res.data.runtimeType}');
    
    if (res.data is Map && res.data['data'] is List) {
      final imgList = res.data['data'] as List;
      print('🖼️ Images count in response: ${imgList.length}');
      
      if (imgList.isNotEmpty) {
        print('🔗 First image raw: ${imgList[0]}');
      }
      
      final images = imgList.map((e) => VariantImage.fromJson(e)).toList();
      
      if (images.isNotEmpty) {
        print('🔗 First image URL: ${images.first.url}');
        print('🔗 First image URL_RAW: ${images.first.urlRaw}');
      }
      
      return images;
    }
    
    print('⚠️ Unexpected response format for images');
    return [];
  }

  /// İlk görselin URL'ini döndür (liste için thumb)
  Future<String?> getFirstImageUrl(int articleId, {bool wm = true}) async {
    try {
      final imgs = await images(articleId, wm: wm, abs: true);
      return imgs.isNotEmpty ? imgs.first.url : null;
    } catch (e) {
      print('⚠️ getFirstImageUrl error: $e');
      return null;
    }
  }
}

final variantsApiProvider = Provider<VariantsApi>((ref) => VariantsApi(ref));