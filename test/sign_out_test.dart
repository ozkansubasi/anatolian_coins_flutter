// M29 (2026-10-17) — çıkış tarayıcı açmaz: yenileme belirteci Auth0'da iptal edilir,
// yerel belirteçler her durumda silinir.
//
// Eski yol (`endSession` / `/v2/logout`) iOS ve macOS'ta "…giriş yapmak için auth0.com'u
// kullanmak istiyor" sistem onayını ve Auth0'nun adı boş çıkış sayfasını açıyordu;
// kullanıcı çıkış için 3 kez onaylıyordu (TestFlight Mac denemesi). Girişler tarayıcıda
// kalıcı oturum bırakmadığından kapatılacak bir şey de yoktu.

import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/auth/auth_repository.dart';

/// Tarayıcı / sistem oturumu açılırsa test düşer.
class _NoBrowserAppAuth extends FlutterAppAuth {
  @override
  Future<EndSessionResponse> endSession(EndSessionRequest request) =>
      throw StateError('çıkışta tarayıcı açılmamalı');
}

Dio _dio(List<RequestOptions> seen, {bool fail = false}) {
  final dio = Dio();
  dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
    seen.add(o);
    if (fail) {
      h.reject(DioException(requestOptions: o, type: DioExceptionType.connectionError));
    } else {
      h.resolve(Response(requestOptions: o, statusCode: 200));
    }
  }));
  return dio;
}

AuthTokens _tokens({String? refresh = 'yenileme-1'}) => AuthTokens(
      accessToken: 'erisim',
      refreshToken: refresh,
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
      email: 'a@b.c',
      sub: 'auth0|x',
      idToken: 'id',
    );

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));

  test('yenileme belirteci /oauth/revoke ile iptal edilir, yerel oturum silinir', () async {
    final seen = <RequestOptions>[];
    final repo = AuthRepository(appAuth: _NoBrowserAppAuth(), httpClient: _dio(seen));
    await repo.save(_tokens());

    await repo.signOut();

    expect(seen, hasLength(1));
    expect(seen.single.method, 'POST');
    expect(seen.single.uri.path, '/oauth/revoke');
    expect((seen.single.data as Map)['token'], 'yenileme-1');
    expect((seen.single.data as Map)['client_id'], isNotEmpty);
    expect(await repo.load(), isNull);
  });

  test('iptal başarısız olsa da (ağ yok) yerel oturum silinir', () async {
    final seen = <RequestOptions>[];
    final repo = AuthRepository(appAuth: _NoBrowserAppAuth(), httpClient: _dio(seen, fail: true));
    await repo.save(_tokens());

    await repo.signOut();

    expect(seen, hasLength(1));
    expect(await repo.load(), isNull);
  });

  test('yenileme belirteci yoksa istek atılmaz, yerel oturum silinir', () async {
    final seen = <RequestOptions>[];
    final repo = AuthRepository(appAuth: _NoBrowserAppAuth(), httpClient: _dio(seen));
    await repo.save(_tokens(refresh: null));

    await repo.signOut();

    expect(seen, isEmpty);
    expect(await repo.load(), isNull);
  });
}
