import 'dart:io' show Platform;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kullanıcının analitik onayı.
enum AnalyticsConsent { unknown, granted, denied }

/// Firebase Analytics (GA4 uygulama akışları) — Prime NT-261112-01321879 / -015431th.
///
/// Kurallar (kullanıcı kararları, 12 Kas 2026):
/// - Onay HERKESE ilk açılışta sorulur (KVKK + AEA/UK/CH).
/// - Onaydan önce HİÇ veri gitmez (Consent Mode "temel"): native tarafta toplama
///   kapalı başlar (AndroidManifest / Info.plist), yalnız onayla açılır.
/// - Onay = analytics_storage + ad_storage + ad_user_data; ad_personalization HEP kapalı
///   (yeniden hedefleme yok; "reklam yok, veri satılmaz" sözü).
/// - Reklam kimliği yok: Android AD_ID izni manifestten silinir, iOS'ta IDFA/ATT yok.
/// - Olaylarda kişisel veri, fotoğraf, serbest metin YOK.
///
/// Firebase yapılandırması depoda değil (depo herkese açık): `env/firebase.json`
/// (`--dart-define-from-file`, kaynak Drive OTURUM/numistr_firebase/firebase.json).
/// Dosya verilmeyen derlemede (dev) Firebase hiç başlamaz, onay da sorulmaz.
class AppAnalytics {
  AppAnalytics._(this._prefs);

  /// Uygulama genelinde tek örnek; `init` öncesi ve Firebase yokken her çağrı boşa düşer.
  static AppAnalytics instance = AppAnalytics._(null);

  static const consentPrefKey = 'analytics_consent_v1';

  final SharedPreferences? _prefs;
  FirebaseAnalytics? _fa;
  String? _lastScreen;

  /// Firebase bu derlemede yapılandırılmış ve başlatılmış mı?
  bool get isAvailable => _fa != null;

  AnalyticsConsent get consent {
    switch (_prefs?.getString(consentPrefKey)) {
      case 'granted':
        return AnalyticsConsent.granted;
      case 'denied':
        return AnalyticsConsent.denied;
      default:
        return AnalyticsConsent.unknown;
    }
  }

  bool get _canLog => _fa != null && consent == AnalyticsConsent.granted;

  static Future<AppAnalytics> init(SharedPreferences prefs) async {
    final service = AppAnalytics._(prefs);
    final options = FirebaseEnv.currentPlatformOptions();
    if (options != null) {
      try {
        try {
          await Firebase.initializeApp(options: options);
        } on FirebaseException catch (e) {
          // Android'de google_app_id kaynağı varken varsayılan uygulama yerelde zaten
          // başlamış olabilir; aynı ayarlar, mevcut olanı kullan.
          if (e.code != 'duplicate-app') rethrow;
          Firebase.app();
        }
        service._fa = FirebaseAnalytics.instance;
        await service._apply(resetOnDeny: false);
      } catch (e) {
        debugPrint('⚠️ [Analytics] Firebase başlatılamadı: $e');
        service._fa = null;
      }
    } else {
      debugPrint('ℹ️ [Analytics] env/firebase.json verilmedi — analitik kapalı');
    }
    instance = service;
    return service;
  }

  Future<void> setConsent(bool granted) async {
    final wasGranted = consent == AnalyticsConsent.granted;
    await _prefs?.setString(consentPrefKey, granted ? 'granted' : 'denied');
    // Geri çekilirse cihazdaki uygulama örneği kimliği de silinir.
    await _apply(resetOnDeny: wasGranted && !granted);
  }

  Future<void> _apply({required bool resetOnDeny}) async {
    final fa = _fa;
    if (fa == null) return;
    final granted = consent == AnalyticsConsent.granted;
    try {
      await fa.setConsent(
        analyticsStorageConsentGranted: granted,
        adStorageConsentGranted: granted,
        adUserDataConsentGranted: granted,
        adPersonalizationSignalsConsentGranted: false,
      );
      await fa.setAnalyticsCollectionEnabled(granted);
      if (resetOnDeny) await fa.resetAnalyticsData();
    } catch (e) {
      debugPrint('⚠️ [Analytics] onay uygulanamadı: $e');
    }
  }

  Future<void> _log(String name, [Map<String, Object>? params]) async {
    if (!_canLog) return;
    try {
      await _fa!.logEvent(name: name, parameters: params);
    } catch (e) {
      debugPrint('⚠️ [Analytics] $name gönderilemedi: $e');
    }
  }

  /// Ekran adı: GoRouter kalıbı (`/variant/:id`), kimlik değil. Ardışık tekrar atılır.
  Future<void> screenView(String screenName) async {
    if (!_canLog || screenName.isEmpty || screenName == _lastScreen) return;
    _lastScreen = screenName;
    try {
      await _fa!.logScreenView(screenName: screenName, screenClass: 'Flutter');
    } catch (_) {}
  }

