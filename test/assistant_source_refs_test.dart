import 'package:anatolian_coins/src/features/assistant/assistant_api.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('kaynak numaraları sunucudan gelir, sıradan türetilmez', () {
    final reply = AssistantReply.fromJson({
      'answer': 'Kistophoros [1, 2] ... Bergama [3].',
      'sources': [
        {
          'title': 'Numizmatik terimler',
          'url': 'https://numistr.org/tr/numizmatik-karsiliklar',
          'refs': [1, 2]
        },
        {
          'title': 'Kistophoros',
          'url': 'https://numistr.org/tr/blog/a',
          'refs': [3]
        },
      ],
    });
    expect(reply.sources[0].refLabel, '[1, 2]');
    expect(reply.sources[1].refLabel, '[3]');
  });

  test('refs olmayan (eski sunucu / araç rotası) kaynak numarasız', () {
    final s = AssistantSource.fromJson(
        {'title': 'T', 'url': 'https://numistr.org/x'});
    expect(s.refs, isEmpty);
    expect(s.refLabel, isNull);
  });

  test('url boş kaynak atlanınca diğerlerinin numarası kaymaz', () {
    final reply = AssistantReply.fromJson({
      'answer': '',
      'sources': [
        {
          'title': 'boş',
          'url': '',
          'refs': [1]
        },
        {
          'title': 'Makale',
          'url': 'https://numistr.org/tr/blog/b',
          'refs': [2]
        },
      ],
    });
    expect(reply.sources, hasLength(1));
    expect(reply.sources.single.refLabel, '[2]');
  });
}
