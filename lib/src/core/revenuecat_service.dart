import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'env.dart';

/// RevenueCat configuration
class RevenueCatConfig {
  // Public SDK anahtarları — Env üzerinden (--dart-define ile geçilebilir)
  static const String androidApiKey = Env.revenueCatAndroidKey;
  static const String iosApiKey = Env.revenueCatIosKey;

  // Entitlement ID - RevenueCat Dashboard'da tanımlanacak
  static const String proEntitlementId = 'pro';

  // Product IDs - App Store Connect ve Google Play Console'da tanımlanacak
  static const String monthlyProductId = 'numistr_pro_monthly';
  static const String yearlyProductId = 'numistr_pro_yearly';
}

/// RevenueCat servis sınıfı
///
/// DAYANIKLILIK KURALI (iOS-01, 2026-09-07):
/// `Purchases.*` metodları SDK yapılandırılmamışken çağrılırsa native tarafta
/// **Swift fatalError** üretir ("Purchases has not been configured").
/// Bu bir Dart istisnası DEĞİLDİR — `try/catch` onu yakalayamaz, süreç
/// `signal 5` ile ölür. Bu yüzden native tarafa giden HER metod, `try` bloğuna
/// girmeden önce [_ensureConfigured] kapısından geçmek zorundadır.
///
/// iOS'ta anahtar boş (uygulama RevenueCat'e henüz eklenmedi), Android'de dolu;
/// ama Android'de de yapılandırma herhangi bir sebeple başarısız olabilir —
/// kapı iki platform için de gereklidir.
class RevenueCatService {
  static final RevenueCatService _instance = RevenueCatService._internal();
  factory RevenueCatService() => _instance;
  RevenueCatService._internal();

  bool _isInitialized = false;

  /// SDK gerçekten yapılandırıldı mı? (Satın alma arayüzü bunu gizlemek için kullanabilir.)
  bool get isConfigured => _isInitialized;

  /// Native tarafa gitmeden önceki tek kapı.
  ///
  /// Bir kez [initialize] denemesi yapar; SDK yine kurulu değilse `false` döner
  /// ve çağıran metod güvenli varsayılanla çıkar — `Purchases.*` asla çağrılmaz.
  Future<bool> _ensureConfigured() async {
    if (!_isInitialized) await initialize();
    return _isInitialized;
  }

  /// RevenueCat'i başlat
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Debug build'de ayrıntılı log, release'de sadece hatalar
      await Purchases.setLogLevel(kDebugMode ? LogLevel.debug : LogLevel.error);

      // Platform'a göre API key seç
      final String apiKey;
      if (Platform.isAndroid) {
        apiKey = RevenueCatConfig.androidApiKey;
      } else if (Platform.isIOS) {
        apiKey = RevenueCatConfig.iosApiKey;
      } else {
        debugPrint('RevenueCat: Unsupported platform');
        return;
      }

      // Anahtar tanımlı değilse (örn. iOS henüz eklenmedi) sessizce atla
      if (apiKey.isEmpty) {
        debugPrint(
          'RevenueCat: Bu platform için API anahtarı tanımlı değil, '
          'satın alma devre dışı (${Platform.operatingSystem})',
        );
        return;
      }

