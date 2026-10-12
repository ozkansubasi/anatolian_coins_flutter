import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../auth/auth_controller.dart';
import '../../core/app_log.dart';
import '../../core/subscription_provider.dart';
import '../../core/web_links.dart';
import '../assistant/assistant_provider.dart';
import '../collections/collections_service.dart';
import '../favorites/favorites_service.dart';
import '../history/scan_history_service.dart';
import '../offline/offline_service.dart';
import '../recognition/recognition_service.dart';
import '../settings/settings_provider.dart';
import 'account_deletion_api.dart';

// ---------------------------------------------------------------------------
// Onay kelimesi
// ---------------------------------------------------------------------------

/// Onay kelimesini karşılaştırmaya hazırlar: boşluklar atılır, büyük harfe
/// çevrilir. Dart'ın büyük/küçük harf dönüşümü dilden bağımsızdır; Türkçe
/// noktalı/noktasız i'ler önce ortak biçime indirilir ki "sil", "Sil", "SİL"
/// ve "SIL" aynı sayılsın ("İ".toLowerCase() birleşik nokta da üretir).
String normalizeConfirmWord(String input) => input
    .trim()
    .replaceAll('\u0130', 'I') // büyük noktalı I
    .replaceAll('\u0131', 'I') // noktasız ı
    .replaceAll('\u0307', '') // birleşik üst nokta
    .toUpperCase();

/// Kullanıcının yazdığı metin yerelleştirilmiş onay kelimesiyle eşleşiyor mu?
bool confirmWordMatches(String input, String word) {
  final expected = normalizeConfirmWord(word);
  return expected.isNotEmpty && normalizeConfirmWord(input) == expected;
}

// ---------------------------------------------------------------------------
// Mağaza aboneliği (hesap silmek onu iptal etmez)
// ---------------------------------------------------------------------------

/// Ücretlendirmenin sürdüğü mağaza.
enum ManagedStore { appStore, playStore }

/// RevenueCat yetkisinin mağazası → kullanıcıyı yönlendireceğimiz mağaza.
/// Promosyon (RevenueCat panelinden verilen) ve kullanılmayan mağazalarda
/// ücretlendirme yok/bizden yönetilemez: null.
ManagedStore? managedStoreOf(Store store) => switch (store) {
      Store.appStore || Store.macAppStore => ManagedStore.appStore,
      Store.playStore => ManagedStore.playStore,
      _ => null,
    };

/// Etkin mağaza aboneliğinin mağazası; yoksa null.
ManagedStore? activeManagedStore(CustomerInfo info) {
  for (final entitlement in info.entitlements.active.values) {
    final store = managedStoreOf(entitlement.store);
    if (store != null) return store;
  }
  return null;
}

/// Aboneliği yönetme (iptal) sayfası. Abonelik hangi mağazadan alındıysa o:
/// normalde cihazın mağazasıdır, başka platformda alınmışsa oranınki.
Uri manageSubscriptionUrl(ManagedStore store) => switch (store) {
      ManagedStore.appStore => appStoreSubscriptionsUrl(),
      ManagedStore.playStore => playSubscriptionsUrl(),
    };

/// Hesap silme ekranı: etkin mağaza aboneliği var mı (RevenueCat CustomerInfo)?
/// SDK kurulu değilse ya da okunamazsa null — uyarı gösterilmez.
final activeStoreSubscriptionProvider = FutureProvider.autoDispose<ManagedStore?>((ref) async {
  final info = await ref.watch(revenueCatServiceProvider).getCustomerInfo();
  return info == null ? null : activeManagedStore(info);
});

/// Hesap silme ekranı: süren web (iyzico) aboneliği var mı? Sunucu silmeyle
/// birlikte onu iptal eder; kullanıcıya bildirilir.
final webSubscriptionActiveProvider = Provider.autoDispose<bool>(
  (ref) => ref.watch(subscriptionProvider.select((s) => s.hasWebSubscription)),
);

// ---------------------------------------------------------------------------
// Yerel temizlik
// ---------------------------------------------------------------------------

/// Hesap silindikten sonra cihazdan kaldırılacak bir adım.
class CleanupStep {
  const CleanupStep(this.name, this.run);

  final String name;
  final Future<void> Function() run;
}

/// Sunucuda silinen hesabın bu cihazdaki izlerini kaldırır.
///
/// Adımlar sırayla ve BİRBİRİNDEN BAĞIMSIZ çalışır: biri hata verse de
/// (ör. dosya kilitli) diğerleri yapılır — hesap sunucuda zaten silindi,
/// en azından oturum mutlaka kapanmalı.
class LocalAccountCleanup {
  const LocalAccountCleanup(this.steps);

