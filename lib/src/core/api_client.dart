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
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 60),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.plain, // ✅ String olarak al, manuel parse edeceğiz
    ));

    // JSON parse interceptor - String response'u Map'e çevir
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // Debug: Response'u logla
        if (response.requestOptions.path.contains('variants')) {
          print('🔍 Response for ${response.requestOptions.path}');
          print('🔍 Response data type: ${response.data.runtimeType}');
          if (response.data is String) {
            final preview = (response.data as String).substring(
              0, 
              (response.data as String).length > 500 ? 500 : (response.data as String).length
            );
            print('🔍 Response preview: $preview...');
          }
        }
        
        if (response.data is String) {
          try {
            response.data = jsonDecode(response.data);
            print('✅ JSON parsed successfully');
          } catch (e) {
            print('⚠️ JSON parse error: $e');
          }
        }
        handler.next(response);
      },
    ));

    // Debug log
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false, // String çok uzun olduğu için kapatıyoruz
      requestHeader: false,
      responseHeader: false,
      logPrint: (o) => print('[DIO] $o'),
    ));

    // Bearer ekleyen interceptor
    dio.interceptors.add(TokenInterceptor(ref));
    return ApiClient._(dio);
  }
}