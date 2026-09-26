import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'env.dart';

/// Network utility class for connectivity and AI service health checks
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

  /// Tanılama iletisi (log ve istisna için; kullanıcıya gösterilmez —
  /// arayüz metni l10n anahtarından gelir).
  String get statusMessage {
    if (isConnectionError) {
      return 'Cannot connect to recognition service';
    }
    if (!isHealthy) {
      return errorMessage ?? 'Recognition service unavailable';
    }
    if (!modelLoaded) {
      return 'AI model not loaded';
    }
    if (!indexLoaded) {
      return 'Coin index not loaded';
    }
    return 'Service ready';
  }
}
