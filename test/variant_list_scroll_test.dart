// M36 (13 Kas 2026): iPhone'da Keşfet / Sikke Ara 6. kaydırmada 429 → liste silinip
// "Bir sorun oluştu" görünüyordu. Artık: küçük görsel liste yanıtından (sikke başına
// istek yok), sonraki sayfa hatası listeyi silmez (altta ileti + "Tekrar dene").
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:anatolian_coins/src/features/variants/prokit_variant_list_page.dart';
import 'package:anatolian_coins/src/features/variants/variants_api.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';
import 'package:anatolian_coins/src/models/variant.dart';
import 'package:anatolian_coins/src/models/variant_image.dart';

Map<String, dynamic> _row(int id, {bool withThumbField = true}) => {
      'article_id': id,
      'uid': 'ntr:var:$id',
      'slug': 's$id',
      'title_tr': 'Sikke $id',
      'region_code': 'ionia',
      // Ağ görseli sınamada yüklenmesin: alan var ama görselsiz sikke (yer tutucu).
      if (withThumbField) 'thumb_url': null,
      if (withThumbField) 'thumb_remote_url': null,
    };

class _FakeApi implements VariantsApi {
  final pages = <int>[];
  final imageCalls = <int>[];
  int? failPage;
  bool thumbField = true;

  @override
  Future<(List<Variant>, Map<String, dynamic>)> list({
    String? mint,
    String? authority,
    String? material,
    String? region,
    int? yearFrom,
    int? yearTo,
    bool hasImages = false,
    int page = 1,
    int perPage = 20,
    String sort = 'uid_asc',
  }) async {
    pages.add(page);
    if (page == failPage) {
      final o = RequestOptions(path: '/variants');
      throw DioException(
          requestOptions: o, response: Response(requestOptions: o, statusCode: 429));
    }
    final start = (page - 1) * perPage;
    final rows = [for (var i = 0; i < perPage; i++) _row(1000 + start + i, withThumbField: thumbField)];
    return (rows.map(Variant.fromJson).toList(), <String, dynamic>{'total': 100});
  }

  @override
  Future<List<VariantImage>> images(int articleId, {bool wm = true, bool abs = true}) async {
    imageCalls.add(articleId);
    return const [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<AppLocalizations> _pump(WidgetTester tester, _FakeApi api) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  final router = GoRouter(initialLocation: '/browse?region=ionia', routes: [
    GoRoute(path: '/browse', builder: (_, __) => const ProkitVariantListPage()),
    GoRoute(path: '/variant/:id', builder: (_, __) => const SizedBox()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [variantsApiProvider.overrideWithValue(api)],
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
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  return AppLocalizations.of(tester.element(find.byType(ProkitVariantListPage)));
}

Future<void> _scrollToEnd(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.drag(find.byType(Scrollable).last, const Offset(0, -3000));
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  test('Variant: liste yanıtındaki küçük görsel alanları', () {
    final v = Variant.fromJson({
      'article_id': 7,
      'uid': 'u',
      'slug': 's',
      'thumb_url': 'https://www.numistr.org/index.php?option=com_numistr&view=gorsel&id=5&wm=0',
      'thumb_remote_url': 'https://kaynak/5.jpg',
    });
    expect(v.hasListThumb, isTrue);
    expect(v.thumbUrl, contains('id=5'));
    expect(v.thumbRemoteUrl, 'https://kaynak/5.jpg');

    final none = Variant.fromJson({'article_id': 8, 'uid': 'u', 'slug': 's', 'thumb_url': null});
    expect(none.hasListThumb, isTrue, reason: 'alan var, görsel yok → istek atılmaz');
    expect(none.thumbUrl, isNull);

    final old = Variant.fromJson({'article_id': 9, 'uid': 'u', 'slug': 's'});
    expect(old.hasListThumb, isFalse, reason: 'eski API → kart görseli ayrı istekle');
  });

  testWidgets('küçük görsel liste yanıtından: görsel ucu çağrılmaz', (tester) async {
    final api = _FakeApi();
    await _pump(tester, api);
    expect(api.pages, [1]);
    expect(find.text('Sikke 1000'), findsOneWidget);
    expect(api.imageCalls, isEmpty);
  });

  testWidgets('eski API (alan yok): sikke başına görsel isteği yedek yol', (tester) async {
    final api = _FakeApi()..thumbField = false;
    await _pump(tester, api);
    expect(api.imageCalls.length, 20);
  });

  testWidgets('kaydırmada 429: liste kalır, altta ileti + tekrar dene; tekrar dene sayfa 2\'yi getirir',
      (tester) async {
    final api = _FakeApi()..failPage = 2;
    final l10n = await _pump(tester, api);

    await _scrollToEnd(tester);
    expect(api.pages, [1, 2]);
    // Eski davranış: tam ekran hata + liste silinir. Artık liste yerinde.
    expect(find.text(l10n.translate('error_generic')), findsNothing);
    expect(find.text(l10n.translate('error_rate_limited')), findsOneWidget);
    final retry = find.text(l10n.translate('retry'));
    expect(retry, findsOneWidget);

    // Hata altbilgisi görünürken kaydırma kendiliğinden yeniden istemez (döngü yok).
    await _scrollToEnd(tester);
    expect(api.pages, [1, 2]);

    api.failPage = null;
    await tester.tap(retry);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(api.pages, [1, 2, 2]);
    expect(find.text(l10n.translate('error_rate_limited')), findsNothing);
    // Sayfalama kaldığı yerden sürer (sayfa atlanmaz, tekrar edilmez).
    await _scrollToEnd(tester);
    expect(api.pages.sublist(0, 4), [1, 2, 2, 3]);
  });

  testWidgets('ilk sayfa 429: tam ekran ileti "çok fazla istek" (bağlantı hatası değil)', (tester) async {
    final api = _FakeApi()..failPage = 1;
    final l10n = await _pump(tester, api);
    expect(find.text(l10n.translate('error_rate_limited')), findsOneWidget);
    expect(find.text(l10n.translate('error_network')), findsNothing);
  });
}
