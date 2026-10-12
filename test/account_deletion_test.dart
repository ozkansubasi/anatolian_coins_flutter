// App Store 5.1.1(v) — hesabı uygulama içinden silme (Hesabım → Hesabımı Sil).
//
// Sunucu sözleşmesi (eklenti 1.20.0): POST /v1/user/delete, gövde {"confirm":true};
// hata kodu errors[0].error_code'da. Burada: yanıtın sonuca eşlenmesi (sahte Dio),
// onay kelimesi normalizasyonu, mağaza eşlemesi, yerel temizlik adımları ve
// oturumun yalnız yerelde kapanması (M17 kurulum kimliği ve dil kalır).

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';
import 'package:anatolian_coins/src/core/install_id.dart';
import 'package:anatolian_coins/src/features/account/account_deletion_api.dart';
import 'package:anatolian_coins/src/features/account/account_deletion_service.dart';
import 'package:anatolian_coins/src/features/settings/settings_provider.dart';

/// Tek yanıt döndüren sahte HTTP katmanı; gelen isteği saklar.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.status, this.body, {this.headers = const {}, this.offline = false});

  final int status;
  final String body;
  final Map<String, List<String>> headers;
  final bool offline;
  RequestOptions? request;

  @override
  Future<ResponseBody> fetch(
      RequestOptions options, Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    request = options;
    if (offline) {
      throw DioException.connectionError(requestOptions: options, reason: 'offline');
    }
    return ResponseBody.fromString(body, status, headers: {
      Headers.contentTypeHeader: ['application/json; charset=utf-8'],
      ...headers,
    });
  }

  @override
  void close({bool force = false}) {}
}

/// ApiClient gibi: düz metin yanıt, temel adres /v1.
Future<(AccountDeletionResult, _FakeAdapter)> _call(int status, String body,
    {Map<String, List<String>> headers = const {}, bool offline = false}) async {
  final adapter = _FakeAdapter(status, body, headers: headers, offline: offline);
  final dio = Dio(BaseOptions(
    baseUrl: 'https://www.numistr.org/api/index.php/v1',
    responseType: ResponseType.plain,
  ))
    ..httpClientAdapter = adapter;
  return (await AccountDeletionApi(dio).deleteAccount(), adapter);
}

String _error(int code, String errorCode, {int? retryAfter}) => jsonEncode({
      'errors': [
        {
          'title': 'x',
          'code': code,
          'error_code': errorCode,
          if (retryAfter != null) 'retry_after': retryAfter,
        }
      ]
    });

class _FakeApi extends AccountDeletionApi {
  _FakeApi(this.result) : super(Dio());

  final AccountDeletionResult result;
  int calls = 0;

  @override
  Future<AccountDeletionResult> deleteAccount() async {
    calls++;
    return result;
  }
}

