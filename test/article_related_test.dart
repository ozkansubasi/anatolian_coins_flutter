// İlgili sikke eşleştirmesi: yanlış eşleşme kullanıcıya YANLIŞ sikke gösterir,
// bu yüzden hem pozitif hem negatif durumlar sabitlenir.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/articles/article_related.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations tr;
  late AppLocalizations en;

  setUpAll(() async {
    tr = await AppLocalizations.load(const Locale('tr'));
    en = await AppLocalizations.load(const Locale('en'));
  });

  test('başlıktaki Türkçe bölge adı (büyük harf, İ dahil)', () {
    final t = detectCoinTarget('BİTİNYA', tr);
    expect(t?.region, 'bithynia-coins');
    expect(t?.mint, isNull);
  });

  test('Latince bölge adı ve yazım varyantı', () {
    expect(detectCoinTarget('Coins of Phrygia', en)?.region, 'phrygia-coins');
    expect(detectCoinTarget('Pisidya Sikkeleri', tr)?.region, 'pisidia-coins');
  });

  test('bölge adı arayüz dilinden gelir', () {
    expect(detectCoinTarget('Lidya Sikkeleri', tr)?.name, 'Lidya');
    expect(detectCoinTarget('Coins of Lydia', en)?.name, 'Lydia');
  });

  test('bölge yoksa darphane kökü', () {
    final t = detectCoinTarget('Nicomedia darphanesi ve Roma', tr);
    expect(t?.mint, 'nicomedia');
    expect(t?.region, 'bithynia-coins');
  });

  test('tam kelime: alt dize eşleşmez', () {
    // "Karyatid" içinde "karya" geçer ama bölge değildir.
    expect(detectCoinTarget('Karyatid heykelleri', tr), isNull);
  });

  test('bölge/darphane yoksa modül gösterilmez', () {
    expect(detectCoinTarget('Pers Hakimiyeti: Anadolu Darphaneleri Satraplar İçin', tr), isNull);
  });
}
