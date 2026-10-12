// E-postası doğrulanmamış yeni hesap (2026-10-11, Play +21'de bildirildi).
//
// Sunucu (AuthHelper, `require_email_verified`) eşleşen Joomla hesabı yoksa
// doğrulanmamış e-postayla yenisini açmaz, her isteğe 401 döner. Eski istemci
// kayıttan sonra oturumu kaydediyor, ilk API çağrısında kullanıcıyı sessizce
// dışarı atıyordu. Burada istemcinin kararları sınanır: claim okuma ve
// "e-postanı doğrula" kodunun kayıt/giriş akışına doğru taşınması.
//
// A23 (2026-10-12): doğrulama iletisi gelmezse "Yeniden gönder" düğmesi —
// sunucu yanıtının ayrıştırılması, geri sayım ve iki ekrandaki yeri.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';
import 'package:anatolian_coins/src/auth/resend_verification.dart';
import 'package:anatolian_coins/src/features/auth/login_screen.dart';
import 'package:anatolian_coins/src/features/auth/register_screen.dart';
import 'package:anatolian_coins/src/features/auth/resend_verification_button.dart';
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

  /// resendVerificationEmail'in döneceği sonuç / fırlatacağı l10n anahtarı.
  ResendVerificationResult resendResult =
      const ResendVerificationResult(ResendVerificationStatus.sent, retryAfterSeconds: 60);
  String? resendError;
  final resendCalls = <String>[];

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
  Future<ResendVerificationResult> resendVerificationEmail(String email, String password) async {
    resendCalls.add('$email|$password');
    if (resendError != null) throw AuthException(resendError!);
    return resendResult;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Test fontu (Ahem) her harfi tam kare çizer; formdaki "Zaten hesabınız
/// var mı?" satırı dar ekranda taşar. 720 dp genişlik bu yapay taşmayı önler.
void _wideView(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 1.5;
  addTearDown(tester.view.reset);
}

Future<void> _pumpApp(WidgetTester tester, _FakeRepo repo, String initial) async {
  final router = GoRouter(initialLocation: initial, routes: [
    GoRoute(path: '/', builder: (_, __) => const Text('ana-sayfa')),
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
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
}

final _resendButton = find.descendant(
  of: find.byType(ResendVerificationButton),
  matching: find.byWidgetPredicate((w) => w is OutlinedButton),
);

bool _resendEnabled(WidgetTester tester) =>
    tester.widget<OutlinedButton>(_resendButton).onPressed != null;

const _resendLabel = 'Doğrulama e-postasını yeniden gönder';

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

    test('A23: yeniden gönderim oturum açmaz; şifre hatası l10n anahtarı olarak döner', () async {
      final ok = await controller.resendVerificationEmail('a@b.c', 'Gizli123!');
      expect(ok.status, ResendVerificationStatus.sent);
      expect(controller.state.authenticated, isFalse);

      repo.resendError = 'login_invalid_credentials';
      final bad = await controller.resendVerificationEmail('a@b.c', 'yanlis');
      expect(bad.status, ResendVerificationStatus.failed);
      expect(bad.errorKey, 'login_invalid_credentials');
    });
  });

  group('ResendVerificationResult.fromResponse', () {
    test('200 sent → gönderildi, sunucunun bekleme süresi', () {
      final r = ResendVerificationResult.fromResponse(200, '{"sent":true,"retry_after":45}');
      expect(r.status, ResendVerificationStatus.sent);
      expect(r.retryAfterSeconds, 45);
    });

    test('200 sent, süre yoksa 60 sn', () {
      final r = ResendVerificationResult.fromResponse(200, '{"sent":true}');
      expect(r.status, ResendVerificationStatus.sent);
      expect(r.retryAfterSeconds, 60);
    });

    test('200 ALREADY_VERIFIED → zaten doğrulanmış', () {
      final r = ResendVerificationResult.fromResponse(
          200, '{"sent":false,"code":"ALREADY_VERIFIED"}');
      expect(r.status, ResendVerificationStatus.alreadyVerified);
    });

    test('429 → sınır; süre gövdeden, yoksa başlıktan, o da yoksa 60', () {
      const body = '{"errors":[{"title":"Too Many Requests","code":429,'
          '"error_code":"RESEND_RATE_LIMITED","retry_after":42}]}';
      final r = ResendVerificationResult.fromResponse(429, body);
      expect(r.status, ResendVerificationStatus.rateLimited);
      expect(r.retryAfterSeconds, 42);
      expect(ResendVerificationResult.fromResponse(429, '', retryAfterHeader: '30')
          .retryAfterSeconds, 30);
      expect(ResendVerificationResult.fromResponse(429, '{}').retryAfterSeconds, 60);
    });

    test('400 / 401 / 502 / 503 / bozuk gövde → başarısız', () {
      for (final code in [400, 401, 502, 503]) {
        expect(
            ResendVerificationResult.fromResponse(code, '{"errors":[{"code":$code}]}').status,
            ResendVerificationStatus.failed,
            reason: '$code');
      }
      expect(ResendVerificationResult.fromResponse(200, '<html>').status,
          ResendVerificationStatus.failed);
      expect(ResendVerificationResult.fromResponse(200, '{"sent":false}').status,
          ResendVerificationStatus.failed);
    });
  });

  group('RegisterScreen doğrulama paneli', () {
    Future<_FakeRepo> pump(WidgetTester tester) async {
      _wideView(tester);
      final repo = _FakeRepo()..signInError = 'login_email_not_verified';
      await _pumpApp(tester, repo, '/register');

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
      expect(find.text(_resendLabel), findsOneWidget);
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
      expect(find.text('Hesabınıza giriş yapın'), findsOneWidget);
    });

    testWidgets('A23: yeniden gönder → bilgi + 60 sn geri sayım, sonra yeniden açık', (tester) async {
      final repo = await pump(tester);
      expect(_resendEnabled(tester), isTrue);

      await tester.tap(find.text(_resendLabel));
      await tester.pump();
      await tester.pump();

      expect(repo.resendCalls, ['yeni@ornek.com|Gizli123!']);
      expect(find.textContaining('yeniden gönderdik'), findsOneWidget);
      expect(find.text('Yeniden gönder (60 sn)'), findsOneWidget);
      expect(_resendEnabled(tester), isFalse);

      await tester.pump(const Duration(seconds: 59));
      expect(find.text('Yeniden gönder (1 sn)'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_resendLabel), findsOneWidget);
      expect(_resendEnabled(tester), isTrue);
    });

    testWidgets('A23: kısa bekleme (dakikada 1) geri sayıma döner', (tester) async {
      final repo = await pump(tester);
      repo.resendResult = const ResendVerificationResult(
          ResendVerificationStatus.rateLimited, retryAfterSeconds: 20);

      await tester.tap(find.text(_resendLabel));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Az önce gönderdik'), findsOneWidget);
      expect(find.text('Yeniden gönder (20 sn)'), findsOneWidget);
      await tester.pump(const Duration(seconds: 20));
      expect(_resendEnabled(tester), isTrue);
    });

    testWidgets('A23: günlük tavan dolduysa mesaj ve düğme kapalı kalır', (tester) async {
      final repo = await pump(tester);
      repo.resendResult = const ResendVerificationResult(
          ResendVerificationStatus.rateLimited, retryAfterSeconds: 50000);

      await tester.tap(find.text(_resendLabel));
      await tester.pumpAndSettle();

      expect(find.textContaining('Gönderim sınırına ulaşıldı'), findsOneWidget);
      expect(_resendEnabled(tester), isFalse);
    });

    testWidgets('A23: e-posta bu arada doğrulanmışsa giriş daveti', (tester) async {
      final repo = await pump(tester);
      repo.resendResult =
          const ResendVerificationResult(ResendVerificationStatus.alreadyVerified);

      await tester.tap(find.text(_resendLabel));
      await tester.pumpAndSettle();

      expect(find.textContaining('Artık giriş yapabilirsiniz'), findsOneWidget);
      expect(_resendEnabled(tester), isTrue);
    });
  });

  group('LoginScreen — doğrulanmamış e-posta', () {
    Future<_FakeRepo> login(WidgetTester tester, String? error) async {
      _wideView(tester);
      final repo = _FakeRepo()..signInError = error;
      await _pumpApp(tester, repo, '/login');
      final fields = find.byType(TextFormField);
      await tester.enterText(fields.at(0), 'eski@ornek.com');
      await tester.enterText(fields.at(1), 'Gizli123!');
      await tester.tap(find.text('Giriş Yap'));
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('A23: hata mesajının altında yeniden gönder düğmesi', (tester) async {
      final repo = await login(tester, 'login_email_not_verified');
      expect(find.textContaining('henüz doğrulanmadı'), findsOneWidget);
      expect(find.byType(ResendVerificationButton), findsOneWidget);

      await tester.tap(find.text(_resendLabel));
      await tester.pump();
      await tester.pump();
      expect(repo.resendCalls, ['eski@ornek.com|Gizli123!']);
      expect(find.text('Yeniden gönder (60 sn)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('başka bir giriş hatasında düğme yok', (tester) async {
      await login(tester, 'login_invalid_credentials');
      expect(find.byType(ResendVerificationButton), findsNothing);
    });
  });
}
