// M2 regresyonu: kota hesap ve abonelik değişince yeniden çekilmeli.
//
// Gerçek scanQuotaProvider + subscriptionProvider + AuthController; kimlik
// deposu, mağaza ve kota uç noktası sahte.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:anatolian_coins/src/auth/auth_controller.dart';
import 'package:anatolian_coins/src/auth/auth_repository.dart';
import 'package:anatolian_coins/src/core/api_client.dart';
import 'package:anatolian_coins/src/core/revenuecat_service.dart';
import 'package:anatolian_coins/src/core/subscription_provider.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';

AuthTokens _tokens(String sub) =>
    AuthTokens(accessToken: 'tok-$sub', email: '$sub@x', sub: sub);

class _FakeRepo implements AuthRepository {
  AuthTokens? tokens;
  _FakeRepo(this.tokens);

  @override
  Future<AuthTokens?> load() async => tokens;

  @override
  Future<AuthTokens?> ensureFresh(AuthTokens? current, {bool force = false}) async =>
      current;

  @override
  Future<void> signOut() async => tokens = null;

  @override
  Future<AuthTokens?> signInWithPassword(String email, String password) async =>
      tokens = _tokens(email);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Sunucu tarafı: "pro-user" Joomla grubunda Pro, diğerleri 3/10.
class _FakeRecognition implements RecognitionService {
  final _FakeRepo repo;
  int calls = 0;
  _FakeRecognition(this.repo);

  @override
  Future<ScanQuota> getQuota() async {
    calls++;
    final pro = repo.tokens?.sub == 'pro-user';
    return ScanQuota(
      used: pro ? 0 : 3,
      limit: pro ? -1 : 10,
      remaining: pro ? -1 : 7,
      isPro: pro,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeRevenueCat implements RevenueCatService {
  int logoutCalls = 0;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> login(String userId) async {}

  @override
  Future<void> logout() async => logoutCalls++;

  @override
  Future<CustomerInfo?> getCustomerInfo() async => null;

  @override
  void addCustomerInfoListener(void Function(CustomerInfo) listener) {}

  @override
  void removeCustomerInfoListener(void Function(CustomerInfo) listener) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Backend abonelik çağrısı hata verir; controller bunu "Pro değil" sayar.
class _FakeApi implements ApiClient {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  late _FakeRepo repo;
  late _FakeRecognition recognition;
  late _FakeRevenueCat rc;
  late ProviderContainer container;

  setUp(() async {
    repo = _FakeRepo(_tokens('pro-user'));
    recognition = _FakeRecognition(repo);
    rc = _FakeRevenueCat();
    container = ProviderContainer(overrides: [
      authControllerProvider.overrideWith((ref) => AuthController(repo)),
      recognitionServiceProvider.overrideWithValue(recognition),
      revenueCatServiceProvider.overrideWithValue(rc),
      apiClientProvider.overrideWithValue(_FakeApi()),
    ]);
    container.listen(scanQuotaProvider, (_, __) {});
    await _settle();
  });

  tearDown(() => container.dispose());

  test('başka hesapla girince önceki hesabın Pro kotası kalmaz', () async {
    expect((await container.read(scanQuotaProvider.future)).isPro, isTrue);

    final auth = container.read(authControllerProvider.notifier);
    await auth.signOut();
    await auth.signInWithPassword('free-user', 'pw');
    await _settle();

    final quota = await container.read(scanQuotaProvider.future);
    expect(quota.isPro, isFalse);
    expect(quota.remaining, 7);
  });

  test('abonelik Pro olunca kota yeniden çekilir', () async {
    await container.read(scanQuotaProvider.future);
    final before = recognition.calls;

    container.read(subscriptionProvider.notifier).activateProForTesting();
    await container.read(scanQuotaProvider.future);

    expect(recognition.calls, before + 1);
  });

  test('kimlik bağlanmamış olsa da çıkış durumu sıfırlar', () async {
    final controller = SubscriptionController(rc, _FakeApi());
    await _settle();
    controller.activateProForTesting();

    await controller.logoutUser();

    expect(controller.state.isPro, isFalse);
    expect(rc.logoutCalls, 1);
    controller.dispose();
  });
}