void main() {
  group('AccountDeletionApi (sahte Dio)', () {
    test('istek: POST /user/delete, gövde {"confirm":true}', () async {
      final (_, adapter) = await _call(200, '{"data":{"deleted":true}}');
      final r = adapter.request!;
      expect(r.method, 'POST');
      expect(r.uri.toString(), 'https://www.numistr.org/api/index.php/v1/user/delete');
      expect(r.data, {'confirm': true});
      expect(r.contentType, startsWith('application/json'));
    });

    test('200 → silindi; sayılar ve web aboneliği iptali okunur', () async {
      final (result, _) = await _call(200,
          '{"data":{"deleted":true,"auth0_users_deleted":2,"web_subscription_canceled":true}}');
      expect(result.status, AccountDeletionStatus.deleted);
      expect(result.isDeleted, isTrue);
      expect(result.auth0UsersDeleted, 2);
      expect(result.webSubscriptionCanceled, isTrue);
      expect(result.errorKey, isNull);
    });

    test('200, web aboneliği yok (null)', () async {
      final (result, _) = await _call(
          200, '{"data":{"deleted":true,"auth0_users_deleted":1,"web_subscription_canceled":null}}');
      expect(result.isDeleted, isTrue);
      expect(result.webSubscriptionCanceled, isNull);
    });

    test('502 AUTH0_DELETE_FAILED → hiçbir şey silinmedi, tekrar denenebilir', () async {
      final (result, _) = await _call(502, _error(502, 'AUTH0_DELETE_FAILED'));
      expect(result.status, AccountDeletionStatus.auth0Failed);
      expect(result.isDeleted, isFalse);
      expect(result.errorKey, 'delete_account_error_retry');
    });

    test('429 RATE_LIMITED → süre gövdeden, dakikaya yukarı yuvarlanır', () async {
      final (result, _) = await _call(429, _error(429, 'RATE_LIMITED', retryAfter: 150));
      expect(result.status, AccountDeletionStatus.rateLimited);
      expect(result.retryAfterSeconds, 150);
      expect(result.errorKey, 'delete_account_error_rate_limited');
      expect(result.errorParams, {'minutes': '3'});
    });

    test('429 → gövdede süre yoksa Retry-After başlığı, o da yoksa 60 sn', () async {
      final (fromHeader, _) = await _call(429, _error(429, 'RATE_LIMITED'), headers: {
        'retry-after': ['30'],
      });
      expect(fromHeader.retryAfterSeconds, 30);
      expect(fromHeader.errorParams, {'minutes': '1'});

      final (fallback, _) = await _call(429, '');
      expect(fallback.status, AccountDeletionStatus.rateLimited);
      expect(fallback.retryAfterSeconds, 60);
    });

    test('diğer hata kodları', () async {
      final cases = {
        _error(400, 'CONFIRM_REQUIRED'): (400, AccountDeletionStatus.confirmRequired),
        _error(401, 'UNAUTHORIZED'): (401, AccountDeletionStatus.unauthorized),
        _error(403, 'ACCOUNT_PROTECTED'): (403, AccountDeletionStatus.protected),
        _error(503, 'DELETE_UNAVAILABLE'): (503, AccountDeletionStatus.unavailable),
        _error(500, 'DELETE_FAILED'): (500, AccountDeletionStatus.failed),
      };
      for (final entry in cases.entries) {
        final (code, expected) = entry.value;
        final (result, _) = await _call(code, entry.key);
        expect(result.status, expected, reason: entry.key);
        expect(result.errorKey, isNotNull);
      }
    });

    test('kodsuz yanıtlar HTTP durumuna göre', () async {
      expect((await _call(401, '{"errors":[{"code":401}]}')).$1.status,
          AccountDeletionStatus.unauthorized);
      // Uç henüz yok (eklenti 1.20.0 öncesi)
      expect((await _call(404, 'Not found')).$1.status, AccountDeletionStatus.unavailable);
      // Kodsuz 502 barındırma katmanından gelebilir: "hiçbir şey silinmedi" denmez
      expect((await _call(502, '<html>')).$1.status, AccountDeletionStatus.failed);
      // 2xx ama "silindi" yok
      expect((await _call(200, '{"data":{}}')).$1.status, AccountDeletionStatus.failed);
    });

    test('bağlantı yok → network', () async {
      final (result, _) = await _call(0, '', offline: true);
      expect(result.status, AccountDeletionStatus.network);
      expect(result.errorKey, 'delete_account_error_network');
    });

    test('ApiClient JSON\'u çözmüşse (Map gövde) de okunur', () {
      final r = AccountDeletionResult.fromResponse(200, {
        'data': {'deleted': true, 'auth0_users_deleted': 1},
      });
      expect(r.isDeleted, isTrue);
      expect(r.auth0UsersDeleted, 1);
    });
  });

  group('onay kelimesi', () {
    test('TR "SİL": büyük/küçük harf ve Türkçe i/İ/ı farkı gözetilmez', () {
      for (final input in ['SİL', 'sil', 'Sil', 'SIL', ' sil ', 'sİl']) {
        expect(confirmWordMatches(input, 'SİL'), isTrue, reason: input);
      }
      for (final input in ['', 'si', 'sill', 'DELETE']) {
        expect(confirmWordMatches(input, 'SİL'), isFalse, reason: input);
      }
    });

    test('EN "DELETE"', () {
      expect(confirmWordMatches('delete', 'DELETE'), isTrue);
      expect(confirmWordMatches('Delete', 'DELETE'), isTrue);
      expect(confirmWordMatches('delet', 'DELETE'), isFalse);
    });

    test('boş kelimeyle eşleşme olmaz', () {
      expect(confirmWordMatches('', ''), isFalse);
    });
  });

  group('mağaza aboneliği', () {
    test('yetkinin mağazası → yönlendirilecek mağaza', () {
      expect(managedStoreOf(Store.appStore), ManagedStore.appStore);
      expect(managedStoreOf(Store.macAppStore), ManagedStore.appStore);
      expect(managedStoreOf(Store.playStore), ManagedStore.playStore);
      // Promosyon ücretlendirilmez; diğerlerini biz kullanmıyoruz
      expect(managedStoreOf(Store.promotional), isNull);
      expect(managedStoreOf(Store.stripe), isNull);
    });

    test('aboneliği yönetme adresleri', () {
      expect(manageSubscriptionUrl(ManagedStore.appStore).toString(),
          'https://apps.apple.com/account/subscriptions');
      expect(manageSubscriptionUrl(ManagedStore.playStore).toString(),
          'https://play.google.com/store/account/subscriptions?package=com.anatoliancoins.app');
    });
  });

  group('yerel temizlik', () {
    test('adımlar sırayla çalışır; biri hata verse de diğerleri yapılır', () async {
      final calls = <String>[];
      final cleanup = LocalAccountCleanup([
        CleanupStep('a', () async => calls.add('a')),
        CleanupStep('b', () async => throw StateError('kilitli')),
        CleanupStep('session', () async => calls.add('session')),
      ]);
      final failed = await cleanup.run();
      expect(calls, ['a', 'session']);
      expect(failed, ['b']);
    });

    test('çevrimdışı ve tarama görselleri silinir, başka dosyalar kalır', () async {
      final docs = await Directory.systemTemp.createTemp('numistr_docs_');
      addTearDown(() => docs.delete(recursive: true));
      File(p.join(docs.path, 'offline_images', '12', '34.jpg')).createSync(recursive: true);
      File(p.join(docs.path, 'scan_images', '1_obv.jpg')).createSync(recursive: true);
      final db = File(p.join(docs.path, 'anatolian_coins_offline.db'))..createSync();
      final other = File(p.join(docs.path, 'other.txt'))..createSync();

      await deleteUserFiles(docs);
      // Klasör yoksa da hata vermez
      await deleteUserFiles(docs);

      expect(Directory(p.join(docs.path, 'offline_images')).existsSync(), isFalse);
      expect(Directory(p.join(docs.path, 'scan_images')).existsSync(), isFalse);
      expect(db.existsSync(), isTrue); // tablolar SQL ile boşaltılır
      expect(other.existsSync(), isTrue);
    });

    test('hesaba bağlı tercihler silinir, tema kalır', () async {
      SharedPreferences.setMockInitialValues({
        SettingsKeys.themeMode: 'dark',
        SettingsKeys.autoSyncFavorites: false,
        SettingsKeys.recognitionFilterRegion: 'lydia-coins',
        SettingsKeys.recognitionTopK: 10,
      });
      final prefs = await SharedPreferences.getInstance();
      await clearUserPreferences(prefs);
      expect(prefs.getString(SettingsKeys.themeMode), 'dark');
      for (final key in SettingsKeys.userScoped) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
    });

    test('oturum yalnız yerelde kapanır; kurulum kimliği ve dil SİLİNMEZ', () async {
      const installId = '3f2b8c1e-7a4d-4e9f-9b2a-1c5d6e7f8a9b';
      FlutterSecureStorage.setMockInitialValues({
        'auth_tokens': jsonEncode(
            AuthTokens(accessToken: 'tok', email: 'a@b.c', sub: 'apple|001').toJson()),
        InstallId.storageKey: installId,
        'app_locale': 'en',
      });
      final controller = AuthController(AuthRepository());
      addTearDown(controller.dispose);
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(controller.state.authenticated, isTrue);
      expect(controller.state.isAppleAccount, isTrue);

      await controller.signOutLocally();

      expect(controller.state.authenticated, isFalse);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: 'auth_tokens'), isNull);
      expect(await storage.read(key: InstallId.storageKey), installId);
      expect(await storage.read(key: 'app_locale'), 'en');
    });
  });

  group('AccountDeletionService', () {
    test('başarıda yerel temizlik çalışır', () async {
      var cleaned = 0;
      final api = _FakeApi(const AccountDeletionResult(AccountDeletionStatus.deleted));
      final service = AccountDeletionService(
          api, LocalAccountCleanup([CleanupStep('x', () async => cleaned++)]));
      final result = await service.deleteAccount();
      expect(result.isDeleted, isTrue);
      expect(api.calls, 1);
      expect(cleaned, 1);
    });

    test('başarısızlıkta (502) hiçbir yerel veri silinmez', () async {
      var cleaned = 0;
      final service = AccountDeletionService(
          _FakeApi(const AccountDeletionResult(AccountDeletionStatus.auth0Failed)),
          LocalAccountCleanup([CleanupStep('x', () async => cleaned++)]));
      final result = await service.deleteAccount();
      expect(result.status, AccountDeletionStatus.auth0Failed);
      expect(cleaned, 0);
    });
  });

  for (final lang in ['tr', 'en']) {
    test('$lang: gizlilik metni uygulama içi silme yolunu arayüz etiketleriyle anar, Apple\'ı sayar',
        () {
      final t = (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map)
          .cast<String, String>();
      // "Hesabım → Hesabımı Sil" / "My Account → Delete My Account"
      expect(t['pp_rights_application_content'],
          contains('${t['account_title']} → ${t['delete_account']}'));
      expect(t['pp_identity_data_content'], contains('Apple'));
      expect(t['pp_transfer_technical'], contains('Apple (App Store'));
      expect(t['kvkk_transfer_1'], contains('Apple (App Store'));
    });
  }

  test('Apple hesabı Auth0 sub önekinden anlaşılır', () {
    expect(const AuthState(loading: false, authenticated: true, userId: 'apple|001')
        .isAppleAccount, isTrue);
    expect(const AuthState(loading: false, authenticated: true, userId: 'google-oauth2|1')
        .isAppleAccount, isFalse);
    expect(const AuthState(loading: false, authenticated: false).isAppleAccount, isFalse);
  });
}
