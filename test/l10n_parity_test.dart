// Çeviri dosyaları: her desteklenen dilin dosyası var, anahtar kümeleri eş,
// parametre yer tutucuları ({limit} gibi) her dilde aynı.
//
// Yeni dil eklenince bu test hangi anahtarların eksik olduğunu listeler.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/l10n/app_localizations.dart';

Map<String, String> _table(String lang) =>
    (jsonDecode(File('assets/l10n/$lang.json').readAsStringSync()) as Map<String, dynamic>)
        .cast<String, String>();

Set<String> _placeholders(String text) =>
    RegExp(r'\{(\w+)\}').allMatches(text).map((m) => m.group(1)!).toSet();

void main() {
  const reference = AppLocalizations.fallbackLanguage;
  final ref = _table(reference);
  final langs = AppLocalizations.supportedLocales.map((l) => l.languageCode);

  for (final lang in langs.where((l) => l != reference)) {
    group(lang, () {
      final table = _table(lang);

      test('anahtar kümesi $reference ile eş', () {
        expect(ref.keys.toSet().difference(table.keys.toSet()), isEmpty,
            reason: '$lang.json içinde eksik');
        expect(table.keys.toSet().difference(ref.keys.toSet()), isEmpty,
            reason: '$reference.json içinde eksik');
      });

      test('yer tutucular eş', () {
        final mismatched = [
          for (final k in ref.keys)
            if (table.containsKey(k) &&
                !setEquals(_placeholders(ref[k]!), _placeholders(table[k]!)))
              k,
        ];
        expect(mismatched, isEmpty);
      });
    });
  }
}
