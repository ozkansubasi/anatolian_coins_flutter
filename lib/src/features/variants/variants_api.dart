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
    bool hasImages = false,           // ❗ varsayılan: kapalı
    int page = 1,
    int perPage = 20,
    String sort = 'uid_asc',          // ❗ güvenli varsayılan
  }) async {
    final res = await _client.dio.get('/variants', queryParameters: {
      if (mint != null && mint.isNotEmpty) 'filter[mint]': mint,
      if (authority != null && authority.isNotEmpty) 'filter[authority]': authority,
      if (material != null && material.isNotEmpty) 'filter[material]': material,
      if (region != null && region.isNotEmpty) 'filter[region]': region,
      if (yearFrom != null) 'filter[year_from]': yearFrom,
      if (yearTo != null) 'filter[year_to]': yearTo,
      if (hasImages) 'filter[has_images]': 1,  // backend destekliyorsa işe yarar
      'page': page,
      'per_page': perPage,
      'sort': sort,
    });
    final data = (res.data['data'] as List).map((e) => Variant.fromJson(e)).toList();
    return (data, Map<String, dynamic>.from(res.data['meta'] ?? {}));
  }

  Future<Variant> getVariant(int articleId, {bool includeImages = true}) async {
    final res = await _client.dio.get('/variants/$articleId', queryParameters: {
      if (includeImages) 'include': 'images',
    });
    final j = res.data['data'] as Map<String, dynamic>;
    return Variant.fromJson({...j, ...?j['_raw']});
  }

  Future<List<VariantImage>> images(int articleId, {bool wm = true, bool abs = true}) async { // ❗ abs=TRUE
    final res = await _client.dio.get('/variants/$articleId/images', queryParameters: {
      'wm': wm ? 1 : 0,
      'abs': abs ? 1 : 0,
    });
    return (res.data['data'] as List).map((e) => VariantImage.fromJson(e)).toList();
  }
}

final variantsApiProvider = Provider<VariantsApi>((ref) => VariantsApi(ref));
