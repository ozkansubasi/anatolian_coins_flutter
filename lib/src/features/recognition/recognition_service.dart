import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/api_client.dart';
import '../../core/env.dart';
import '../../core/network_utils.dart';
import '../../auth/auth_controller.dart';
import '../../core/install_id.dart';
import '../../core/subscription_provider.dart';

/// Recognition service for coin identification
/// Communicates with Joomla API (which proxies to AI service)
/// Handles authentication and quota management
class RecognitionService {
  final ApiClient _client;

  /// M17: oturum yokken kurulum kimliği (`X-Device-Id`), oturumluyken null.
  final Future<String?> Function()? _anonymousDeviceId;

  RecognitionService(this._client, {Future<String?> Function()? anonymousDeviceId})
      : _anonymousDeviceId = anonymousDeviceId;

  /// Oturumsuz deneme isteğinde kurulum kimliği başlığı; oturumluyken başlık yok.
  Future<Map<String, dynamic>?> _trialHeaders() async {
    final id = await _anonymousDeviceId?.call();
    return id == null ? null : {'X-Device-Id': id};
  }

  /// Pre-flight check before recognition
  /// Throws RecognitionException if service is not available
  Future<void> _preFlightCheck() async {
    debugPrint('🔵 [RecognitionService] Running pre-flight checks...');

    // Check internet connectivity
    final hasInternet = await NetworkUtils.hasInternetConnection();
    if (!hasInternet) {
      debugPrint('❌ [RecognitionService] No internet connection');
      throw RecognitionException(
        'No internet connection',
        isServiceUnavailable: true,
      );
    }
    debugPrint('✅ [RecognitionService] Internet connection OK');

    // Check AI service health (with timeout)
    try {
      final health = await NetworkUtils.checkAiServiceHealth();
      if (!health.isHealthy) {
        debugPrint('❌ [RecognitionService] AI service not healthy: ${health.statusMessage}');
        throw RecognitionException(
          health.statusMessage,
          isServiceUnavailable: true,
        );
      }
      debugPrint('✅ [RecognitionService] AI service health OK');
    } catch (e) {
      if (e is RecognitionException) rethrow;
      debugPrint('⚠️ [RecognitionService] Health check failed, proceeding anyway: $e');
      // Don't block recognition if health check fails - let the actual request fail
    }
  }

  /// Upload single image and get recognition results
  /// Returns list of matching coins with confidence scores
  /// Uses Joomla API endpoint which proxies to AI service
  /// Faz B: koleksiyonerin isteğe bağlı verdiği nitelikler (yeniden sıralamada kullanılır).
  static Map<String, String> attrFields({String? metal, String? weightG, String? diameterMm}) {
    final f = <String, String>{};
    if (metal != null && metal.isNotEmpty) f['metal'] = metal;
    if (weightG != null && weightG.isNotEmpty) f['weight_g'] = weightG;
    if (diameterMm != null && diameterMm.isNotEmpty) f['diameter_mm'] = diameterMm;
    return f;
  }

