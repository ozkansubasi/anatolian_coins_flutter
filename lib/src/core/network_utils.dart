import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'env.dart';

/// Network utility class for connectivity checks and retry logic
class NetworkUtils {
  static const Duration _healthCheckTimeout = Duration(seconds: 15);

  /// Check if device has internet connectivity
  static Future<bool> hasInternetConnection() async {
    try {
      final result = await InternetAddress.lookup('google.com')
          .timeout(const Duration(seconds: 5));
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } on TimeoutException catch (_) {
      return false;
    }
  }

  /// Check if AI service is healthy and responding
  static Future<AiServiceHealth> checkAiServiceHealth() async {
    try {
      final dio = Dio(BaseOptions(
        connectTimeout: _healthCheckTimeout,
        receiveTimeout: _healthCheckTimeout,
      ));

      final response = await dio.get('${Env.aiServiceUrl}/health');

      if (response.statusCode == 200) {
        final data = response.data as Map<String, dynamic>;
        return AiServiceHealth(
          isHealthy: data['status'] == 'healthy',
          modelLoaded: data['model_loaded'] as bool? ?? false,
          indexLoaded: data['index_loaded'] as bool? ?? false,
          timestamp: DateTime.tryParse(data['timestamp'] as String? ?? ''),
        );
      }

      return AiServiceHealth(
        isHealthy: false,
        errorMessage: 'Unexpected response: ${response.statusCode}',
      );
    } on DioException catch (e) {
      return AiServiceHealth(
        isHealthy: false,
        errorMessage: _getDioErrorMessage(e),
        isConnectionError: _isConnectionError(e),
      );
    } catch (e) {
      return AiServiceHealth(
        isHealthy: false,
        errorMessage: e.toString(),
      );
    }
  }

  /// Execute an async action with retry logic and exponential backoff
  static Future<T> withRetry<T>(
    Future<T> Function() action, {
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
    bool Function(dynamic)? shouldRetry,
  }) async {
    int attempt = 0;
    Duration delay = initialDelay;
    dynamic lastError;

    while (attempt < maxAttempts) {
      try {
        attempt++;
        return await action();
      } catch (e) {
        lastError = e;

        // Check if we should retry this error
        final canRetry = shouldRetry?.call(e) ?? isRetryableError(e);

        if (attempt >= maxAttempts || !canRetry) {
          rethrow;
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(delay);
        delay *= 2;
      }
    }

    throw lastError;
  }

  /// Check if an error is retryable (transient failures)
  static bool isRetryableError(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
        case DioExceptionType.connectionError:
          return true;
        default:
          // Check HTTP status codes
          final statusCode = error.response?.statusCode;
          return statusCode == 500 ||
              statusCode == 502 ||
              statusCode == 503 ||
              statusCode == 504;
      }
    }
    return false;
  }

  /// Check if error is a connection-related error
  static bool _isConnectionError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.connectionError:
        return true;
      default:
        return false;
    }
  }

  /// Get user-friendly error message from DioException
  static String _getDioErrorMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out';
      case DioExceptionType.sendTimeout:
        return 'Send timeout';
      case DioExceptionType.receiveTimeout:
        return 'Server response timeout';
      case DioExceptionType.connectionError:
        return 'Connection error';
      default:
        return e.message ?? 'Unknown error';
    }
  }

  /// Convert any error to user-friendly message
  static String getUserFriendlyMessage(dynamic error) {
    if (error is DioException) {
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
          return 'Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.';
        case DioExceptionType.sendTimeout:
          return 'Yükleme zaman aşımına uğradı. Daha küçük bir görsel deneyin.';
        case DioExceptionType.receiveTimeout:
          return 'Sunucu yanıt vermedi. Lütfen tekrar deneyin.';
        case DioExceptionType.connectionError:
          return 'Sunucuya bağlanılamadı. İnternet bağlantınızı kontrol edin.';
        default:
          break;
      }

      final statusCode = error.response?.statusCode;
      switch (statusCode) {
        case 400:
          return 'Geçersiz görsel. Lütfen sikkenin net bir fotoğrafını kullanın.';
        case 413:
          return 'Görsel çok büyük. Lütfen daha küçük bir görsel kullanın.';
        case 429:
          return 'Çok fazla istek. Lütfen biraz bekleyin ve tekrar deneyin.';
        case 500:
          return 'Sunucu hatası. Ekibimiz bilgilendirildi.';
        case 503:
          return 'Servis geçici olarak kullanılamıyor. Lütfen daha sonra tekrar deneyin.';
        default:
          return 'Bir hata oluştu. Lütfen tekrar deneyin.';
      }
    }

    if (error is RecognitionError) {
      return error.userMessage;
    }

    return 'Beklenmeyen bir hata oluştu. Lütfen tekrar deneyin.';
  }
}

