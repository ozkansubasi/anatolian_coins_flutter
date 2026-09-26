// Harita verisi ↔ çeviri dosyaları tutarlılığı.
//
// Veri dosyası yalnız kimlik + koordinat taşır; görünen ad/açıklama l10n'da.
// Darphane eklenip anahtarı unutulursa ekranda ham anahtar görünür — bu test
// onu yakalar.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/region_data.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

void main() {
  final data = jsonDecode(File('assets/data/ancient_map_data.json').readAsStringSync())
      as Map<String, dynamic>;
  final mints = (data['mints'] as List).cast<Map<String, dynamic>>();
  final regions = (data['regions'] as List).cast<Map<String, dynamic>>();

  test('darphane kimlikleri tekil', () {
    final ids = mints.map((m) => m['id']).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('bölge ve darphane bölgeleri RegionData ile uyumlu', () {
    for (final r in regions) {
      expect(RegionData.regionCodes, contains(r['regionCode']));
    }
    for (final m in mints) {
      expect(RegionData.regionCodes, contains(m['region']), reason: '${m['id']}');
    }
  });

  for (final locale in AppLocalizations.supportedLocales) {
    final lang = locale.languageCode;
    test('$lang: her darphanenin adı ve açıklaması var', () {
      final table = (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync())
              as Map<String, dynamic>)
          .cast<String, String>();
      final missing = [
        for (final m in mints) ...[
          if (!table.containsKey('map_mint_${m['id']}')) 'map_mint_${m['id']}',
          if (!table.containsKey('map_mint_${m['id']}_desc')) 'map_mint_${m['id']}_desc',
        ],
      ];
      expect(missing, isEmpty);
    });
  }
}