  Future<RecognitionResponse> recognize(File imageFile,
      {bool skipPreFlight = false, Map<String, String> attrs = const {}}) async {
    try {
      // Pre-flight check (can be skipped for retry attempts)
      if (!skipPreFlight) {
        await _preFlightCheck();
      }

      debugPrint('🔵 [RecognitionService] Starting single-image recognition...');
      debugPrint('🔵 [RecognitionService] Image path: ${imageFile.path}');
      debugPrint('🔵 [RecognitionService] Image exists: ${await imageFile.exists()}');
      debugPrint('🔵 [RecognitionService] Image size: ${await imageFile.length()} bytes');

      // Create multipart form data
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          imageFile.path,
          filename: 'coin.jpg',
        ),
        ...attrs,
      });

      debugPrint('🔵 [RecognitionService] Sending POST request to ${Env.baseUrl}/recognize...');

      // Send POST request to Joomla API (which proxies to AI service)
      // Auth token is automatically added by TokenInterceptor
      final response = await _client.dio.post(
        '/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
          headers: await _trialHeaders(),
        ),
      );

      debugPrint('✅ [RecognitionService] Response received: ${response.statusCode}');
      debugPrint('🔵 [RecognitionService] Response data type: ${response.data.runtimeType}');

      // Parse response (ApiClient already handles JSON parsing)
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      debugPrint('🔵 [RecognitionService] Parsed data keys: ${data.keys}');
      final result = RecognitionResponse.fromJson(data);
      debugPrint('✅ [RecognitionService] Recognition successful! Matches: ${result.matches.length}');

      return result;
    } on DioException catch (e) {
      debugPrint('❌ [RecognitionService] DioException: ${e.type}');
      debugPrint('❌ [RecognitionService] Status code: ${e.response?.statusCode}');
      debugPrint('❌ [RecognitionService] Error message: ${e.message}');
      debugPrint('❌ [RecognitionService] Response data: ${e.response?.data}');

      throw exceptionFor(e.response?.statusCode, e.response?.data, e.message);
    } catch (e, stack) {
      debugPrint('❌ [RecognitionService] Unexpected error: $e');
      debugPrint('❌ [RecognitionService] Stack trace: $stack');
      if (e is RecognitionException) rethrow;
      throw RecognitionException('Recognition failed: $e');
    }
  }

  /// Upload dual images (obverse + reverse) and get recognition results
  /// Returns list of matching coins with confidence scores
  /// Backend now supports dual images via 'image' (obverse) and 'reverse' fields
  Future<RecognitionResponse> recognizeDual(File obverseFile, File reverseFile,
      {bool skipPreFlight = false, Map<String, String> attrs = const {}}) async {
    try {
      // Pre-flight check (can be skipped for retry attempts)
      if (!skipPreFlight) {
        await _preFlightCheck();
      }

      debugPrint('🔵 [RecognitionService] Starting dual-image recognition...');
      debugPrint('🔵 [RecognitionService] Obverse: ${obverseFile.path}');
      debugPrint('🔵 [RecognitionService] Reverse: ${reverseFile.path}');
      debugPrint('🔵 [RecognitionService] Obverse exists: ${await obverseFile.exists()}');
      debugPrint('🔵 [RecognitionService] Reverse exists: ${await reverseFile.exists()}');
      debugPrint('🔵 [RecognitionService] Obverse size: ${await obverseFile.length()} bytes');
      debugPrint('🔵 [RecognitionService] Reverse size: ${await reverseFile.length()} bytes');

      // Create multipart form data with both images
      final formData = FormData.fromMap({
        'image': await MultipartFile.fromFile(
          obverseFile.path,
          filename: 'coin_obverse.jpg',
        ),
        'reverse': await MultipartFile.fromFile(
          reverseFile.path,
          filename: 'coin_reverse.jpg',
        ),
        ...attrs,
      });

      debugPrint('🔵 [RecognitionService] Sending POST request to ${Env.baseUrl}/recognize (dual images)...');

      // Send POST request to Joomla API (which proxies to AI service)
      // Auth token is automatically added by TokenInterceptor
      final response = await _client.dio.post(
        '/recognize',
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          receiveTimeout: const Duration(seconds: 60),
          headers: await _trialHeaders(),
        ),
      );

      debugPrint('✅ [RecognitionService] Response received: ${response.statusCode}');
      debugPrint('🔵 [RecognitionService] Response data type: ${response.data.runtimeType}');

      // Parse response (ApiClient already handles JSON parsing)
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      debugPrint('🔵 [RecognitionService] Parsed data keys: ${data.keys}');
      final result = RecognitionResponse.fromJson(data);
      debugPrint('✅ [RecognitionService] Recognition successful! Matches: ${result.matches.length}');

      return result;
    } on DioException catch (e) {
      debugPrint('❌ [RecognitionService] DioException: ${e.type}');
      debugPrint('❌ [RecognitionService] Status code: ${e.response?.statusCode}');
      debugPrint('❌ [RecognitionService] Error message: ${e.message}');
      debugPrint('❌ [RecognitionService] Response data: ${e.response?.data}');

      throw exceptionFor(e.response?.statusCode, e.response?.data, e.message);
    } catch (e, stack) {
      debugPrint('❌ [RecognitionService] Unexpected error: $e');
      debugPrint('❌ [RecognitionService] Stack trace: $stack');
      if (e is RecognitionException) rethrow;
      throw RecognitionException('Recognition failed: $e');
    }
  }

  /// HTTP hatasını [RecognitionException]'a çevirir (iki tanıma çağrısı ortak kullanır).
  /// M17: oturumsuz denemede 429 gövdesindeki `error.code` deneme bitti / kullanılamıyor
  /// ayrımını taşır; bunlar kota hatası değil, ücretsiz hesap davetidir.
  @visibleForTesting
  static RecognitionException exceptionFor(int? status, Object? body, String? message) {
    final code = _errorCode(body);
    if (code == 'TRIAL_EXHAUSTED' || code == 'TRIAL_UNAVAILABLE') {
      return RecognitionException('Free trial: $code', trialCode: code);
    }
    if (status == 429) {
      return RecognitionException(
        'Scan quota exceeded. Please upgrade to Pro or wait until next month.',
        isQuotaExceeded: true,
      );
    }
    if (status == 401) {
      return RecognitionException('Authentication required for recognition', isAuthRequired: true);
    }
    if (status == 503) {
      return RecognitionException(
        'Recognition service temporarily unavailable. Please try again later.',
        isServiceUnavailable: true,
      );
    }
    return RecognitionException('Recognition failed: $message');
  }

  static String? _errorCode(Object? body) {
    var data = body;
    if (data is String) {
      try {
        data = jsonDecode(data);
      } catch (_) {
        return null;
      }
    }
    if (data is Map && data['error'] is Map) return (data['error'] as Map)['code']?.toString();
    return null;
  }

  /// M17: oturumsuz deneme hakkı (kurulum kimliğiyle). Sunucu yalnız okur, hak düşmez.
  Future<ScanQuota> getAnonQuota(String deviceId) async {
    try {
      final response = await _client.dio.get(
        '/anon/scan-quota',
        options: Options(headers: {'X-Device-Id': deviceId}),
      );
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};
      return ScanQuota.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch trial quota: $e');
    }
  }

  /// Check remaining scan quota
  Future<ScanQuota> getQuota() async {
    try {
      final response = await _client.dio.get('/user/scan-quota');

      // ApiClient already handles JSON parsing
      final Map<String, dynamic> data = response.data is Map
          ? response.data as Map<String, dynamic>
          : {};

      return ScanQuota.fromJson(data);
    } catch (e) {
      throw Exception('Failed to fetch scan quota: $e');
    }
  }
}

