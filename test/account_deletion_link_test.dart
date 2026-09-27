import 'package:anatolian_coins/src/core/web_links.dart';
import 'package:flutter_test/flutter_test.dart';

/// Play politikası (hesap silme uygulama içinden de): Hesabım → "Hesabımı Sil".
void main() {
  test('silme sayfası Play\'e kayıtlı adresler', () {
    expect(accountDeletionWebUrl('en').toString(), 'https://www.numistr.org/en/delete-account');
    expect(accountDeletionWebUrl('tr').toString(), 'https://www.numistr.org/tr/hesap-silme');
  });

  test('hazır e-posta: boşluk %20 (+ değil), Türkçe harf ve @ kodlanır', () {
    final uri = accountDeletionMailUrl(
      subject: 'Hesap silme talebi',
      body: 'NumisTR hesabımın silinmesini talep ediyorum: a.b@örnek.com',
    );
    final s = uri.toString();
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'bilgi@numistr.org');
    expect(s, contains('subject=Hesap%20silme%20talebi'));
    expect(s, isNot(contains('+')));
    expect(Uri.decodeComponent(s.split('body=').last),
        'NumisTR hesabımın silinmesini talep ediyorum: a.b@örnek.com');
  });
}
