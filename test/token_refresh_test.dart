// "Editör'den" kartı iskelette kalıyordu (10 + 12 Eki, Play sürümü; yeniden
// başlatınca düzeliyordu, logcat'te hata yoktu).
//
// Kök neden: flutter_appauth Android eklentisi (6.0.7) aynı anda iki `token`
// çağrısında "Concurrent operations detected" hatasını İLK çağrıya teslim ediyor,
// ikinci çağrının Future'ı hiç tamamlanmıyor. Belirteç süresi dolmuşken açılışta
// ana sayfanın istekleri aynı anda yenileme istiyor; biri sonsuza kadar bekliyordu.
// Burada sahte eklenti aynı davranışı gösterir; depo yenilemeyi tek çağrıda toplamalı.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/auth/auth_repository.dart';

String _jwt(Map<String, dynamic> claims) {
  String part(Map<String, dynamic> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'RS256'})}.${part(claims)}.sig';
}

/// Eklentinin Android tarafı gibi davranır: bir `token` çağrısı sürerken ikincisi
/// gelirse hata ilk çağrıya gider, ikinci çağrı hiç yanıt almaz.
class _PluginLikeAppAuth extends FlutterAppAuth {
  int calls = 0;
  Completer<TokenResponse?>? _pending;

  @override
  Future<TokenResponse?> token(TokenRequest request) {
    calls++;
    final c = Completer<TokenResponse?>();
    final pending = _pending;
    if (pending != null) {
      _pending = null;
      pending.completeError(PlatformException(
          code: 'token_failed', message: 'Concurrent operations detected: token, token'));
      return c.future; // hiç tamamlanmaz
    }
    _pending = c;
    return c.future;
  }

  void answer() {
    final p = _pending;
    _pending = null;
    p?.complete(TokenResponse(
      'yeni-erisim',
      'yeni-yenileme',
      DateTime.now().add(const Duration(hours: 10)),
      _jwt({'sub': 'auth0|x', 'email': 'a@b.c'}),
      'Bearer',
      null,
      null,
    ));
  }

  bool get hasPending => _pending != null;
}

AuthTokens _expired() => AuthTokens(
      accessToken: 'eski',
      refreshToken: 'eski-yenileme',
      expiresAt: DateTime.now().subtract(const Duration(minutes: 5)),
      email: 'a@b.c',
      sub: 'auth0|x',
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('aynı anda gelen yenilemeler tek çağrıyı paylaşır, hiçbiri asılı kalmaz', () async {
    final appAuth = _PluginLikeAppAuth();
    final repo = AuthRepository(appAuth: appAuth);
    final current = _expired();

    // Açılış: AuthController._init + ana sayfanın üç isteği aynı anda.
    final all = Future.wait([
      for (var i = 0; i < 4; i++) repo.ensureFresh(current),
    ]);
    await Future<void>.delayed(Duration.zero);
    expect(appAuth.calls, 1);

    appAuth.answer();
    final results = await all.timeout(const Duration(seconds: 2));

    for (final t in results) {
      expect(t!.refreshToken, 'yeni-yenileme');
      expect(t.accessToken, startsWith('ey')); // ID token kullanılır
    }
  });

  test('zorunlu yenileme de süren çağrıya katılır', () async {
    final appAuth = _PluginLikeAppAuth();
    final repo = AuthRepository(appAuth: appAuth);
    final current = _expired();

    final normal = repo.ensureFresh(current);
    final forced = repo.ensureFresh(current, force: true);
    await Future<void>.delayed(Duration.zero);
    expect(appAuth.calls, 1);

    appAuth.answer();
    expect((await normal.timeout(const Duration(seconds: 2)))!.refreshToken, 'yeni-yenileme');
    expect((await forced.timeout(const Duration(seconds: 2)))!.refreshToken, 'yeni-yenileme');

    // Bitince yeni bir yenileme yeniden çağrı açar.
    final again = repo.ensureFresh(current);
    await Future<void>.delayed(Duration.zero);
    expect(appAuth.calls, 2);
    appAuth.answer();
    await again;
  });

  testWidgets('eklenti hiç yanıt vermezse 30 sn sonra eldeki belirteçle devam edilir', (tester) async {
    final appAuth = _PluginLikeAppAuth();
    final repo = AuthRepository(appAuth: appAuth);
    final current = _expired();

    AuthTokens? normal;
    AuthTokens? forced = current;
    var done = 0;
    repo.ensureFresh(current).then((t) {
      normal = t;
      done++;
    });
    repo.ensureFresh(current, force: true).then((t) {
      forced = t;
      done++;
    });

    await tester.pump(const Duration(seconds: 29));
    expect(done, 0);
    await tester.pump(const Duration(seconds: 2));
    expect(done, 2);
    expect(normal, same(current)); // normal: eldeki belirteçle devam
    expect(forced, isNull); // zorunlu: oturum ölü sayılır
  });
}
