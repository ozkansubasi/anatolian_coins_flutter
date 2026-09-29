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
}
