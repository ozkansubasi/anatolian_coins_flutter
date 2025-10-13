import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  SubscriptionState({
    required this.tier,
    required this.isActive,
    this.expiryDate,
  });

  bool get isPro => tier == SubscriptionTier.pro && isActive;
  bool get isFree => tier == SubscriptionTier.free;
}

/// Abonelik kontrolcüsü
class SubscriptionController extends StateNotifier<SubscriptionState> {
  SubscriptionController()
      : super(SubscriptionState(
          tier: SubscriptionTier.free,
          isActive: true,
        ));

  /// Pro üyeliği aktif et (test için)
  void activatePro({DateTime? expiryDate}) {
    state = SubscriptionState(
      tier: SubscriptionTier.pro,
      isActive: true,
      expiryDate: expiryDate,
    );
  }

  /// Ücretsiz versiyona dön
  void deactivatePro() {
    state = SubscriptionState(
      tier: SubscriptionTier.free,
      isActive: true,
    );
  }

  /// Aboneliği kontrol et (backend'den)
  Future<void> checkSubscription() async {
    // TODO: Backend API'den abonelik durumunu çek
    // final response = await api.getSubscriptionStatus();
    // state = SubscriptionState(...);
  }
}

/// Provider
final subscriptionProvider =
    StateNotifierProvider<SubscriptionController, SubscriptionState>(
  (ref) => SubscriptionController(),
);

/// Özellik limitleri ve kısıtlamalar
class FeatureLimits {
  static const int freeMaxFavorites = 10;
  static const int proMaxFavorites = 999999; // unlimited
  
  static const int freeMaxCollections = 1;
  static const int proMaxCollections = 999999;
  
  static const bool freeOfflineAccess = false;
  static const bool proOfflineAccess = true;
  
  static const bool freeCoinRecognition = false;
  static const bool proCoinRecognition = true;
  
  static const bool freeHighResImages = false;
  static const bool proHighResImages = true;
  
  static const bool freeExpertSupport = false;
  static const bool proExpertSupport = true;
  
  static const bool freeAdsEnabled = true;
  static const bool proAdsEnabled = false;
}