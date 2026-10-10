// M17 — oturumsuz deneme hakkı (kurulum başına 3 tanıma, 2026-10-11).
//
// Sunucu: eklenti 1.18.0 `/v1/recognize` (X-Device-Id) + `/v1/anon/scan-quota`. Burada istemcinin
// kararları sınanır: kurulum kimliği, deneme kotasının ayrıştırılması ve 429 gövdesindeki deneme
// kodlarının kota hatasından ayrılması (deneme reddi kullanıcıya "Pro'ya geç" değil, ücretsiz
// hesap daveti olarak gösterilir).

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/core/install_id.dart';
import 'package:anatolian_coins/src/features/recognition/recognition_service.dart';

void main() {
  group('InstallId', () {
    test('üretilen kimlik UUID v4 biçiminde ve her seferinde farklı', () {
      final r = Random(7);
      final a = InstallId.generate(r);
      final b = InstallId.generate(r);
      expect(InstallId.isValid(a), isTrue, reason: a);
      expect(InstallId.isValid(b), isTrue, reason: b);
      expect(a, isNot(b));
    });

    test('kayıtlı geçerli kimlik aynen döner, yeniden yazılmaz', () async {
      const saved = '3f2b8c1e-9a4d-4c7e-b1f0-5d6a7e8f9a0b';
      var writes = 0;
      final id = await InstallId.get(
        read: (_) async => saved,
        write: (_, __) async => writes++,
      );
      expect(id, saved);
      expect(writes, 0);
    });

    test('kayıt yoksa ya da bozuksa yenisi üretilip kaydedilir', () async {
      for (final saved in [null, '', 'not-a-uuid', '3F2B8C1E-9A4D-4C7E-B1F0-5D6A7E8F9A0B']) {
        String? written;
        final id = await InstallId.get(
          read: (_) async => saved,
          write: (k, v) async {
            expect(k, InstallId.storageKey);
            written = v;
          },
          random: Random(1),
        );
        expect(InstallId.isValid(id), isTrue, reason: 'kayıt: $saved');
        expect(written, id, reason: 'kayıt: $saved');
      }
    });
  });

  group('deneme kotası', () {
    test('/anon/scan-quota: 3 hak, 1 kullanılmış', () {
      final q = ScanQuota.fromJson({
        'enabled': true,
        'scans_used': 1,
        'scan_limit': 3,
        'remaining': 2,
        'is_pro': false,
        'reset_date': null,
        'tier': 'anonymous',
      });
      expect(q.isAnonymous, isTrue);
      expect(q.trialEnabled, isTrue);
      expect(q.remaining, 2);
      expect(q.limit, 3);
      expect(q.hasScansAvailable, isTrue);
    });

    test('hak bitince tarama yok', () {
      final q = ScanQuota.fromJson(
          {'enabled': true, 'scans_used': 3, 'scan_limit': 3, 'remaining': 0, 'tier': 'anonymous'});
      expect(q.hasScansAvailable, isFalse);
      expect(q.trialEnabled, isTrue);
    });

    test('deneme kapalıysa (kapatma anahtarı / ölçülemedi) kalan olsa bile tarama yok', () {
      final q = ScanQuota.fromJson(
          {'enabled': false, 'scans_used': 0, 'scan_limit': 3, 'remaining': 3, 'tier': 'anonymous'});
      expect(q.hasScansAvailable, isFalse);
      expect(q.trialEnabled, isFalse);
    });

    test('tanıma yanıtındaki kota (used/limit anahtarları) da okunur', () {
      final r = RecognitionResponse.fromJson({
        'data': {'matches': []},
        'quota': {'used': 2, 'remaining': 1, 'limit': 3, 'tier': 'anonymous', 'reset_date': null},
      });
      expect(r.quota!.isAnonymous, isTrue);
      expect(r.quota!.limit, 3);
      expect(r.quota!.used, 2);
      expect(r.quota!.remaining, 1);
    });

    test('oturumlu kota değişmedi: tier yoksa anonim değil, Pro -1 kotasız', () {
      final free = ScanQuota.fromJson({'scans_used': 4, 'scan_limit': 10, 'remaining': 6, 'is_pro': false});
      expect(free.isAnonymous, isFalse);
      expect(free.hasScansAvailable, isTrue);
      final pro = ScanQuota.fromJson({'scans_used': 0, 'scan_limit': -1, 'remaining': -1, 'is_pro': true});
      expect(pro.hasScansAvailable, isTrue);
    });
  });

  group('hata eşlemesi', () {
    const exhausted =
        '{"success":false,"error":{"code":"TRIAL_EXHAUSTED","message":"x","quota":{"used":3,"remaining":0,"limit":3}}}';

    test('429 + TRIAL_EXHAUSTED (düz metin gövde) → deneme bitti, kota hatası değil', () {
      final e = RecognitionService.exceptionFor(429, exhausted, null);
      expect(e.isTrialEnded, isTrue);
      expect(e.trialCode, 'TRIAL_EXHAUSTED');
      expect(e.isQuotaExceeded, isFalse);
    });

    test('429 + TRIAL_UNAVAILABLE (ayrıştırılmış gövde) → deneme kullanılamıyor', () {
      final e = RecognitionService.exceptionFor(429, {
        'success': false,
        'error': {'code': 'TRIAL_UNAVAILABLE', 'message': 'x'},
      }, null);
      expect(e.trialCode, 'TRIAL_UNAVAILABLE');
      expect(e.isQuotaExceeded, isFalse);
    });

    test('kodsuz 429 → kota hatası (oturumlu davranış aynı)', () {
      final e = RecognitionService.exceptionFor(429, '{"error":{"code":"QUOTA_EXCEEDED"}}', null);
      expect(e.isQuotaExceeded, isTrue);
      expect(e.isTrialEnded, isFalse);
    });

    test('401 → oturum gerekli; 503 → servis yok; bozuk gövde güvenle yok sayılır', () {
      expect(RecognitionService.exceptionFor(401, 'not json', null).isAuthRequired, isTrue);
      expect(RecognitionService.exceptionFor(503, null, null).isServiceUnavailable, isTrue);
      final other = RecognitionService.exceptionFor(500, '{', 'boom');
      expect(other.isTrialEnded || other.isQuotaExceeded || other.isAuthRequired, isFalse);
    });
  });
}
