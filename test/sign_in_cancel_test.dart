// Giriş sayfasını kapatmak (kullanıcı iptali) sessiz geçer — 2026-10-29.
//
// AppAuth iptali `null` sonuç olarak değil `PlatformException` olarak bildiriyor; depo bunu
// yeniden fırlatınca giriş ekranı "Giriş yapılamadı. Lütfen tekrar deneyin." gösteriyordu
// (iOS 27 iPad simülatöründe "Google ile devam et" → sayfayı kapat). iOS mesajı cihaz diline
// çevrilir, Android sabit İngilizce metin döner.

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';

final _iosTr = PlatformException(
  code: 'authorize_and_exchange_code_failed',
  message: 'Failed to authorize: İşlem tamamlanamadı. (org.openid.appauth.general hatası -3.)',
);
final _iosEn = PlatformException(
  code: 'authorize_and_exchange_code_failed',
  message: 'Failed to authorize: The operation couldn’t be completed. (org.openid.appauth.general error -3.)',
);
final _android = PlatformException(
  code: 'authorize_and_exchange_code_failed',
  message: 'Failed to authorize: [error: null, description: User cancelled flow]',
);
final _realError = PlatformException(
  code: 'authorize_and_exchange_code_failed',
  message: 'Failed to authorize: [error: access_denied, description: Service not found]',
);

/// Giriş sayfası açılınca verilen hatayı fırlatır (tarayıcı açılmaz).
class _ThrowingAppAuth extends FlutterAppAuth {
  const _ThrowingAppAuth(this.error);
  final Object error;

  @override
  Future<AuthorizationTokenResponse?> authorizeAndExchangeCode(
          AuthorizationTokenRequest request) =>
      Future.error(error);
}

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  group('isUserCancellation', () {
    test('iOS (Türkçe ve İngilizce cihaz) ve Android iptali tanınır', () {
      expect(AuthRepository.isUserCancellation(_iosTr), isTrue);
      expect(AuthRepository.isUserCancellation(_iosEn), isTrue);
      expect(AuthRepository.isUserCancellation(_android), isTrue);
    });

    test('gerçek hatalar iptal sayılmaz', () {
      expect(AuthRepository.isUserCancellation(_realError), isFalse);
      // -30 başka bir AppAuth kodu; -3 ile karışmaz.
      expect(
        AuthRepository.isUserCancellation(PlatformException(
          code: 'authorize_and_exchange_code_failed',
          message: 'Failed to authorize: (org.openid.appauth.general error -30.)',
        )),
        isFalse,
      );
      // Belirteç / keşif hataları iptal değildir.
      expect(
        AuthRepository.isUserCancellation(PlatformException(
          code: 'token_failed',
          message: 'Failed to get token: [error: null, description: User cancelled flow]',
        )),
        isFalse,
      );
      expect(AuthRepository.isUserCancellation(Exception('User cancelled flow')), isFalse);
    });
  });

  group('AuthRepository', () {
    for (final (name, error) in [('iOS tr', _iosTr), ('iOS en', _iosEn), ('Android', _android)]) {
      test('$name iptalinde signInWithSocial ve signIn null döner', () async {
        final repo = AuthRepository(appAuth: _ThrowingAppAuth(error));
        expect(await repo.signInWithSocial('google-oauth2'), isNull);
        expect(await repo.signIn(), isNull);
      });
    }

    test('gerçek hata yine fırlatılır', () async {
      final repo = AuthRepository(appAuth: _ThrowingAppAuth(_realError));
      await expectLater(repo.signInWithSocial('google-oauth2'), throwsA(_realError));
      await expectLater(repo.signIn(), throwsA(_realError));
    });
  });

  group('AuthController', () {
    Future<AuthController> controller(Object error) async {
      final c = AuthController(AuthRepository(appAuth: _ThrowingAppAuth(error)));
      await pumpEventQueue(); // açılıştaki _init() biter
      return c;
    }

    test('iptal: hata yok, yükleniyor biter, oturum kapalı', () async {
      final c = await controller(_iosTr);
      await c.signInWithSocial('google-oauth2');
      expect(c.state.loading, isFalse);
      expect(c.state.authenticated, isFalse);

      await c.signIn();
      expect(c.state.loading, isFalse);
      expect(c.state.authenticated, isFalse);
    });

    test('gerçek hatada signIn yükleniyor durumunu sıfırlar', () async {
      final c = await controller(_realError);
      await expectLater(c.signIn(), throwsA(_realError));
      expect(c.state.loading, isFalse);
    });
  });
}
