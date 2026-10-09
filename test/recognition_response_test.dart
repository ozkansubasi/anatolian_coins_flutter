// Tanıma yanıtı: Faz D `verified` + AI4 `near_matches` / `basis` (2026-09-29).
// Ekran, verified == false iken adayları "kesin eşleşme yok — en yakın adaylar" olarak ve kullanıcı eşiği
// uygulanmadan gösterir; verified == null (eklenti < 1.16.5) eski davranışı korur.

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';

void main() {
  test('verified alanı yoksa (eski eklenti) null ve yakın aday listesi boş', () {
    final r = RecognitionResponse.fromJson({
      'data': {
        'matches': [
          {'article_id': 3404, 'title': 'X', 'confidence': 0.9},
        ],
      },
    });
    expect(r.verified, isNull);
    expect(r.nearMatches, isEmpty);
    expect(r.matches.single.verified, isFalse);
    expect(r.matches.single.basis, isNull);
  });

  test('doğrulanmış yanıt: verified=true, eşleşmede verified ve basis', () {
    final r = RecognitionResponse.fromJson({
      'data': {
        'verified': true,
        'matches': [
          {'article_id': 3404, 'title': 'X', 'confidence': 1.0, 'verified': true, 'basis': 'both'},
        ],
        'near_matches': [],
      },
    });
    expect(r.verified, isTrue);
    expect(r.matches.single.verified, isTrue);
    expect(r.matches.single.basis, 'both');
  });

  test('eşleşme yok: verified=false, yakın adaylar basis ile ayrışır', () {
    final r = RecognitionResponse.fromJson({
      'data': {
        'verified': false,
        'no_match': true,
        'no_match_reason': 'below_confidence',
        'matches': [],
        'near_matches': [
          {'article_id': 11704, 'title': 'Y', 'confidence': 0.25, 'basis': 'obverse'},
          {'article_id': 22526, 'title': 'Z', 'confidence': 0.21, 'basis': 'both'},
          'bozuk kayıt',
        ],
      },
    });
    expect(r.verified, isFalse);
    expect(r.noMatch, isTrue);
    expect(r.nearMatches.map((m) => m.articleId), [11704, 22526]);
    expect(r.nearMatches.first.basis, 'obverse');
  });

  test('geçmiş kaydı: toJson → fromJson verified ve basis korunur', () {
    final m = CoinMatch.fromJson({'article_id': 7337, 'title': 'Price 2831A', 'confidence': 0.94,
      'verified': true, 'basis': 'obverse'});
    final back = CoinMatch.fromJson(m.toJson());
    expect(back.verified, isTrue);
    expect(back.basis, 'obverse');
    expect(back.articleId, 7337);
  });

  // Hedef 2 (2026-10-09): identification — tip doğrulanmasa da hükümdar / dönem / darphane / tarih.
  test('identification: hükümdar düzeyi, arka yüz adayları ve dönem ayrıştırılır', () {
    final r = RecognitionResponse.fromJson({
      'data': {
        'verified': false,
        'matches': [],
        'identification': {
          'level': 'ruler',
          'basis': 'obverse',
          'ruler': {'name': 'Marcus Aurelius', 'share': 0.83, 'reign_tr': 'MS 161–180', 'reign_en': 'AD 161–180',
              'note_tr': 'Filozof imparator', 'note_en': 'Philosopher emperor'},
          'ruler_alternatives': [],
          'dynasty': {'id': 'nerva_antonine', 'name_tr': 'Nerva–Antoninler', 'name_en': 'Nerva–Antonine', 'share': 0.94},
          'mint': {'name': 'pergamum', 'share': 0.9},
          'date': {'estimate': 165, 'from': 160, 'to': 170},
          'reverse': {
            'status': 'unverified',
            'candidates': [
              {'article_id': 23345, 'title': 'CN Type 4059', 'score': 0.31},
              {'article_id': 'bozuk', 'title': 'X', 'score': 0.2},
            ],
          },
        },
      },
    });
    final i = r.identification!;
    expect(i.level, 'ruler');
    expect(i.rulerName, 'Marcus Aurelius');
    expect(i.rulerReignTr, 'MS 161–180');
    expect(i.dynastyNameTr, 'Nerva–Antoninler');
    expect(i.mint, 'pergamum');
    expect([i.dateFrom, i.dateTo], [160, 170]);
    expect(i.reverseStatus, 'unverified');
    expect(i.reverseCandidates.map((c) => c.articleId), [23345]); // kimliksiz aday atlanır
    expect(i.hasContent, isTrue);
  });

  test('identification yoksa, bozuksa ya da düzeyi yoksa null', () {
    expect(RecognitionResponse.fromJson({'data': {'matches': []}}).identification, isNull);
    expect(RecognitionResponse.fromJson({'data': {'matches': [], 'identification': 'bozuk'}}).identification, isNull);
    expect(RecognitionResponse.fromJson({'data': {'matches': [], 'identification': {'level': null}}}).identification,
        isNull);
  });

  test('doğrulanmış tipte not yoksa kart gösterilmez (hasContent=false)', () {
    final i = CoinIdentification.tryParse({'level': 'type', 'mint': {'name': 'ephesus'}, 'date': {'from': -130, 'to': -129}})!;
    expect(i.hasContent, isFalse);
  });

  // 2026-10-10: kanonik ad (İngilizce, "…, governor of Asia") yerine görünen ad + tür (kart başlığı).
  test('identification: görünen ad, tür ve yerel alternatifler ayrıştırılır', () {
    final i = CoinIdentification.tryParse({
      'level': 'ruler',
      'ruler': {'name': 'T. Ampius, governor of Asia', 'name_tr': 'T. Ampius Balbus', 'name_en': 'T. Ampius Balbus',
          'kind': 'official', 'reign_tr': 'MÖ 58–57'},
      'ruler_alternatives': ['Trajan', 'Alexander III of Macedon'],
      'ruler_alternatives_tr': ['Traianus', 'Büyük İskender'],
      'ruler_alternatives_en': ['Trajan', 'Alexander the Great'],
    })!;
    expect(i.rulerName, 'T. Ampius, governor of Asia');
    expect([i.rulerNameTr, i.rulerNameEn, i.rulerKind], ['T. Ampius Balbus', 'T. Ampius Balbus', 'official']);
    expect(i.rulerAlternativesTr, ['Traianus', 'Büyük İskender']);
    expect(i.rulerAlternativesEn, ['Trajan', 'Alexander the Great']);
  });

  test('identification: eski sunucu (görünen ad yok) → boş alanlar, kanonik ad korunur', () {
    final i = CoinIdentification.tryParse({
      'level': 'ruler',
      'ruler': {'name': 'Hadrian'},
      'ruler_alternatives': ['Trajan', 7],
    })!;
    expect(i.rulerName, 'Hadrian');
    expect([i.rulerNameTr, i.rulerNameEn, i.rulerKind], [null, null, null]);
    expect(i.rulerAlternatives, ['Trajan']); // dize olmayan atlanır
    expect(i.rulerAlternativesTr, isEmpty);
  });
}
