import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../auth/auth_controller.dart';
import 'api_client.dart';
import 'revenuecat_service.dart';

/// Kullanıcının abonelik durumu
enum SubscriptionTier {
  free,
  pro,
}

/// Abonelik durumu state
class SubscriptionState {
  final SubscriptionTier tier;
  final bool isActive;
  final DateTime? expiryDate;
  final bool isLoading;
  final String? error;

  /// Abonelik mağaza (App Store / Play) üzerinden mi yönetiliyor?
  ///
  /// `false` + [isPro] `true` ⇒ üyelik web tarafından (iyzico) geliyor; kullanıcı
  /// iptal/değişiklik için numistr.org'a yönlendirilmeli, mağaza ayarlarına DEĞİL.
  final bool managedByStore;

  SubscriptionState({
    required this.tier,
    required this.isActive,
    this.expiryDate,
    this.isLoading = false,
    this.error,
    this.managedByStore = false,
  });

  bool get isPro => tier == SubscriptionTier.pro && isActive;
  bool get isFree => tier == SubscriptionTier.free;

  SubscriptionState copyWith({
    SubscriptionTier? tier,
    bool? isActive,
    DateTime? expiryDate,
    bool? isLoading,
    String? error,
    bool? managedByStore,
  }) {
    return SubscriptionState(
      tier: tier ?? this.tier,
      isActive: isActive ?? this.isActive,
      expiryDate: expiryDate ?? this.expiryDate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
      managedByStore: managedByStore ?? this.managedByStore,
    );
  }
}

/// Abonelik kontrolcüsü - RevenueCat entegrasyonlu
class SubscriptionController extends StateNotifier<SubscriptionState> {
  final RevenueCatService _revenueCat;
  final ApiClient _api;
  late final void Function(CustomerInfo) _customerInfoListener;

  /// Backend'in (Joomla) son bildirdiği Pro durumu.
  ///
  /// Neden ayrı tutuluyor: iki bağımsız ödeme kanalı var (mağaza ve web/iyzico) ve
  /// hiçbiri diğerini görmüyor. RevenueCat listener'ı tetiklendiğinde state'i
  /// baştan kurduğu için, web kaynaklı üyeliğin kaybolmaması adına burada saklanır.
  bool _backendPro = false;

  /// Web (iyzico) aboneliğinin dönem sonu — yalnız GELECEKTEKİ tarih tutulur.
  ///
  /// Backend geçmiş bir tarih de döndürebilir (housekeeping cron'u henüz süpürmemişse);
  /// "şu tarihe kadar geçerli" kartında geçmiş tarih göstermek yanlış olur, burada süzülür.
  /// Mağaza aboneliğinde tarih RevenueCat'ten gelir, backend'den gelmez.
  DateTime? _backendExpiry;

  SubscriptionController(this._revenueCat, this._api)
      : super(SubscriptionState(
          tier: SubscriptionTier.free,
          isActive: true,
          isLoading: true,
        )) {
    _customerInfoListener = _updateFromCustomerInfo;
    _init();
  }