/// AI Service health status
class AiServiceHealth {
  final bool isHealthy;
  final bool modelLoaded;
  final bool indexLoaded;
  final DateTime? timestamp;
  final String? errorMessage;
  final bool isConnectionError;

  AiServiceHealth({
    required this.isHealthy,
    this.modelLoaded = false,
    this.indexLoaded = false,
    this.timestamp,
    this.errorMessage,
    this.isConnectionError = false,
  });

  String get statusMessage {
    if (isConnectionError) {
      return 'Tanıma servisine bağlanılamıyor';
    }
    if (!isHealthy) {
      return errorMessage ?? 'Tanıma servisi kullanılamıyor';
    }
    if (!modelLoaded) {
      return 'AI modeli yüklenmedi';
    }
    if (!indexLoaded) {
      return 'Sikke veritabanı yüklenmedi';
    }
    return 'Servis hazır';
  }
}

/// Custom error types for recognition
class RecognitionError implements Exception {
  final String message;
  final String userMessage;
  final RecognitionErrorType type;

  RecognitionError({
    required this.message,
    required this.userMessage,
    required this.type,
  });

  factory RecognitionError.noInternet() => RecognitionError(
        message: 'No internet connection',
        userMessage: 'İnternet bağlantısı yok.\nLütfen bağlantınızı kontrol edin.',
        type: RecognitionErrorType.noInternet,
      );

  factory RecognitionError.serviceUnavailable() => RecognitionError(
        message: 'AI service unavailable',
        userMessage: 'Tanıma servisi şu anda kullanılamıyor.\nLütfen daha sonra tekrar deneyin.',
        type: RecognitionErrorType.serviceUnavailable,
      );

  factory RecognitionError.timeout() => RecognitionError(
        message: 'Request timed out',
        userMessage: 'İstek zaman aşımına uğradı.\nLütfen tekrar deneyin.',
        type: RecognitionErrorType.timeout,
      );

  factory RecognitionError.quotaExceeded() => RecognitionError(
        message: 'Quota exceeded',
        userMessage: 'Aylık tarama limitiniz doldu.\nYüksek kapasiteli tarama için Pro\'ya yükseltin.',
        type: RecognitionErrorType.quotaExceeded,
      );

  factory RecognitionError.authRequired() => RecognitionError(
        message: 'Authentication required',
        userMessage: 'Bu özelliği kullanmak için giriş yapmalısınız.',
        type: RecognitionErrorType.authRequired,
      );

  factory RecognitionError.invalidImage() => RecognitionError(
        message: 'Invalid image',
        userMessage: 'Geçersiz görsel formatı.\nLütfen JPG veya PNG kullanın.',
        type: RecognitionErrorType.invalidImage,
      );

  factory RecognitionError.unknown(String message) => RecognitionError(
        message: message,
        userMessage: 'Beklenmeyen bir hata oluştu.\nLütfen tekrar deneyin.',
        type: RecognitionErrorType.unknown,
      );

  @override
  String toString() => 'RecognitionError: $message';
}

enum RecognitionErrorType {
  noInternet,
  serviceUnavailable,
  timeout,
  quotaExceeded,
  authRequired,
  invalidImage,
  unknown,
}

// Riverpod Providers

/// Provider for internet connectivity status
final connectivityProvider = FutureProvider<bool>((ref) async {
  return await NetworkUtils.hasInternetConnection();
});

/// Provider for AI service health
final aiServiceHealthProvider = FutureProvider<AiServiceHealth>((ref) async {
  return await NetworkUtils.checkAiServiceHealth();
});

/// Stream provider for continuous connectivity monitoring
final connectivityStreamProvider = StreamProvider<bool>((ref) async* {
  // Check immediately
  yield await NetworkUtils.hasInternetConnection();

  // Then check periodically (every 30 seconds)
  await for (final _ in Stream.periodic(const Duration(seconds: 30))) {
    yield await NetworkUtils.hasInternetConnection();
  }
});