      await Purchases.configure(PurchasesConfiguration(apiKey));
      _isInitialized = true;
      debugPrint('RevenueCat initialized successfully');
    } catch (e) {
      debugPrint('RevenueCat initialization failed: $e');
    }
  }

  /// Kullanıcı ID'si ile giriş yap (Auth sonrası çağır)
  Future<void> login(String userId) async {
    if (!await _ensureConfigured()) {
      debugPrint('RevenueCat login atlandı: SDK yapılandırılmadı');
      return;
    }

    try {
      final result = await Purchases.logIn(userId);
      debugPrint('RevenueCat login successful: ${result.customerInfo.originalAppUserId}');
    } catch (e) {
      debugPrint('RevenueCat login failed: $e');
    }
  }

  /// Çıkış yap
  Future<void> logout() async {
    if (!_isInitialized) return;

    try {
      await Purchases.logOut();
      debugPrint('RevenueCat logout successful');
    } catch (e) {
      debugPrint('RevenueCat logout failed: $e');
    }
  }

  /// Mevcut abonelik durumunu kontrol et
  Future<bool> checkProStatus() async {
    if (!await _ensureConfigured()) return false;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final isPro = customerInfo.entitlements.active.containsKey(RevenueCatConfig.proEntitlementId);
      debugPrint('RevenueCat pro status: $isPro');
      return isPro;
    } catch (e) {
      debugPrint('RevenueCat check pro status failed: $e');
      return false;
    }
  }

  /// Müşteri bilgilerini al
  Future<CustomerInfo?> getCustomerInfo() async {
    if (!await _ensureConfigured()) return null;

    try {
      return await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint('RevenueCat get customer info failed: $e');
      return null;
    }
  }

  /// Abonelik bitiş tarihini al
  Future<DateTime?> getExpirationDate() async {
    if (!await _ensureConfigured()) return null;

    try {
      final customerInfo = await Purchases.getCustomerInfo();
      final entitlement = customerInfo.entitlements.active[RevenueCatConfig.proEntitlementId];
      if (entitlement?.expirationDate != null) {
        return DateTime.parse(entitlement!.expirationDate!);
      }
      return null;
    } catch (e) {
      debugPrint('RevenueCat get expiration date failed: $e');
      return null;
    }
  }

  /// Mevcut teklifleri (offerings) al
  Future<Offerings?> getOfferings() async {
    if (!await _ensureConfigured()) return null;

    try {
      final offerings = await Purchases.getOfferings();
      debugPrint('RevenueCat offerings: ${offerings.current?.availablePackages.length ?? 0} packages');
      return offerings;
    } catch (e) {
      debugPrint('RevenueCat get offerings failed: $e');
      return null;
    }
  }

  /// Satın alma işlemi yap
  Future<PurchaseOutcome> purchasePackage(Package package) async {
    if (!await _ensureConfigured()) {
      return PurchaseOutcome(
        success: false,
        error: 'Satın alma bu cihazda şu anda kullanılamıyor',
      );
    }

    try {
      // purchases_flutter 9+ : purchasePackage artik CustomerInfo degil
      // PurchaseResult donduruyor (customerInfo + storeTransaction).
      final purchase = await Purchases.purchasePackage(package);
      final customerInfo = purchase.customerInfo;
      final isPro = customerInfo.entitlements.active.containsKey(RevenueCatConfig.proEntitlementId);

      if (isPro) {
        debugPrint('RevenueCat purchase successful - Pro active');
        return PurchaseOutcome(
          success: true,
          isPro: true,
          expirationDate: _getExpirationFromCustomerInfo(customerInfo),
        );
      } else {
        debugPrint('RevenueCat purchase completed but Pro not active');
        return PurchaseOutcome(
          success: false,
          error: 'Satın alma tamamlandı ancak Pro aktif değil',
        );
      }
    } on PurchasesErrorCode catch (e) {
      debugPrint('RevenueCat purchase error: $e');
      return PurchaseOutcome(
        success: false,
        error: _getErrorMessage(e),
        isCancelled: e == PurchasesErrorCode.purchaseCancelledError,
      );
    } catch (e) {
      debugPrint('RevenueCat purchase failed: $e');
      return PurchaseOutcome(
        success: false,
        error: e.toString(),
      );
    }
  }

  /// Satın almaları geri yükle
  Future<PurchaseOutcome> restorePurchases() async {
    if (!await _ensureConfigured()) {
      return PurchaseOutcome(
        success: false,
        error: 'Satın alma bu cihazda şu anda kullanılamıyor',
      );
    }

    try {
      final customerInfo = await Purchases.restorePurchases();
      final isPro = customerInfo.entitlements.active.containsKey(RevenueCatConfig.proEntitlementId);

      return PurchaseOutcome(
        success: true,
        isPro: isPro,
        expirationDate: isPro ? _getExpirationFromCustomerInfo(customerInfo) : null,
      );
    } catch (e) {
      debugPrint('RevenueCat restore failed: $e');
      return PurchaseOutcome(
        success: false,
        error: 'Satın almalar geri yüklenemedi: $e',
      );
    }
  }

  /// CustomerInfo'dan bitiş tarihini al
  DateTime? _getExpirationFromCustomerInfo(CustomerInfo customerInfo) {
    final entitlement = customerInfo.entitlements.active[RevenueCatConfig.proEntitlementId];
    if (entitlement?.expirationDate != null) {
      return DateTime.parse(entitlement!.expirationDate!);
    }
    return null;
  }

  /// Hata mesajlarını Türkçeleştir
  String _getErrorMessage(PurchasesErrorCode errorCode) {
    switch (errorCode) {
      case PurchasesErrorCode.purchaseCancelledError:
        return 'Satın alma iptal edildi';
      case PurchasesErrorCode.purchaseNotAllowedError:
        return 'Satın alma bu cihazda izin verilmiyor';
      case PurchasesErrorCode.purchaseInvalidError:
        return 'Geçersiz satın alma';
      case PurchasesErrorCode.productNotAvailableForPurchaseError:
        return 'Ürün satın alınamıyor';
      case PurchasesErrorCode.productAlreadyPurchasedError:
        return 'Bu ürün zaten satın alınmış';
      case PurchasesErrorCode.networkError:
        return 'Ağ hatası. İnternet bağlantınızı kontrol edin';
      case PurchasesErrorCode.receiptAlreadyInUseError:
        return 'Bu makbuz zaten başka bir hesapta kullanılıyor';
      case PurchasesErrorCode.storeProblemError:
        return 'Mağaza hatası. Lütfen daha sonra tekrar deneyin';
      default:
        return 'Satın alma hatası: $errorCode';
    }
  }

  /// Abonelik değişikliklerini dinle
  ///
  /// SDK kurulu değilse sessizce atlanır — dinleyici kaydı da native tarafa
  /// gider ve yapılandırılmamış SDK'da fatalError üretir.
  void addCustomerInfoListener(void Function(CustomerInfo) listener) {
    if (!_isInitialized) return;
    Purchases.addCustomerInfoUpdateListener(listener);
  }

  /// Dinleyiciyi kaldır
  void removeCustomerInfoListener(void Function(CustomerInfo) listener) {
    if (!_isInitialized) return;
    Purchases.removeCustomerInfoUpdateListener(listener);
  }
}

/// Satın alma sonucu
class PurchaseOutcome {
  final bool success;
  final bool isPro;
  final DateTime? expirationDate;
  final String? error;
  final bool isCancelled;

  PurchaseOutcome({
    required this.success,
    this.isPro = false,
    this.expirationDate,
    this.error,
    this.isCancelled = false,
  });
}
