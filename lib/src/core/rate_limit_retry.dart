import 'dart:convert';

import 'package:dio/dio.dart';

/// M36 (13 Kas 2026): sunucu dakika sınırına takılınca (429) GET isteğini kısa bekleyip
/// BİR KEZ yeniden dener. iPhone'da liste kaydırırken 429 gelince liste silinip
/// "Bir sorun oluştu", açılan sikkede "Sikke yüklenemedi" görünüyordu (12 Kas).
///
/// Bekleme süresi sunucudan: `Retry-After` başlığı ya da gövdede `errors[0].retry_after`
/// (API 1.25.0'dan beri katalog uçlarında). Süre bilinmiyorsa ya da [maxWait]'ten uzunsa
/// (ör. günlük tavan) yeniden denenmez; hata ekrana "çok fazla istek" olarak düşer.
class RateLimitRetryInterceptor extends Interceptor {
  RateLimitRetryInterceptor(
    this._dio, {
    this.maxWait = const Duration(seconds: 8),
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? ((d) => Future<void>.delayed(d));

  final Dio _dio;
  final Duration maxWait;
  final Future<void> Function(Duration) _sleep;

  static const _retriedFlag = 'rate_limit_retried';

  /// Sunucunun bildirdiği bekleme süresi; yoksa null.
  static Duration? retryAfterOf(Response<dynamic>? response) {
    if (response == null) return null;
    var secs = int.tryParse(response.headers.value('retry-after')?.trim() ?? '');
    if (secs == null) {
      try {
        final raw = response.data;
        final j = raw is String ? jsonDecode(raw) : raw;
        if (j is Map && j['errors'] is List && (j['errors'] as List).isNotEmpty) {
          final e0 = (j['errors'] as List).first;
          if (e0 is Map) secs = int.tryParse('${e0['retry_after'] ?? ''}');
        }
      } catch (_) {}
    }
    if (secs == null || secs < 0) return null;
    return Duration(seconds: secs);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final o = err.requestOptions;
    final wait = retryAfterOf(err.response);
    if (err.response?.statusCode != 429 ||
        o.method.toUpperCase() != 'GET' ||
        o.extra[_retriedFlag] == true ||
        wait == null ||
        wait > maxWait) {
      handler.next(err);
      return;
    }
    await _sleep(wait < const Duration(seconds: 1) ? const Duration(seconds: 1) : wait);
    o.extra[_retriedFlag] = true;
    try {
      handler.resolve(await _dio.fetch<dynamic>(o));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}

/// Hata 429 (çok fazla istek) mı?
bool isRateLimited(Object e) => e is DioException && e.response?.statusCode == 429;
