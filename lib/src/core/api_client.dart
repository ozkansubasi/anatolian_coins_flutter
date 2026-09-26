import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'app_log.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import '../core/env.dart';
import 'token_interceptor.dart';

class ApiClient {
  final Dio dio;
  ApiClient._(this.dio);

  factory ApiClient(Ref ref) {
    final dio = Dio(BaseOptions(
      baseUrl: Env.baseUrl,
      connectTimeout: const Duration(seconds: 45), // ✅ 30 → 45 saniye
      receiveTimeout: const Duration(seconds: 120), // ✅ 60 → 120 saniye (text arama uzun sürebilir)
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.plain, // ✅ String olarak al, manuel parse edeceğiz
    ));

    // JSON parse interceptor - String response'u Map'e çevir
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        if (response.data is String) {
          try {
            response.data = jsonDecode(response.data);
          } catch (e) {
            debugPrint('⚠️ JSON parse error: $e');
          }
        }
        handler.next(response);
      },
      onError: (error, handler) {
        final o = error.requestOptions;
        var detail = '';
        try {
          final raw = error.response?.data;
          final j = raw is String ? jsonDecode(raw) : raw;
          if (j is Map && j['errors'] is List && (j['errors'] as List).isNotEmpty) {
            final e0 = (j['errors'] as List).first;
            if (e0 is Map) detail = '${e0['detail'] ?? e0['title'] ?? ''}';
          }
        } catch (_) {}
        // Jetonsuz istekte 401 beklenen durum (giriş yapılmamış): kaydetme.
        if (error.response?.statusCode == 401 && !o.headers.containsKey('Authorization')) {
          handler.next(error);
          return;
        }
        final query = o.uri.hasQuery ? '?${o.uri.query}' : '';
        appLog('HTTP', '${error.response?.statusCode ?? error.type.name} ${o.method} ${o.uri.path}$query'
            '${detail.isEmpty ? '' : ' → $detail'}');
        handler.next(error);
      },
    ));

    // Debug log
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false, // String çok uzun olduğu için kapatıyoruz
      requestHeader: false,
      responseHeader: false,
      logPrint: (o) => debugPrint('[DIO] $o'),
    ));

    // Bearer ekleyen interceptor
    dio.interceptors.add(TokenInterceptor(ref));
    return ApiClient._(dio);
  }
}

// Singleton API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient(ref);
});