  final List<CleanupStep> steps;

  /// Başarısız adımların adlarını döndürür (yalnız günlük için).
  Future<List<String>> run() async {
    final failed = <String>[];
    for (final step in steps) {
      try {
        await step.run();
      } catch (e) {
        debugPrint('! Account cleanup step "${step.name}" failed: $e');
        failed.add(step.name);
      }
    }
    return failed;
  }
}

/// Kullanıcı verisi taşıyan klasörler (uygulama belgeleri altında): çevrimdışı
/// sikke görselleri ve tarama geçmişinin kopyaladığı fotoğraflar.
const userFileDirectories = [
  OfflineService.imagesDirName,
  ScanHistoryService.imagesDirName,
];

/// [documents] altındaki kullanıcı klasörlerini siler. Veritabanı dosyası
/// burada silinmez: açık bağlantı SQL ile boşaltılır (OfflineDatabase.clearAll).
Future<void> deleteUserFiles(Directory documents) async {
  for (final name in userFileDirectories) {
    final dir = Directory(p.join(documents.path, name));
    if (await dir.exists()) await dir.delete(recursive: true);
  }
}

/// Hesaba bağlı tercihleri siler; tema gibi cihaz tercihleri kalır.
Future<void> clearUserPreferences(SharedPreferences prefs) async {
  for (final key in SettingsKeys.userScoped) {
    await prefs.remove(key);
  }
}

/// Uygulamadaki temizlik adımları. Sıra önemli: önce veriler, en son oturum
/// (oturum kapanınca ekranlar giriş görünümüne döner). M17 kurulum kimliği
/// (`anon_install_id`) ve dil tercihi SİLİNMEZ — deneme hakkı sıfırlanmasın.
final localAccountCleanupProvider = Provider<LocalAccountCleanup>((ref) {
  return LocalAccountCleanup([
    // favorites, view_history, scan_history, collections, collection_items +
    // önbellek tabloları (variants, images, download_queue)
    CleanupStep('database', () => ref.read(offlineDatabaseProvider).clearAll()),
    CleanupStep('files', () async => deleteUserFiles(await getApplicationDocumentsDirectory())),
    // RevenueCat'ten çıkış (Purchases.logOut; hata yutulur) + Pro durumu sıfırlanır
    CleanupStep('purchases', () => ref.read(subscriptionProvider.notifier).logoutUser()),
    CleanupStep('preferences', () => clearUserPreferences(ref.read(sharedPreferencesProvider))),
    // Yalnız yerel oturum: tarayıcıda Auth0 çıkış penceresi açılmaz
    CleanupStep('session', () => ref.read(authControllerProvider.notifier).signOutLocally()),
    // Bellekte tutulan eski hesabın verileri yeniden okunsun
    CleanupStep('memory', () async {
      ref.invalidate(favoritesControllerProvider);
      ref.invalidate(collectionsControllerProvider);
      ref.invalidate(assistantProvider);
      ref.invalidate(scanQuotaProvider);
      ref.invalidate(autoSyncFavoritesProvider);
      ref.invalidate(recognitionConfidenceThresholdProvider);
      ref.invalidate(recognitionTopKProvider);
      ref.invalidate(recognitionFilterRegionProvider);
      ref.invalidate(recognitionFilterMaterialProvider);
    }),
  ]);
});

// ---------------------------------------------------------------------------
// Silme akışı
// ---------------------------------------------------------------------------

/// Sunucuda hesabı siler; başarılıysa bu cihazı da temizler ve oturumu kapatır.
/// Başarısızlıkta hiçbir yerel veri silinmez.
class AccountDeletionService {
  AccountDeletionService(this._api, this._cleanup);

  final AccountDeletionApi _api;
  final LocalAccountCleanup _cleanup;

  Future<AccountDeletionResult> deleteAccount() async {
    final result = await _api.deleteAccount();
    if (!result.isDeleted) {
      appLog('ACCOUNT', 'delete failed: ${result.status.name}');
      return result;
    }
    final failed = await _cleanup.run();
    if (failed.isNotEmpty) appLog('ACCOUNT', 'local cleanup failed: ${failed.join(', ')}');
    return result;
  }
}

final accountDeletionServiceProvider = Provider<AccountDeletionService>(
  (ref) => AccountDeletionService(
    ref.watch(accountDeletionApiProvider),
    ref.watch(localAccountCleanupProvider),
  ),
);
