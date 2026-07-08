import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';

class TokenInterceptor extends Interceptor {
  static const _retriedKey = 'auth_retried';

  final Ref ref;
  TokenInterceptor(this.ref);

  @override
  Future<void> onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final notifier = ref.read(authControllerProvider.notifier);
    final token = await notifier.getValidAccessToken();

    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    } else {
      debugPrint('! [TokenInterceptor] No token available for ${options.path}');
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final status = err.response?.statusCode;
    final alreadyRetried = err.requestOptions.extra[_retriedKey] == true;

    if (status == 401 && !alreadyRetried) {
      debugPrint('⚠️ [TokenInterceptor] 401 on ${err.requestOptions.path} — forcing token refresh');

      final notifier = ref.read(authControllerProvider.notifier);
      final freshToken = await notifier.forceRefreshToken();

      if (freshToken != null && freshToken.isNotEmpty) {
        // Yeni token'la isteği bir kez tekrarla
        final opts = err.requestOptions;
        opts.extra[_retriedKey] = true;
        opts.headers['Authorization'] = 'Bearer $freshToken';

        try {
          final response = await Dio().fetch(opts);
          debugPrint('✅ [TokenInterceptor] Retry after refresh succeeded');
          return handler.resolve(response);
        } on DioException catch (retryErr) {
          if (retryErr.response?.statusCode == 401) {
            // Yeni token da reddedildi — oturum sunucu tarafında geçersiz
            debugPrint('❌ [TokenInterceptor] Retry still 401 — session expired');
            await notifier.sessionExpired();
          }
          return handler.next(retryErr);
        }
      }

      // Refresh başarısız — oturum ölü, kullanıcıyı login'e düşür
      debugPrint('❌ [TokenInterceptor] Token refresh failed — session expired');
      await notifier.sessionExpired();
    }

    handler.next(err);
  }
}
