import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';

/// App Store 5.1.1(v) — uygulama içinden hesap silme sonucu.
///
/// Sunucu ucu `POST /v1/user/delete` (eklenti 1.20.0), gövde `{"confirm": true}`:
/// 200 `{data:{deleted:true, auth0_users_deleted, web_subscription_canceled}}` ·
/// 400 CONFIRM_REQUIRED · 401 UNAUTHORIZED · 403 ACCOUNT_PROTECTED ·
/// 429 RATE_LIMITED (+ `retry_after`) · 502 AUTH0_DELETE_FAILED (hiçbir şey
/// silinmedi, tekrar denenebilir) · 503 DELETE_UNAVAILABLE · 500 DELETE_FAILED.
/// Hata kodu `errors[0].error_code`'da (bkz. ResponseHelper::errorPayload).
enum AccountDeletionStatus {
  deleted,
  confirmRequired,
  unauthorized,
  protected,
  rateLimited,
  auth0Failed,
  unavailable,
  failed,
  network,
}

class AccountDeletionResult {
  const AccountDeletionResult(
    this.status, {
    this.retryAfterSeconds = 0,
    this.auth0UsersDeleted,
    this.webSubscriptionCanceled,
  });

  final AccountDeletionStatus status;

  /// 429'da yeniden denemeden önce beklenecek süre (sn); bilinmiyorsa 0.
  final int retryAfterSeconds;

  /// Başarıda: silinen Auth0 kullanıcı sayısı (aynı e-postaya bağlı kimlikler).
  final int? auth0UsersDeleted;

  /// Başarıda: web (iyzico) aboneliği iptal edildi mi; abonelik yoksa null.
  final bool? webSubscriptionCanceled;

  bool get isDeleted => status == AccountDeletionStatus.deleted;

  /// Bekleme dakika olarak (yukarı yuvarlanır, en az 1).
  int get retryAfterMinutes {
    final minutes = (retryAfterSeconds / 60).ceil();
    return minutes < 1 ? 1 : minutes;
  }

  /// Arayüzde gösterilecek hata metninin l10n anahtarı; başarıda null.
  String? get errorKey => switch (status) {
        AccountDeletionStatus.deleted => null,
        AccountDeletionStatus.unauthorized => 'delete_account_error_unauthorized',
        AccountDeletionStatus.protected => 'delete_account_error_protected',
        AccountDeletionStatus.rateLimited => 'delete_account_error_rate_limited',
        AccountDeletionStatus.auth0Failed => 'delete_account_error_retry',
        AccountDeletionStatus.unavailable => 'delete_account_error_unavailable',
        AccountDeletionStatus.network => 'delete_account_error_network',
        // 400 istemci hatasıdır (onay gövdesi eksik): kullanıcı için genel durum.
        AccountDeletionStatus.confirmRequired ||
        AccountDeletionStatus.failed =>
          'delete_account_error_support',
      };

  /// [errorKey] metnindeki yer tutucular.
  Map<String, String> get errorParams => status == AccountDeletionStatus.rateLimited
      ? {'minutes': '$retryAfterMinutes'}
      : const {};

