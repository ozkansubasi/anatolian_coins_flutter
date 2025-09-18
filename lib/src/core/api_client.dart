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
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: {'Accept': 'application/json'},
      responseType: ResponseType.json,
    ));

    // İstek/yanıt debug logu (sorun olduğunda terminalde görürsün)
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