  /// Tanıma tamamlandı. Fotoğraf ya da benzerlik değerinin kendisi gitmez; yalnız kova.
  Future<void> recognitionComplete({
    required int candidateCount,
    required bool noMatch,
    required bool uncertain,
    required int sides,
    required bool modernCoin,
    double? topConfidence,
  }) =>
      _log('recognition_complete', {
        'candidate_count': candidateCount,
        'no_match': noMatch ? 'yes' : 'no',
        'uncertain': uncertain ? 'yes' : 'no',
        'sides': sides,
        'modern_coin': modernCoin ? 'yes' : 'no',
        'score_bucket': scoreBucket(topConfidence),
      });

  Future<void> login(String method) async {
    if (!_canLog) return;
    try {
      await _fa!.logLogin(loginMethod: method);
    } catch (_) {}
  }

  Future<void> signUp(String method) async {
    if (!_canLog) return;
    try {
      await _fa!.logSignUp(signUpMethod: method);
    } catch (_) {}
  }

  /// Sikke ayrıntısı (katalog kimliği kişisel veri değildir).
  Future<void> viewItem(int variantId) async {
    if (!_canLog) return;
    try {
      await _fa!.logViewItem(
        items: [AnalyticsEventItem(itemId: '$variantId', itemCategory: 'coin')],
      );
    } catch (_) {}
  }

  /// Blog yazısı açıldı.
  Future<void> selectArticle(int articleId) async {
    if (!_canLog) return;
    try {
      await _fa!.logSelectContent(contentType: 'article', itemId: '$articleId');
    } catch (_) {}
  }

  /// Asistana soru soruldu; sorunun metni GİTMEZ.
  Future<void> assistantQuestion(String lang) => _log('assistant_question', {'lang': lang});

  /// Pro abonelik başladı (RevenueCat satın alması başarılı).
  /// Play/StoreKit'in kendiliğinden `in_app_purchase` olayından farklı ad: dönüşüm
  /// olarak yalnız `purchase` işaretlenir, çift sayım olmaz.
  Future<void> purchase({
    required String productId,
    required double value,
    required String currency,
  }) async {
    if (!_canLog) return;
    try {
      await _fa!.logPurchase(
        currency: currency,
        value: value,
        items: [AnalyticsEventItem(itemId: productId, itemCategory: 'subscription')],
      );
    } catch (_) {}
  }

  /// Benzerlik değerini (sunucuda 0–1) kaba kovaya çevirir; değerin kendisi gitmez.
  @visibleForTesting
  static String scoreBucket(double? confidence) {
    if (confidence == null) return 'none';
    final pct = confidence * 100;
    if (pct < 40) return '0-40';
    if (pct < 60) return '40-60';
    if (pct < 80) return '60-80';
    return '80-100';
  }
}

/// `--dart-define-from-file=env/firebase.json` değerleri.
class FirebaseEnv {
  static const projectId = String.fromEnvironment('FIREBASE_PROJECT_ID');
  static const senderId = String.fromEnvironment('FIREBASE_SENDER_ID');
  static const storageBucket = String.fromEnvironment('FIREBASE_STORAGE_BUCKET');
  static const androidAppId = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
  static const androidApiKey = String.fromEnvironment('FIREBASE_ANDROID_API_KEY');
  static const iosAppId = String.fromEnvironment('FIREBASE_IOS_APP_ID');
  static const iosApiKey = String.fromEnvironment('FIREBASE_IOS_API_KEY');
  static const iosBundleId = String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID');

  static FirebaseOptions? currentPlatformOptions() {
    if (kIsWeb || projectId.isEmpty || senderId.isEmpty) return null;
    if (Platform.isAndroid && androidAppId.isNotEmpty && androidApiKey.isNotEmpty) {
      return FirebaseOptions(
        apiKey: androidApiKey,
        appId: androidAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
      );
    }
    if (Platform.isIOS && iosAppId.isNotEmpty && iosApiKey.isNotEmpty) {
      return FirebaseOptions(
        apiKey: iosApiKey,
        appId: iosAppId,
        messagingSenderId: senderId,
        projectId: projectId,
        storageBucket: storageBucket.isEmpty ? null : storageBucket,
        iosBundleId: iosBundleId.isEmpty ? null : iosBundleId,
      );
    }
    return null;
  }
}

/// Arayüz için onay durumu (ayarlardaki anahtar + ilk açılış penceresi).
class AnalyticsConsentNotifier extends StateNotifier<AnalyticsConsent> {
  AnalyticsConsentNotifier() : super(AppAnalytics.instance.consent);

  Future<void> set(bool granted) async {
    await AppAnalytics.instance.setConsent(granted);
    state = AppAnalytics.instance.consent;
  }
}

final analyticsConsentProvider =
    StateNotifierProvider<AnalyticsConsentNotifier, AnalyticsConsent>(
  (ref) => AnalyticsConsentNotifier(),
);
