// Yazı içindeki figür görselleri (TestFlight 0.6.4+32: görünmüyordu, yalnız altyazı kalıyordu).
//
// HTML, API'nin `/v1/articles/34108` (Skepsis) içeriğinden kısaltılarak alındı.

import 'package:flutter/material.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/articles/article_image_extension.dart';

const _figure = '''
<p>Önceki paragraf.</p>
<figure class="numistr-figur" style="margin:32px 0;padding:0">
  <div class="numistr-figur-sira" style="display:flex;gap:16px;justify-content:center;align-items:center;flex-wrap:wrap">
    <img src="https://www.numistr.org/index.php?option=com_numistr&amp;view=gorsel&amp;format=raw&amp;id=115905&amp;wm=1" alt="CN Type 19598 — Ön yüz" loading="lazy" style="max-width:230px;width:45%;display:block;height:auto">
    <img src="https://www.numistr.org/index.php?option=com_numistr&amp;view=gorsel&amp;format=raw&amp;id=115906&amp;wm=1" alt="CN Type 19598 — Arka yüz" loading="lazy" style="max-width:230px;width:45%;display:block;height:auto">
  </div>
  <figcaption style="text-align:center"><b><a href="https://www.numistr.org/tr/anatolian-coins/troas-coins/23644-cn-type-19598">CN Type 19598</a></b> — Scepsis</figcaption>
</figure>
<p><img src="/images/blog/harita.jpg" alt="Harita"></p>
''';

Future<Map<String, double>> _pump(WidgetTester tester, double screenWidth) async {
  final widths = <String, double>{};
  tester.view.physicalSize = Size(screenWidth * 3, 2400);
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Html(
          data: _figure,
          extensions: [
            ArticleImageExtension(
              horizontalInset: 40,
              imageBuilder: (url, width, alt) {
                widths[url] = width;
                return SizedBox(width: width, height: width, child: Text(alt ?? ''));
              },
            ),
          ],
        ),
      ),
    ),
  ));
  await tester.pump();
  return widths;
}

void main() {
  group('resolveSrc', () {
    test('mutlak adres aynen, göreli adres siteye göre', () {
      expect(ArticleImageExtension.resolveSrc('https://www.numistr.org/a.jpg'),
          'https://www.numistr.org/a.jpg');
      expect(ArticleImageExtension.resolveSrc('/images/blog/x.jpg'),
          'https://www.numistr.org/images/blog/x.jpg');
      expect(ArticleImageExtension.resolveSrc('images/x.png'), 'https://www.numistr.org/images/x.png');
    });

    test('çizilemeyenler eşleşmez (boş, svg, data, mailto)', () {
      expect(ArticleImageExtension.resolveSrc(null), isNull);
      expect(ArticleImageExtension.resolveSrc('  '), isNull);
      expect(ArticleImageExtension.resolveSrc('https://x.org/logo.SVG'), isNull);
      expect(ArticleImageExtension.resolveSrc('data:image/png;base64,AAAA'), isNull);
      expect(ArticleImageExtension.resolveSrc('mailto:a@b.c'), isNull);
    });
  });

  group('imageWidth', () {
    test('figür sırası satırı eşit paylaşır, en fazla 230', () {
      expect(ArticleImageExtension.imageWidth(contentWidth: 350, perRow: 2), 155);
      expect(ArticleImageExtension.imageWidth(contentWidth: 800, perRow: 2), 230);
    });

    test('tek görsel içerik genişliğini kullanır', () {
      expect(ArticleImageExtension.imageWidth(contentWidth: 350, perRow: 1), 350);
    });
  });

  testWidgets('figürün iki görseli yan yana, ekrana göre boyutlanır (telefon 390)', (tester) async {
    final widths = await _pump(tester, 390);
    const on = 'https://www.numistr.org/index.php?option=com_numistr&view=gorsel&format=raw&id=115905&wm=1';
    const arka = 'https://www.numistr.org/index.php?option=com_numistr&view=gorsel&format=raw&id=115906&wm=1';

    expect(widths[on], 155); // (390 - 40 - 2×(12 + 8)) / 2
    expect(widths[arka], 155);
    expect(widths['https://www.numistr.org/images/blog/harita.jpg'], 350); // göreli, tek görsel

    // Yan yana: aynı satırda, ön yüz solda.
    final onBox = tester.getRect(find.text('CN Type 19598 — Ön yüz'));
    final arkaBox = tester.getRect(find.text('CN Type 19598 — Arka yüz'));
    expect(onBox.top, arkaBox.top);
    expect(onBox.right, lessThanOrEqualTo(arkaBox.left));
    // Altyazı ve bağlantısı yerinde.
    expect(find.textContaining('CN Type 19598', findRichText: true), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş ekranda (iPad) figür görseli 230 ile sınırlı', (tester) async {
    final widths = await _pump(tester, 1024);
    expect(widths.values.where((w) => w == 230).length, 2);
    expect(tester.takeException(), isNull);
  });
}
