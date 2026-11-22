import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

/// Uygulamadan siteye girişli geçiş — sunucu eklentisi 1.28.0 + plg_system_numistrauth 1.3.0 (22 Kas 2026).
///
/// Uygulama Auth0'a geçici oturumla girer (`preferEphemeralSession`), tarayıcıda oturum kalmaz; bu yüzden
/// "Aboneliği yönet" → sitenin Hesabım sayfası misafir açılıyordu. Önce `POST /v1/user/web-handoff` ile
/// tek kullanımlık (120 sn) adres alınır; site kodu bir kez tüketip oturumu açar ve Hesabım'a yönlendirir.
/// Adres alınamazsa (eski sunucu, ağ, 401, 429) düz adrese düşülür — kullanıcı yine sayfaya ulaşır.
class WebHandoffApi {
  WebHandoffApi(this._dio);

  final Dio _dio;

  static const path = '/user/web-handoff';

  Future<Uri> accountUrl({
    required String returnPath,
    required String lang,
    required Uri fallback,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: {'return': returnPath, 'lang': lang},
        options: Options(
          contentType: Headers.jsonContentType,
          receiveTimeout: const Duration(seconds: 10),
          sendTimeout: const Duration(seconds: 10),
        ),
      );
      return parseHandoffUrl(response.data) ?? fallback;
    } catch (e) {
      debugPrint('! Web handoff: $e');
      return fallback;
    }
  }
}

/// Yanıttaki geçiş adresi; yalnız `https://www.numistr.org/index.php?…task=handoff&code=<64 hex>` kabul edilir
/// (yanıt beklenmedikse başka bir adres tarayıcıda açılmaz).
Uri? parseHandoffUrl(Object? data) {
  if (data is! Map) return null;
  final d = data['data'];
  final raw = d is Map ? d['url'] : null;
  if (raw is! String) return null;
  final u = Uri.tryParse(raw);
  if (u == null || u.scheme != 'https' || u.host != 'www.numistr.org' || u.path != '/index.php') return null;
  final q = u.queryParameters;
  if (q['plugin'] != 'numistrauth' || q['task'] != 'handoff') return null;
  if (!RegExp(r'^[0-9a-f]{64}$').hasMatch(q['code'] ?? '')) return null;
  return u;
}

final webHandoffApiProvider = Provider<WebHandoffApi>(
  (ref) => WebHandoffApi(ref.watch(apiClientProvider).dio),
);
