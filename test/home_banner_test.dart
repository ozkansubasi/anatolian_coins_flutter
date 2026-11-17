import 'package:anatolian_coins/src/features/home/widgets/home_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// İşaret halkası kare görselin kendi alanına göre konumlanır (17 Kas 2026):
/// `at` = halka merkezi, görsele göre -1..1; bant kutusunun genişliği sonucu değiştirmez.
void main() {
  Future<Offset> halkaMerkezi(WidgetTester tester, double genislik, Alignment at) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: genislik,
            height: 200,
            child: HomeBanner(
              image: 'assets/images/banners/coin_bilgi.jpg',
              slogan: 'Slogan',
              fit: BoxFit.contain,
              onTap: () {},
              markers: [BannerMarker(at, 'Portre')],
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    final halka = find.byWidgetPredicate((w) =>
        w is Container && w.constraints?.maxWidth == 26 && w.constraints?.maxHeight == 26);
    expect(halka, findsOneWidget);
    return tester.getCenter(halka);
  }

  Rect gorselKaresi(WidgetTester tester) {
    // Görsel alanı = Stack'in kutusu; kare görsel contain ile ortada, kenarı = yükseklik.
    final kutu = tester.getRect(find.byType(Stack).first);
    final kenar = kutu.height < kutu.width ? kutu.height : kutu.width;
    return Rect.fromCenter(center: kutu.center, width: kenar, height: kenar);
  }

  testWidgets('merkez (0,0) görselin ortasında', (tester) async {
    final m = await halkaMerkezi(tester, 360, Alignment.center);
    final kare = gorselKaresi(tester);
    expect((m - kare.center).distance, lessThan(1.0));
  });

  testWidgets('köşe noktası kutu genişliğinden bağımsız', (tester) async {
    for (final g in [320.0, 360.0, 420.0]) {
      final m = await halkaMerkezi(tester, g, const Alignment(-0.72, 0.20));
      final kare = gorselKaresi(tester);
      final beklenen = Offset(kare.left + (1 - 0.72) / 2 * kare.width, kare.top + (1 + 0.20) / 2 * kare.height);
      expect((m - beklenen).distance, lessThan(1.0), reason: 'genişlik $g');
    }
  });
}
