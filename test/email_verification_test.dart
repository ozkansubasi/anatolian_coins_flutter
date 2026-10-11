// E-postası doğrulanmamış yeni hesap (2026-10-11, Play +21'de bildirildi).
//
// Sunucu (AuthHelper, `require_email_verified`) eşleşen Joomla hesabı yoksa
// doğrulanmamış e-postayla yenisini açmaz, her isteğe 401 döner. Eski istemci
// kayıttan sonra oturumu kaydediyor, ilk API çağrısında kullanıcıyı sessizce
// dışarı atıyordu. Burada istemcinin kararları sınanır: claim okuma ve
// "e-postanı doğrula" kodunun kayıt/giriş akışına doğru taşınması.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';
import 'package:anatolian_coins/src/features/auth/register_screen.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.sig';
}

class _FakeRepo implements AuthRepository {
  /// signInWithPassword'ün fırlatacağı l10n anahtarı (null = başarılı giriş).
  String? signInError;
  int signUps = 0;

  @override
  Future<AuthTokens?> load() async => null;

  @override
  Future<AuthTokens?> ensureFresh(AuthTokens? current, {bool force = false}) async =>
      current;

  @override
  Future<void> signUp(String email, String password) async => signUps++;

  @override
  Future<AuthTokens?> signInWithPassword(String email, String password) async {
    if (signInError != null) throw AuthException(signInError!);
    return AuthTokens(accessToken: 'tok', email: email, sub: 'auth0|x');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AuthTokens.isEmailUnverified', () {
    test('email_verified=false → doğrulanmamış', () {
      expect(AuthTokens.isEmailUnverified(_jwt({'email_verified': false})), isTrue);
    });

    test('email_verified=true → doğrulanmış', () {
      expect(AuthTokens.isEmailUnverified(_jwt({'email_verified': true})), isFalse);
    });

    test('claim yoksa ya da belirteç bozuksa giriş engellenmez', () {
      expect(AuthTokens.isEmailUnverified(_jwt({'sub': 'auth0|x'})), isFalse);
      expect(AuthTokens.isEmailUnverified('bozuk'), isFalse);
    });
  });

  group('AuthController', () {
    late _FakeRepo repo;
    late AuthController controller;

    setUp(() async {
      repo = _FakeRepo();
      controller = AuthController(repo);
      await Future<void>.delayed(Duration.zero); // _init
    });

    tearDown(() => controller.dispose());

    test('kayıt sonrası e-posta doğrulanmamışsa doğrulama paneli kodu döner', () async {
      repo.signInError = 'login_email_not_verified';
      final code = await controller.signUpWithPassword('a@b.c', 'Gizli123!');
      expect(code, AuthController.signupVerifyEmail);
      expect(repo.signUps, 1);
      expect(controller.state.authenticated, isFalse);
      expect(controller.state.loading, isFalse);
    });

    test('kayıt sonrası başka bir giriş hatası eski mesaja düşer', () async {
      repo.signInError = 'login_failed';
      final code = await controller.signUpWithPassword('a@b.c', 'Gizli123!');
      expect(code, 'signup_login_failed');
    });

    test('giriş ekranı doğrulanmamış e-posta anahtarını alır, oturum açılmaz', () async {
      repo.signInError = 'login_email_not_verified';
      final code = await controller.signInWithPassword('a@b.c', 'Gizli123!');
      expect(code, 'login_email_not_verified');
      expect(controller.state.authenticated, isFalse);
    });

    test('doğrulandıktan sonra aynı bilgilerle giriş başarılı', () async {
      final code = await controller.signInWithPassword('a@b.c', 'Gizli123!');
      expect(code, isNull);
      expect(controller.state.authenticated, isTrue);
    });
  });

  group('RegisterScreen doğrulama paneli', () {
    Future<_FakeRepo> pump(WidgetTester tester) async {
      // Test fontu (Ahem) her harfi tam kare çizer; formdaki "Zaten hesabınız
      // var mı?" satırı dar ekranda taşar. 720 dp genişlik bu yapay taşmayı önler.
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 1.5;
      addTearDown(tester.view.reset);

      final repo = _FakeRepo()..signInError = 'login_email_not_verified';
      final router = GoRouter(initialLocation: '/register', routes: [
        GoRoute(path: '/', builder: (_, __) => const Text('ana-sayfa')),
        GoRoute(path: '/login', builder: (_, __) => const Text('giris-ekrani')),
        GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      ]);
      await tester.pumpWidget(ProviderScope(
        overrides: [authControllerProvider.overrideWith((ref) => AuthController(repo))],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('tr'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('en'), Locale('tr')],
        ),
      ));
      await tester.pumpAndSettle();

      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'yeni@ornek.com');
      await tester.enterText(fields.at(1), 'Gizli123!');
      await tester.enterText(fields.at(2), 'Gizli123!');
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('kayıttan sonra form yerine panel; e-posta adresi metinde', (tester) async {
      await pump(tester);
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('E-postanızı doğrulayın'), findsOneWidget);
      expect(find.textContaining('yeni@ornek.com'), findsOneWidget);
      expect(find.text('Doğruladım, giriş yap'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('henüz doğrulanmadıysa uyarı, doğrulanınca ana sayfa', (tester) async {
      final repo = await pump(tester);

      await tester.tap(find.text('Doğruladım, giriş yap'));
      await tester.pumpAndSettle();
      expect(find.textContaining('henüz doğrulanmamış görünüyor'), findsOneWidget);

      repo.signInError = null;
      await tester.tap(find.text('Doğruladım, giriş yap'));
      await tester.pumpAndSettle();
      expect(find.text('ana-sayfa'), findsOneWidget);
    });

    testWidgets('giriş ekranına dön', (tester) async {
      await pump(tester);
      await tester.tap(find.text('Giriş ekranına dön'));
      await tester.pumpAndSettle();
      expect(find.text('giris-ekrani'), findsOneWidget);
    });
  });
}