/// Custom exception for recognition errors
class RecognitionException implements Exception {
  final String message;
  final bool isQuotaExceeded;
  final bool isAuthRequired;
  final bool isServiceUnavailable;

  /// M17: oturumsuz deneme reddi (`TRIAL_EXHAUSTED` / `TRIAL_UNAVAILABLE`), yoksa null.
  final String? trialCode;

  RecognitionException(
    this.message, {
    this.isQuotaExceeded = false,
    this.isAuthRequired = false,
    this.isServiceUnavailable = false,
    this.trialCode,
  });

  bool get isTrialEnded => trialCode != null;

  @override
  String toString() => message;
}

/// Recognition response model
class RecognitionResponse {
  final List<CoinMatch> matches;
  final ScanQuota? quota;
  final int? processingTimeMs;
  final String? ocrText;
  final String? message;

  /// Faz A (2026-08): servis eslesme bulamadiginda nedenli fallback dondurur.
  final bool noMatch;

  /// no_coin_detected | low_detail_surface | below_confidence | ambiguous_match
  final String? noMatchReason;

  /// Yuz basina girdi kalitesi: {'obverse': {'coin_detected': bool, 'sharpness': num}, ...}
  final Map<String, dynamic>? quality;

  /// Faz D (2026-09-29): ilk eşleşme yerel özellik doğrulamasından geçti (aynı sikke/kalıp).
  /// null = sunucu bu alanı göndermiyor (eklenti < 1.16.5) → eski davranış.
  final bool? verified;

