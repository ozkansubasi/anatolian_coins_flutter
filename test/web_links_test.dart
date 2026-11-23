import 'package:anatolian_coins/src/core/web_links.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('coinIdFromWebUrl (M31)', () {
    test('sikke sayfası: www / www\'siz, TR / EN, göreli', () {
      expect(coinIdFromWebUrl('https://www.numistr.org/tr/anatolian-coins/lydia-coins/30669-sardis-carradice-1987-croeseid-a-heavy-au'), 30669);
      expect(coinIdFromWebUrl('https://numistr.org/tr/anatolian-coins/troas-coins/23655-cn-type-19621'), 23655);
      expect(coinIdFromWebUrl('https://www.numistr.org/en/anatolian-coins/lydia-coins/3816-sardis-weidauer-1975-xvi'), 3816);
      expect(coinIdFromWebUrl('/tr/anatolian-coins/lydia-coins/3817-alyattes'), 3817);
    });
    test('sikke sayfası değil → null', () {
      expect(coinIdFromWebUrl('https://numistr.org/tr/lidya-yerlesimleri/30727-sardis-hyde'), isNull);
      expect(coinIdFromWebUrl('https://www.numistr.org/tr/sikke-hikayeleri/34028-lidya'), isNull);
      expect(coinIdFromWebUrl('https://en.wikipedia.org/tr/anatolian-coins/x/12-y'), isNull);
      expect(coinIdFromWebUrl('https://www.numistr.org/tr/anatolian-coins/lydia-coins'), isNull);
      expect(coinIdFromWebUrl(''), isNull);
    });
  });
}
