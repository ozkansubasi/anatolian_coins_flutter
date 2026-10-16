// M28 (ADR-009 K4/K5) — kapsam dışı günümüz Türk parası: yanıt ayrıştırma ve mesaj cümlesi.
// Sunucu (AI12, eklenti 1.21.0) `no_match_reason: modern_coin` + `modern_coin {unit, denomination, year}`
// döner; OCR'ın okuyamadığı alan null gelir ve cümleden o parça çıkar. Tarama hakkından söz edilmez.

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/recognition/modern_coin_text.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

AppLocalizations _l10n(String dil) => AppLocalizations(
      Locale(dil),
      (jsonDecode(File('assets/l10n/$dil.json').readAsStringSync()) as Map<String, dynamic>).cast<String, String>(),
    );

void main() {
  test('yanıt: modern_coin ayrıştırılır, aday listesi boş', () {
    final r = RecognitionResponse.fromJson({
      'data': {
        'no_match': true,
        'no_match_reason': 'modern_coin',
        'matches': [],
        'near_matches': [],
        'identification': null,
        'modern_coin': {'country': 'TR', 'unit': 'lira', 'denomination': 1, 'year': 2005},
      },
    });
    expect(r.isModernCoin, isTrue);
    expect(r.matches, isEmpty);
    expect(r.modernCoin!.unit, 'lira');
    expect(r.modernCoin!.denomination, 1);
    expect(r.modernCoin!.year, 2005);
  });

  test('yanıt: kapı kapalıyken modern_coin null, eski yanıtlar etkilenmez', () {
    final r = RecognitionResponse.fromJson({
      'data': {'no_match': true, 'no_match_reason': 'no_coin_detected', 'matches': [], 'modern_coin': null},
    });
    expect(r.isModernCoin, isFalse);
    expect(r.modernCoin, isNull);
    expect(ModernCoin.tryParse({'unit': '', 'denomination': null, 'year': null})!.unit, isNull);
  });

  group('cümle (TR)', () {
    final tr = _l10n('tr');
    test('tam', () {
      expect(modernCoinSentence(tr, const ModernCoin(unit: 'lira', denomination: 1, year: 2005)),
          'Fotoğraftaki para 2005 tarihli 1 lira gibi görünüyor.');
    });
    test('yalnız değer', () {
      expect(modernCoinSentence(tr, const ModernCoin(unit: 'kurus', denomination: 50)),
          'Fotoğraftaki para 50 kuruş gibi görünüyor.');
    });
    test('yalnız yıl', () {
      expect(modernCoinSentence(tr, const ModernCoin(unit: 'lira', year: 2009)),
          'Fotoğraftaki para 2009 tarihli, birimi lira gibi görünüyor.');
    });
    test('yalnız birim', () {
      expect(modernCoinSentence(tr, const ModernCoin(unit: 'kurus')), 'Fotoğraftaki paranın birimi kuruş gibi görünüyor.');
    });
    test('birim yoksa cümle yok', () {
      expect(modernCoinSentence(tr, const ModernCoin(denomination: 1, year: 2005)), isNull);
      expect(modernCoinSentence(tr, null), isNull);
    });
    test('kesirli değer ve bilinmeyen birim', () {
      expect(modernCoinSentence(tr, const ModernCoin(unit: 'mark', denomination: 0.5)),
          'Fotoğraftaki para 0.5 mark gibi görünüyor.');
    });
    test('mesajda tarama hakkı geçmez', () {
      final metin = [tr.translate('modern_coin_title'), tr.translate('modern_coin_desc'),
          modernCoinSentence(tr, const ModernCoin(unit: 'lira', denomination: 1, year: 2005))].join(' ').toLowerCase();
      expect(metin.contains('hak'), isFalse);
      expect(metin.contains('kota'), isFalse);
    });
  });

  test('cümle (EN)', () {
    final en = _l10n('en');
    expect(modernCoinSentence(en, const ModernCoin(unit: 'lira', denomination: 1, year: 2005)),
        'The coin in the photo appears to be a 1 lira dated 2005.');
    expect(modernCoinSentence(en, const ModernCoin(unit: 'kurus')), 'The unit of the coin in the photo appears to be kuruş.');
  });
}
