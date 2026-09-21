// Ortak sikke biçimlendirici. Tanıma sonuçları eskiden "-133 - -50",
// sikke detayı "133 BC - 50 BC" gösteriyordu.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/coin_format.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  final tr = AppLocalizations(const Locale('tr'));
  final en = AppLocalizations(const Locale('en'));

  test('dönem: MÖ/MS, dile göre sıra', () {
    expect(CoinFormat.dateRange(-133, -50, tr), 'MÖ 133 – MÖ 50');
    expect(CoinFormat.dateRange(-133, -50, en), '133 BC – 50 BC');
    expect(CoinFormat.dateRange(-30, 14, tr), 'MÖ 30 – MS 14');
    expect(CoinFormat.dateRange(-300, -300, tr), 'MÖ 300');
    expect(CoinFormat.dateRange(null, -50, tr), 'MÖ 50');
    expect(CoinFormat.dateRange(null, null, tr), isNull);
  });

  test('materyal: bilinen değer çevrilir, bilinmeyen baş harfi büyük', () {
    expect(CoinFormat.material('bronze', tr), 'Bronz');
    expect(CoinFormat.material('silver', en), 'Silver');
    expect(CoinFormat.material('orichalcum', tr), 'Orichalcum');
    expect(CoinFormat.material('  ', tr), isNull);
  });

  test('özel ad: küçük harf ve alt çizgi', () {
    expect(CoinFormat.titleCase('smyrna'), 'Smyrna');
    expect(CoinFormat.titleCase('antiocheia_pisidia'), 'Antiocheia Pisidia');
  });
}
