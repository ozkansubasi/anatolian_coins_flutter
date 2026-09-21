// İlgili sikke eşleştirmesi: yanlış eşleşme kullanıcıya YANLIŞ sikke gösterir,
// bu yüzden hem pozitif hem negatif durumlar sabitlenir.

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/articles/article_related.dart';

void main() {
  test('başlıktaki Türkçe bölge adı (büyük harf, İ dahil)', () {
    final t = detectCoinTarget('BİTİNYA');
    expect(t?.region, 'bithynia-coins');
    expect(t?.mint, isNull);
  });

  test('Latince bölge adı ve yazım varyantı', () {
    expect(detectCoinTarget('Coins of Phrygia')?.region, 'phrygia-coins');
    expect(detectCoinTarget('Pisidya Sikkeleri')?.region, 'pisidia-coins');
  });

  test('bölge yoksa darphane kökü', () {
    final t = detectCoinTarget('Nicomedia darphanesi ve Roma');
    expect(t?.mint, 'nicomedia');
    expect(t?.region, 'bithynia-coins');
  });

  test('tam kelime: alt dize eşleşmez', () {
    // "Karyatid" içinde "karya" geçer ama bölge değildir.
    expect(detectCoinTarget('Karyatid heykelleri'), isNull);
  });

  test('bölge/darphane yoksa modül gösterilmez', () {
    expect(detectCoinTarget('Pers Hakimiyeti: Anadolu Darphaneleri Satraplar İçin'), isNull);
  });
}
