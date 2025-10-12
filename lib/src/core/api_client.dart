import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/env.dart';
import 'token_interceptor.dart';

class ApiClient {
  final Dio dio;
  ApiClient._(this.dio);

  factory ApiClient(Ref ref) {
    final dio = Dio(BaseOptions(
      baseUrl: Env.baseUrl, // https://www.numistr.org/api/index.php/v1
      connectTimeout: const Duration(seconds: 30), // 15 → 30
      receiveTimeout: const Duration(seconds: 60), // 30 → 60
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.plain, // ✅ String olarak al, sonra parse et
    ));

    // JSON parse interceptor ekle
    dio.interceptors.add(InterceptorsWrapper(
      onResponse: (response, handler) {
        // String ise JSON'a çevir
        if (response.data is String && response.data.toString().isNotEmpty) {
          try {
            response.data = jsonDecode(response.data);
          } catch (e) {
            print('❌ JSON Parse Error: $e');
          }
        }
        handler.next(response);
      },
      onError: (error, handler) async {
        // Timeout hatası varsa 1 kez daha dene
        if (error.type == DioExceptionType.receiveTimeout || 
            error.type == DioExceptionType.connectionTimeout) {
          print('⚠️ Timeout - retrying...');
          try {
            final response = await dio.fetch(error.requestOptions);
            handler.resolve(response);
            return;
          } catch (e) {
            print('❌ Retry failed: $e');
          }
        }
        handler.next(error);
      },
    ));

    // İstek/yanıt debug logu
    dio.interceptors.add(LogInterceptor(
      requestBody: false,
      responseBody: false,
      requestHeader: false,
      responseHeader: false,
      logPrint: (o) => print('[DIO] $o'),
    ));

    // Bearer ekleyen interceptor
    dio.interceptors.add(TokenInterceptor(ref));
    return ApiClient._(dio);
  }
}