  /// Sunucu yanıtını ayrıştırır. [body] düz metin (hata gövdeleri) ya da
  /// ApiClient'ın çözdüğü Map (başarı) olabilir. Kod varsa ona, yoksa HTTP
  /// durumuna bakılır; tanınmayan durum "destekle iletişime geçin"dir.
  static AccountDeletionResult fromResponse(int statusCode, Object? body,
      {String? retryAfterHeader}) {
    final json = _asMap(body);

    if (statusCode >= 200 && statusCode < 300) {
      final data = json?['data'] is Map ? json!['data'] as Map : json;
      if (data?['deleted'] == true) {
        return AccountDeletionResult(
          AccountDeletionStatus.deleted,
          auth0UsersDeleted: _int(data?['auth0_users_deleted']),
          webSubscriptionCanceled: data?['web_subscription_canceled'] is bool
              ? data!['web_subscription_canceled'] as bool
              : null,
        );
      }
      // 2xx ama silindi denmiyor: ne olduğu bilinmiyor.
      return const AccountDeletionResult(AccountDeletionStatus.failed);
    }

    final errors = json?['errors'];
    final first =
        errors is List && errors.isNotEmpty && errors.first is Map ? errors.first as Map : null;
    final code = first?['error_code']?.toString();

    final status = switch (code) {
      'CONFIRM_REQUIRED' => AccountDeletionStatus.confirmRequired,
      'UNAUTHORIZED' => AccountDeletionStatus.unauthorized,
      'ACCOUNT_PROTECTED' => AccountDeletionStatus.protected,
      'RATE_LIMITED' => AccountDeletionStatus.rateLimited,
      'AUTH0_DELETE_FAILED' => AccountDeletionStatus.auth0Failed,
      'DELETE_UNAVAILABLE' => AccountDeletionStatus.unavailable,
      'DELETE_FAILED' => AccountDeletionStatus.failed,
      _ => switch (statusCode) {
          401 => AccountDeletionStatus.unauthorized,
          403 => AccountDeletionStatus.protected,
          429 => AccountDeletionStatus.rateLimited,
          // 404/405: uç henüz yok (eklenti 1.20.0 öncesi) · 503: bakım.
          404 || 405 || 503 => AccountDeletionStatus.unavailable,
          // Kodsuz 502 barındırma katmanından da gelebilir; silmenin yapılıp
          // yapılmadığı bilinmez — "hiçbir şey silinmedi" denmez.
          _ => AccountDeletionStatus.failed,
        },
    };

    if (status == AccountDeletionStatus.rateLimited) {
      return AccountDeletionResult(
        status,
        retryAfterSeconds: _positive(first?['retry_after']) ?? _positive(retryAfterHeader) ?? 60,
      );
    }
    return AccountDeletionResult(status);
  }

  static Map? _asMap(Object? body) {
    if (body is Map) return body;
    if (body is String && body.isNotEmpty) {
      try {
        final decoded = jsonDecode(body);
        if (decoded is Map) return decoded;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  static int? _positive(Object? v) {
    final n = _int(v);
    return n != null && n > 0 ? n : null;
  }

  static int? _int(Object? v) {
    if (v is int) return v >= 0 ? v : null;
    if (v is String) {
      final n = int.tryParse(v.trim());
      return n != null && n >= 0 ? n : null;
    }
    return null;
  }
}

/// `POST /v1/user/delete` — kimlikli diğer uçlar gibi ApiClient'ın Dio'suyla
/// (Bearer belirteci TokenInterceptor ekler; 401'de bir kez yenileyip dener).
class AccountDeletionApi {
  AccountDeletionApi(this._dio);

  final Dio _dio;

  static const path = '/user/delete';

  Future<AccountDeletionResult> deleteAccount() async {
    try {
      final response = await _dio.post(
        path,
        data: {'confirm': true},
        options: Options(contentType: Headers.jsonContentType),
      );
      return AccountDeletionResult.fromResponse(response.statusCode ?? 0, response.data);
    } on DioException catch (e) {
      final r = e.response;
      if (r == null) {
        debugPrint('! Account deletion: no response (${e.type.name})');
        return const AccountDeletionResult(AccountDeletionStatus.network);
      }
      return AccountDeletionResult.fromResponse(
        r.statusCode ?? 0,
        r.data,
        retryAfterHeader: r.headers.value('retry-after'),
      );
    } catch (e) {
      debugPrint('! Account deletion error: $e');
      return const AccountDeletionResult(AccountDeletionStatus.failed);
    }
  }
}

final accountDeletionApiProvider = Provider<AccountDeletionApi>(
  (ref) => AccountDeletionApi(ref.watch(apiClientProvider).dio),
);
