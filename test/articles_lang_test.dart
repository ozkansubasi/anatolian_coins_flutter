// M3 adım 5: blog istekleri arayüz dilini gönderir (plugin 1.16.0 `?lang=`).
//
// Dil gönderilmezse sunucu TR blog ağacını döner; İngilizce arayüzde Türkçe
// yazı görünmesinin nedeni buydu.

import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/api_client.dart';
import 'package:anatolian_coins/src/core/locale_provider.dart';
import 'package:anatolian_coins/src/features/articles/articles_api.dart';

/// İstekleri kaydeder, ağa çıkmadan sahte yanıt döner.
class _RecordingApi implements ApiClient {
  final requests = <RequestOptions>[];

  @override
  late final Dio dio = Dio()
    ..interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests.add(options);
      final isList = options.path == '/articles' || options.path == '/articles/categories';
      handler.resolve(Response(
        requestOptions: options,
        statusCode: 200,
        data: {
          'data': isList
              ? <dynamic>[]
              : {'id': 1, 'title': 't', 'intro': '', 'category': 'c', 'category_id': 1, 'created': '2026-09-26 00:00:00'},
        },
      ));
    }));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Depolamaya dokunmayan dil durumu.
class _FixedLocale extends StateNotifier<Locale> implements LocaleNotifier {
  _FixedLocale(super.state);

  @override
  Future<void> setLocale(Locale locale) async => state = locale;
}

void main() {
  late _RecordingApi api;
  late ProviderContainer container;

  setUp(() {
    api = _RecordingApi();
    container = ProviderContainer(overrides: [
      apiClientProvider.overrideWithValue(api),
      localeProvider.overrideWith((ref) => _FixedLocale(const Locale('en'))),
    ]);
  });

  tearDown(() => container.dispose());

  test('liste, öne çıkan ve kategoriler dil parametresi gönderir', () async {
    final articles = container.read(articlesApiProvider);
    await articles.getArticles(categoryId: 111);
    await articles.getFeaturedArticle();
    await articles.getCategories();

    expect(api.requests.map((r) => r.queryParameters['lang']), everyElement('en'));
    expect(api.requests.first.queryParameters['category_id'], 111);
  });

  test('dil değişince öne çıkan yazı yeni dilde yeniden çekilir', () async {
    container.listen(featuredArticleProvider, (_, __) {});
    await container.read(featuredArticleProvider.future);

    await container.read(localeProvider.notifier).setLocale(const Locale('tr'));
    await container.read(featuredArticleProvider.future);

    expect(api.requests.map((r) => r.queryParameters['lang']), ['en', 'tr']);
  });
}
