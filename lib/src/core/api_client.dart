import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
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
        // Debug: Response'u logla
        if (response.requestOptions.path.contains('variants')) {
          debugPrint('🔍 Response for ${response.requestOptions.path}');
          debugPrint('🔍 Response data type: ${response.data.runtimeType}');
          if (response.data is String) {
            final preview = (response.data as String).substring(
              0,
              (response.data as String).length > 500 ? 500 : (response.data as String).length
            );
            debugPrint('🔍 Response preview: $preview...');
          }
        }

        if (response.data is String) {
          try {
            response.data = jsonDecode(response.data);
            debugPrint('✅ JSON parsed successfully');
          } catch (e) {
            debugPrint('⚠️ JSON parse error: $e');
          }
        }
        handler.next(response);
      },
      onError: (error, handler) {
        // 🔥 DEBUG: Error response body
        debugPrint('❌ API Error: ${error.response?.statusCode}');
        debugPrint('❌ Path: ${error.requestOptions.path}');
        debugPrint('❌ Method: ${error.requestOptions.method}');

        if (error.response?.data != null) {
          debugPrint('❌ Response Body:');
          debugPrint(error.response!.data);

          // Try to parse error JSON
          try {
            if (error.response!.data is String) {
              final errorJson = jsonDecode(error.response!.data);
              debugPrint('❌ Parsed Error: $errorJson');
            }
          } catch (e) {
            debugPrint('⚠️ Could not parse error response');
          }
        }

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