  /// AI4: hiçbir aday güven eşiğine ulaşmadığında sunucunun ayrıca verdiği en yakın adaylar.
  final List<CoinMatch> nearMatches;

  /// Hedef 2 (2026-10-09): tip doğrulanmasa da fotoğrafın söyledikleri (hükümdar / dönem /
  /// darphane / tarih). null = sunucu göndermiyor (eklenti < 1.17.0) ya da söylenecek bir şey yok.
  final CoinIdentification? identification;

  RecognitionResponse({
    required this.matches,
    this.quota,
    this.processingTimeMs,
    this.ocrText,
    this.message,
    this.noMatch = false,
    this.noMatchReason,
    this.quality,
    this.verified,
    this.nearMatches = const [],
    this.identification,
  });

  /// Convenience getter for remaining scans (backward compatibility)
  int get remainingScans => quota?.remaining ?? 0;

  /// AI11 (2026-10-10): iki fotoğraf sikkenin aynı yüzünü gösteriyordu; sunucu tek fotoğrafla yanıtladı,
  /// ikinci fotoğraf tanımada kullanılmadı (`quality.same_face`).
  bool get sameFace => quality?['same_face'] == true;

  factory RecognitionResponse.fromJson(Map<String, dynamic> json) {
    // Handle both direct response format and wrapped 'data' format from Joomla
    final data = json['data'] as Map<String, dynamic>? ?? json;

    final matchesJson = data['matches'] as List<dynamic>? ?? [];
    final matches = matchesJson
        .map((m) => CoinMatch.fromJson(m as Map<String, dynamic>))
        .toList();

    // Parse quota info if present (can be at top level or in data)
    ScanQuota? quota;
    if (json['quota'] != null) {
      quota = ScanQuota.fromJson(json['quota'] as Map<String, dynamic>);
    }

    return RecognitionResponse(
      matches: matches,
      quota: quota,
      processingTimeMs: data['processing_time_ms'] as int?,
      ocrText: data['ocr_text'] as String?,
      message: json['message'] as String?,
      noMatch: data['no_match'] as bool? ?? matches.isEmpty,
      noMatchReason: data['no_match_reason'] as String?,
      quality: data['quality'] as Map<String, dynamic>?,
      verified: data.containsKey('verified') ? data['verified'] == true : null,
      nearMatches: (data['near_matches'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CoinMatch.fromJson)
          .toList(),
      identification: CoinIdentification.tryParse(data['identification']),
    );
  }
}

/// Hedef 2: tam tip doğrulanmadığında da fotoğraftan çıkarılan bilgi. Düzey sırası:
/// type (doğrulanmış tip) > ruler > dynasty > mint > date. Hükümdarın kanonik adı katalogdaki gibi
/// (İngilizce) gelir, gösterilecek ad `name_tr` / `name_en`; darphane küçük harf anahtar; not ve dönem
/// metni TR/EN ikisi birden. `kind` (ruler | family | official | community) kart başlığını seçer.
class CoinIdentification {
  final String level; // type | ruler | dynasty | mint | date
  final String? basis; // obverse | reverse — portreyi taşıyan fotoğraf
  final String? rulerName;
  final String? rulerNameTr, rulerNameEn, rulerKind;
  final String? rulerReignTr, rulerReignEn, rulerNoteTr, rulerNoteEn;
  final List<String> rulerAlternatives, rulerAlternativesTr, rulerAlternativesEn;
  final String? dynastyNameTr, dynastyNameEn, dynastyNoteTr, dynastyNoteEn;
  final String? mint;
  final int? dateFrom, dateTo;
  final String? reverseStatus; // verified | unverified | not_sent
  final List<CoinMatch> reverseCandidates;

