import 'package:anatolian_coins/src/core/web_handoff.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const kod = '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  Map<String, Object?> yanit(String url) => {'data': {'url': url, 'expires_in': 120}};

  test('geçerli geçiş adresi kabul edilir', () {
    final u = parseHandoffUrl(yanit(
        'https://www.numistr.org/index.php?option=com_ajax&plugin=numistrauth&format=raw&task=handoff&code=$kod&lang=tr'));
    expect(u, isNotNull);
    expect(u!.queryParameters['code'], kod);
  });

  test('başka alan adı reddedilir', () {
    expect(parseHandoffUrl(yanit('https://evil.example/index.php?plugin=numistrauth&task=handoff&code=$kod')), isNull);
  });

  test('http reddedilir', () {
    expect(parseHandoffUrl(yanit('http://www.numistr.org/index.php?plugin=numistrauth&task=handoff&code=$kod')), isNull);
  });

  test('başka görev ya da kısa kod reddedilir', () {
    expect(parseHandoffUrl(yanit('https://www.numistr.org/index.php?plugin=numistrauth&task=login&code=$kod')), isNull);
    expect(parseHandoffUrl(yanit('https://www.numistr.org/index.php?plugin=numistrauth&task=handoff&code=abc')), isNull);
  });

  test('beklenmeyen gövde → null (düz adrese düşülür)', () {
    expect(parseHandoffUrl(null), isNull);
    expect(parseHandoffUrl('metin'), isNull);
    expect(parseHandoffUrl({'data': {'url': 5}}), isNull);
    expect(parseHandoffUrl({'errors': []}), isNull);
  });
}