  /// Başlangıç işlemleri
  Future<void> _init() async {
    try {
      // RevenueCat'i başlat
      await _revenueCat.initialize();

      // Mevcut durumu kontrol et
      await checkSubscription();

      // Değişiklikleri dinle
      _revenueCat.addCustomerInfoListener(_customerInfoListener);
    } catch (e) {
      debugPrint('Subscription init error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// CustomerInfo + backend durumundan state güncelle
  ///
  /// Pro = mağaza entitlement'ı aktif **VEYA** backend Pro diyor. İki kanaldan
  /// biri Pro diyorsa Pro sayılır; aksi halde web'den ödeme yapan kullanıcı
  /// uygulamada ücretsiz görünür ve aynı üyeliği ikinci kez satın alabilir.
  void _updateFromCustomerInfo(CustomerInfo customerInfo) {
    final storePro = customerInfo.entitlements.active.containsKey(
      RevenueCatConfig.proEntitlementId,
    );
    final isPro = storePro || _backendPro;

    DateTime? expiryDate;
    if (storePro) {
      final entitlement = customerInfo.entitlements.active[RevenueCatConfig.proEntitlementId];
      if (entitlement?.expirationDate != null) {
        expiryDate = DateTime.parse(entitlement!.expirationDate!);
      }
    } else {
      // Web (iyzico) üyeliği: tarih backend'den (`expires_at`) gelir.
      expiryDate = _backendExpiry;
    }

    debugPrint('Subscription: store=$storePro backend=$_backendPro '
        'expiry=${expiryDate?.toIso8601String() ?? "-"} -> isPro=$isPro');

    state = SubscriptionState(
      tier: isPro ? SubscriptionTier.pro : SubscriptionTier.free,
      isActive: true,
      expiryDate: expiryDate,
      isLoading: false,
      managedByStore: storePro,
    );
  }

  /// RevenueCat'e login edilmiş son kullanıcı (tekrarlı logIn çağrısını önler)
  String? _lastLoginId;

  /// Kullanıcı girişi sonrası RevenueCat'e login
  Future<void> loginUser(String userId) async {
    if (userId.isEmpty || userId == _lastLoginId) return;
    _lastLoginId = userId;
    await _revenueCat.login(userId);
    await checkSubscription();
  }

  /// Kullanıcı çıkışı
  Future<void> logoutUser() async {
    if (_lastLoginId == null) return;
    _lastLoginId = null;
    _backendPro = false;
    _backendExpiry = null;
    await _revenueCat.logout();
    state = SubscriptionState(
      tier: SubscriptionTier.free,
      isActive: true,
      isLoading: false,
    );
  }

  /// Aboneliği iki kaynaktan kontrol et: mağaza (RevenueCat) + backend (Joomla)
  Future<void> checkSubscription() async {
    state = state.copyWith(isLoading: true, error: null);

    await _fetchBackendSubscription();

    try {
      final customerInfo = await _revenueCat.getCustomerInfo();
      if (customerInfo != null) {
        _updateFromCustomerInfo(customerInfo);
      } else {
        // Mağaza SDK'sı yok/yapılandırılmadı (ör. anahtar boş): yalnız backend'e göre karar ver.
        state = SubscriptionState(
          tier: _backendPro ? SubscriptionTier.pro : SubscriptionTier.free,
          isActive: true,
          isLoading: false,
          managedByStore: false,
        );
      }
    } catch (e) {
      debugPrint('Check subscription error: $e');
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  /// `GET /v1/user/subscription` → `_backendPro` + `_backendExpiry`
  ///
  /// Giriş yapılmamışsa uç 401 döner; bu bir hata değil, "Pro değil" demektir.
  /// Ağ hatasında da false döner — mağaza tarafı yine kendi başına değerlendirilir.
  Future<void> _fetchBackendSubscription() async {
    _backendPro = false;
    _backendExpiry = null;

    try {
      final response = await _api.dio.get('/user/subscription');
      final body = response.data;

      if (body is! Map || body['data'] is! Map) {
        return;
      }

      final data = body['data'] as Map;
      _backendPro = data['is_pro'] == true;

      // `expires_at` yalnızca web (iyzico) aboneliğinde dolu gelir; mağaza
      // aboneliğinde ve üniversite grubundan gelen Pro'da null.
      final raw = data['expires_at'];

      if (_backendPro && raw is String && raw.isNotEmpty) {
        final parsed = DateTime.tryParse(raw);

        if (parsed != null && parsed.isAfter(DateTime.now())) {
          _backendExpiry = parsed;
        }
      }
    } catch (e) {
      debugPrint('Backend subscription check skipped: $e');
    }
  }

  /// Satın alma işlemi
  Future<PurchaseOutcome> purchase(Package package) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _revenueCat.purchasePackage(package);

      if (result.success && result.isPro) {
        state = SubscriptionState(
          tier: SubscriptionTier.pro,
          isActive: true,
          expiryDate: result.expirationDate,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return PurchaseOutcome(success: false, error: e.toString());
    }
  }

  /// Satın almaları geri yükle
  Future<PurchaseOutcome> restorePurchases() async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _revenueCat.restorePurchases();

      if (result.success) {
        state = SubscriptionState(
          tier: result.isPro ? SubscriptionTier.pro : SubscriptionTier.free,
          isActive: true,
          expiryDate: result.expirationDate,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          error: result.error,
        );
      }

      return result;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
      return PurchaseOutcome(success: false, error: e.toString());
    }
  }

  /// Pro üyeliği aktif et (TEST İÇİN - Production'da kaldırın)
  @visibleForTesting
  void activateProForTesting({DateTime? expiryDate}) {
    state = SubscriptionState(
      tier: SubscriptionTier.pro,
      isActive: true,
      expiryDate: expiryDate,
      isLoading: false,
    );
  }

  /// Ücretsiz versiyona dön (TEST İÇİN - Production'da kaldırın)
  @visibleForTesting
  void deactivateProForTesting() {
    state = SubscriptionState(
      tier: SubscriptionTier.free,
      isActive: true,
      isLoading: false,
    );
  }

  @override
  void dispose() {
    _revenueCat.removeCustomerInfoListener(_customerInfoListener);
    super.dispose();
  }
}

/// RevenueCat servis provider
final revenueCatServiceProvider = Provider<RevenueCatService>((ref) {
  return RevenueCatService();
});

/// Subscription provider
///
/// Auth durumunu dinler: giriş yapan kullanıcının Auth0 `sub`'ı RevenueCat
/// appUserID olarak bağlanır (abonelik hesabı takip eder, cihazı değil);
/// çıkışta RevenueCat'ten de çıkılır.
final subscriptionProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (ref) {
    final revenueCat = ref.watch(revenueCatServiceProvider);
    final controller = SubscriptionController(revenueCat, ref.watch(apiClientProvider));

    ref.listen<AuthState>(
      authControllerProvider,
      (previous, next) {
        final rcUserId = next.userId ?? next.email;
        if (next.authenticated && rcUserId != null && rcUserId.isNotEmpty) {
          controller.loginUser(rcUserId);
        } else if ((previous?.authenticated ?? false) && !next.authenticated) {
          controller.logoutUser();
        }
      },
      fireImmediately: true,
    );

    return controller;
  },
);

/// Offerings provider - mevcut satın alma seçenekleri
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  final revenueCat = ref.watch(revenueCatServiceProvider);
  return await revenueCat.getOfferings();
});

/// Özellik limitleri ve kısıtlamalar
class FeatureLimits {
  static const int freeMaxFavorites = 10;
  static const int proMaxFavorites = 999999; // unlimited

  static const int freeMaxCollections = 1;
  static const int proMaxCollections = 999999;

  static const bool freeOfflineAccess = false;
  static const bool proOfflineAccess = true;

  static const bool freeCoinRecognition = true; // Free tier: 10 scans/month
  static const bool proCoinRecognition = true;  // Pro tier: unlimited

  static const int freeMonthlyScans = 10;
  static const int proMonthlyScans = 999999; // unlimited

  static const bool freeHighResImages = false;
  static const bool proHighResImages = true;

  static const bool freeExpertSupport = false;
  static const bool proExpertSupport = true;

  static const bool freeAdsEnabled = true;
  static const bool proAdsEnabled = false;
}