  const CoinIdentification({
    required this.level,
    this.basis,
    this.rulerName,
    this.rulerNameTr,
    this.rulerNameEn,
    this.rulerKind,
    this.rulerReignTr,
    this.rulerReignEn,
    this.rulerNoteTr,
    this.rulerNoteEn,
    this.rulerAlternatives = const [],
    this.rulerAlternativesTr = const [],
    this.rulerAlternativesEn = const [],
    this.dynastyNameTr,
    this.dynastyNameEn,
    this.dynastyNoteTr,
    this.dynastyNoteEn,
    this.mint,
    this.dateFrom,
    this.dateTo,
    this.reverseStatus,
    this.reverseCandidates = const [],
  });

  /// Bozuk ya da eksik veri uygulamayı kırmaz: düzeyi olmayan yanıt → null.
  static CoinIdentification? tryParse(Object? raw) {
    if (raw is! Map) return null;
    final j = Map<String, dynamic>.from(raw);
    final level = j['level'];
    if (level is! String || level.isEmpty) return null;
    Map<String, dynamic> m(Object? v) => v is Map ? Map<String, dynamic>.from(v) : const {};
    final ruler = m(j['ruler']);
    final dyn = m(j['dynasty']);
    final date = m(j['date']);
    final rev = m(j['reverse']);
    List<String> names(Object? v) => (v as List<dynamic>? ?? []).whereType<String>().toList();
    return CoinIdentification(
      level: level,
      basis: j['basis'] as String?,
      rulerName: ruler['name'] as String?,
      rulerNameTr: ruler['name_tr'] as String?,
      rulerNameEn: ruler['name_en'] as String?,
      rulerKind: ruler['kind'] as String?,
      rulerReignTr: ruler['reign_tr'] as String?,
      rulerReignEn: ruler['reign_en'] as String?,
      rulerNoteTr: ruler['note_tr'] as String?,
      rulerNoteEn: ruler['note_en'] as String?,
      rulerAlternatives: names(j['ruler_alternatives']),
      rulerAlternativesTr: names(j['ruler_alternatives_tr']),
      rulerAlternativesEn: names(j['ruler_alternatives_en']),
      dynastyNameTr: dyn['name_tr'] as String?,
      dynastyNameEn: dyn['name_en'] as String?,
      dynastyNoteTr: dyn['note_tr'] as String?,
      dynastyNoteEn: dyn['note_en'] as String?,
      mint: m(j['mint'])['name'] as String?,
      dateFrom: CoinMatch._toInt(date['from']),
      dateTo: CoinMatch._toInt(date['to']),
      reverseStatus: rev['status'] as String?,
      reverseCandidates: (rev['candidates'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((c) => CoinMatch(
                articleId: CoinMatch._toInt(c['article_id']) ?? 0,
                title: c['title'] as String? ?? '',
                confidence: (c['score'] as num?)?.toDouble() ?? 0.0,
              ))
          .where((c) => c.articleId > 0)
          .toList(),
    );
  }

  /// Bilgi kartı gösterilecek mi: doğrulanmış tipte yalnız hükümdar/dönem notu varsa.
  bool get hasContent => level == 'type'
      ? (rulerName != null || dynastyNameTr != null)
      : (rulerName != null || dynastyNameTr != null || mint != null || dateFrom != null);
}

/// Coin match result model
class CoinMatch {
  final int articleId;
  final String title;

  /// AI10: başlığın başındaki katalog otorite adı görünen adla değişmiş hali
  /// ("T. Ampius, governor of Asia …" → "T. Ampius Balbus …"); eski sunucuda yok → [title].
  final String? titleTr, titleEn;
  final double confidence;
  final String? region;
  final String? mintName; // Mint name
  final String? dateRange;

  /// Ham yıl (MÖ negatif). Ekranda CoinFormat.dateRange ile gösterilir;
  /// [dateRange] eski biçimsiz metin ("-133 - -50"), yalnız geriye uyumluluk.
  final int? dateFrom;
  final int? dateTo;
  final String? thumbnailUrl;
  final String? explanation;

  /// Faz A: yuz basina benzerlik skorlari (varsa).
  final double? obverseScore;
  final double? reverseScore;

  /// Faz D: yerel özellik doğrulamasından geçti (aynı sikke/kalıp).
  final bool verified;

  /// AI4: adayı taşıyan fotoğraf — both | obverse | reverse (tek yüz eşleşmesinde uyarı için).
  final String? basis;

  CoinMatch({
    required this.articleId,
    required this.title,
    this.titleTr,
    this.titleEn,
    required this.confidence,
    this.region,
    this.mintName,
    this.dateRange,
    this.dateFrom,
    this.dateTo,
    this.thumbnailUrl,
    this.explanation,
    this.obverseScore,
    this.reverseScore,
    this.verified = false,
    this.basis,
  });

  String displayTitle(bool en) => (en ? titleEn : titleTr) ?? title;

  factory CoinMatch.fromJson(Map<String, dynamic> json) {
    final regionAlias = json['region'] as String?;

    // Construct date range from date_from and date_to
    String? dateRange;
    final dateFrom = json['date_from'];
    final dateTo = json['date_to'];
    if (dateFrom != null || dateTo != null) {
      dateRange = '${dateFrom ?? "?"} - ${dateTo ?? "?"}';
    }

    return CoinMatch(
      articleId: (json['article_id'] as num?)?.toInt() ??
          int.tryParse('${json['article_id']}') ??
          0,
      title: json['title'] as String? ?? 'Unknown Coin',
      titleTr: json['title_tr'] as String?,
      titleEn: json['title_en'] as String?,
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0.0,
      region: regionAlias, // Alias (for compatibility)
      mintName: json['mint_name'] as String?,
      dateRange: dateRange ?? json['date_range'] as String?, // Fallback to direct field
      dateFrom: _toInt(dateFrom),
      dateTo: _toInt(dateTo),
      thumbnailUrl: json['thumbnail_url'] as String?, // Not provided by AI service yet
      explanation: json['explanation'] as String?,
      obverseScore: (json['obverse_score'] as num?)?.toDouble(),
      reverseScore: (json['reverse_score'] as num?)?.toDouble(),
      verified: json['verified'] == true,
      basis: json['basis'] as String?,
    );
  }

  static int? _toInt(Object? v) => v is num ? v.toInt() : int.tryParse('${v ?? ''}');

  /// Tarama geçmişine kaydetmek için; fromJson ile geri okunabilir.
  Map<String, dynamic> toJson() => {
        'article_id': articleId,
        'title': title,
        if (titleTr != null) 'title_tr': titleTr,
        if (titleEn != null) 'title_en': titleEn,
        'confidence': confidence,
        'region': region,
        'mint_name': mintName,
        'date_range': dateRange,
        'date_from': dateFrom,
        'date_to': dateTo,
        'thumbnail_url': thumbnailUrl,
        'explanation': explanation,
        'obverse_score': obverseScore,
        'reverse_score': reverseScore,
        'verified': verified,
        'basis': basis,
      };
}

/// Scan quota model
class ScanQuota {
  final int used;
  final int limit;
  final int _remaining; // Backend-provided remaining count
  final bool isPro;
  final DateTime? resetDate;

  /// M17: oturumsuz deneme kotası (sunucu `tier: anonymous`).
  final bool isAnonymous;

  /// Oturumsuz denemede sunucu denemeyi açık tutuyor mu (kapalı / ölçülemiyorsa false).
  final bool trialEnabled;

  ScanQuota({
    required this.used,
    required this.limit,
    required int remaining,
    required this.isPro,
    this.resetDate,
    this.isAnonymous = false,
    this.trialEnabled = true,
  }) : _remaining = remaining;

  /// Returns remaining scans. -1 means unlimited (Pro users)
  int get remaining => _remaining;

  /// Check if user has scans available
  bool get hasScansAvailable => isAnonymous
      ? trialEnabled && _remaining > 0
      : isPro || _remaining > 0 || _remaining == -1;

  factory ScanQuota.fromJson(Map<String, dynamic> json) {
    final isPro = json['is_pro'] as bool? ?? false;
    // /user/scan-quota `scan_limit`/`scans_used`, tanıma yanıtındaki kota `limit`/`used` der.
    final limit = (json['scan_limit'] ?? json['limit']) as int? ?? 10;
    final used = (json['scans_used'] ?? json['used']) as int? ?? 0;

    // Use backend-provided remaining, or calculate if not provided
    int remaining;
    if (json['remaining'] != null) {
      remaining = json['remaining'] as int;
    } else {
      remaining = isPro ? -1 : (limit - used);
    }

    return ScanQuota(
      used: used,
      limit: limit,
      remaining: remaining,
      isPro: isPro,
      resetDate: json['reset_date'] != null
          ? DateTime.tryParse(json['reset_date'] as String)
          : null,
      isAnonymous: json['tier'] == 'anonymous',
      trialEnabled: json['enabled'] as bool? ?? true,
    );
  }
}

// Providers

final recognitionServiceProvider = Provider<RecognitionService>((ref) {
  return RecognitionService(
    ref.watch(apiClientProvider),
    // M17: kurulum kimliği yalnız oturum yokken gider (oturumluyken gereksiz veri).
    anonymousDeviceId: () async => ref.read(authControllerProvider).authenticated
        ? null
        : await ref.read(installIdProvider.future),
  );
});

final recognitionControllerProvider =
    StateNotifierProvider<RecognitionController, AsyncValue<RecognitionResponse>>(
  (ref) => RecognitionController(ref.watch(recognitionServiceProvider)),
);

/// Kota, oturumdaki kullanıcıya ve abonelik katmanına bağlıdır; ikisi değişince
/// yeniden çekilir (M2). Aksi halde çıkış yapıp başka hesapla girince önceki
/// hesabın kotası/Pro'su, satın almadan sonra da eski 10/10 kartı görünürdü.
final scanQuotaProvider = FutureProvider<ScanQuota>((ref) async {
  ref.watch(authControllerProvider
      .select((s) => s.authenticated ? (s.userId ?? s.email) : null));
  ref.watch(subscriptionProvider.select((s) => s.isPro));

  final authController = ref.watch(authControllerProvider.notifier);
  final token = await authController.getValidAccessToken();
  final service = ref.watch(recognitionServiceProvider);

  if (token == null) {
    // M17: oturum yoksa kurulum kimliğiyle deneme hakkı okunur. Okunamazsa (deneme ucu
    // olmayan eski sunucu, ağ) hata kalır ve kamera bugünkü giriş penceresini gösterir.
    final deviceId = await ref.watch(installIdProvider.future);
    return service.getAnonQuota(deviceId);
  }

  return service.getQuota();
});

/// Recognition state controller
class RecognitionController extends StateNotifier<AsyncValue<RecognitionResponse>> {
  final RecognitionService _service;

  RecognitionController(this._service) : super(const AsyncValue.loading());

  Future<void> recognize(File imageFile, {bool skipPreFlight = false, Map<String, String> attrs = const {}}) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.recognize(imageFile, skipPreFlight: skipPreFlight, attrs: attrs);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  Future<void> recognizeDual(File obverseFile, File reverseFile, {bool skipPreFlight = false, Map<String, String> attrs = const {}}) async {
    state = const AsyncValue.loading();

    try {
      final result = await _service.recognizeDual(obverseFile, reverseFile, skipPreFlight: skipPreFlight, attrs: attrs);
      state = AsyncValue.data(result);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
    }
  }

  void reset() {
    state = const AsyncValue.loading();
  }
}
