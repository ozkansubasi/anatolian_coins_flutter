import 'dart:convert';

/// A23 — doğrulama iletisini yeniden gönderme sonucu.
///
/// Sunucu ucu `POST /v1/auth/resend-verification` (eklenti 1.19.0):
/// 200 `{sent:true, retry_after}` · 200 `{sent:false, code:ALREADY_VERIFIED}` ·
/// 429 `RESEND_RATE_LIMITED` (+ `retry_after`) · 400/401/502/503 → başarısız.
enum ResendVerificationStatus { sent, alreadyVerified, rateLimited, failed }

class ResendVerificationResult {
  const ResendVerificationResult(this.status, {this.retryAfterSeconds = 0, this.errorKey});

  const ResendVerificationResult.failed({this.errorKey})
      : status = ResendVerificationStatus.failed,
        retryAfterSeconds = 0;

  final ResendVerificationStatus status;

  /// Yeniden denemeden önce beklenecek süre (sn); bilinmiyorsa 0.
  final int retryAfterSeconds;

  /// Başarısızlıkta gösterilecek l10n anahtarı (ör. yanlış şifre); null = genel mesaj.
  final String? errorKey;

  /// Kısa bekleme mi (düğmede geri sayım), yoksa günlük tavan mı (mesaj)?
  static const shortWaitLimit = 120;

  /// Sunucu yanıtını ayrıştırır. Gövde bozuksa ya da beklenmeyen bir durum
  /// geldiyse başarısız sayılır — kullanıcıya "şu anda gönderilemedi" denir.
  static ResendVerificationResult fromResponse(int statusCode, String body, {String? retryAfterHeader}) {
    Map<String, dynamic>? json;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) json = decoded;
    } catch (_) {
      json = null;
    }

    if (statusCode == 200 && json != null) {
      if (json['sent'] == true) {
        return ResendVerificationResult(
          ResendVerificationStatus.sent,
          retryAfterSeconds: _int(json['retry_after']) ?? 60,
        );
      }
      if (json['code'] == 'ALREADY_VERIFIED') {
        return const ResendVerificationResult(ResendVerificationStatus.alreadyVerified);
      }
      return const ResendVerificationResult.failed();
    }

    if (statusCode == 429) {
      final errors = json?['errors'];
      final first = errors is List && errors.isNotEmpty && errors.first is Map ? errors.first as Map : null;
      final retry = _int(first?['retry_after']) ?? _int(retryAfterHeader) ?? 60;
      return ResendVerificationResult(ResendVerificationStatus.rateLimited, retryAfterSeconds: retry);
    }

    return const ResendVerificationResult.failed();
  }

  static int? _int(Object? v) {
    if (v is int) return v > 0 ? v : null;
    if (v is String) {
      final n = int.tryParse(v.trim());
      return n != null && n > 0 ? n : null;
    }
    return null;
  }
}
