import 'package:anatolian_coins/src/features/map/map_locations_api.dart';
import 'package:flutter_test/flutter_test.dart';

/// Yerleşim kartındaki "Makaleyi aç" uygulama içi `/article/:id` açar; kimlik sitedeki
/// makale adresinden gelir (`/v1/locations` → `url`).
void main() {
  MapLocation loc(String? url) => MapLocation.fromJson({
        'id': 'LOC-0007',
        'lat': 38.46,
        'lng': 27.35,
        'name': 'Ulucak Höyük',
        'has_coins': false,
        'url': url,
      });

  test('makale kimliği adresten', () {
    expect(loc('https://numistr.org/tr/ionya-yerlesimleri/30698-ulucak-hoyuk').articleId, 30698);
    expect(loc('https://numistr.org/en/ionia-settlements/31234-ulucak/').articleId, 31234);
  });

  test('adres yoksa ya da biçim farklıysa kimlik yok', () {
    expect(loc(null).articleId, isNull);
    expect(loc('https://numistr.org/tr/antik-harita').articleId, isNull);
  });

  test('has_coins 1/true darphane sayılır', () {
    expect(MapLocation.fromJson({'id': 'A', 'name': 'x', 'has_coins': 1}).hasCoins, isTrue);
    expect(MapLocation.fromJson({'id': 'A', 'name': 'x', 'has_coins': true}).hasCoins, isTrue);
    expect(MapLocation.fromJson({'id': 'A', 'name': 'x'}).hasCoins, isFalse);
  });
}
