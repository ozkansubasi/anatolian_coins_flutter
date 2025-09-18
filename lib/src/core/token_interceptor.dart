import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../auth/auth_controller.dart';

class TokenInterceptor extends Interceptor {
  final Ref ref;
  TokenInterceptor(this.ref);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    final notifier = ref.read(authControllerProvider.notifier);
    final token = await notifier.getValidAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      // İstersen burada re-login veya signOut tetikleyebilirsin.
    }
    super.onError(err, handler);
  }
}
