// Detay ucu article_id döndürmüyor; kimlik uid'den çözülmeli (2026-09-26).

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/models/variant.dart';

void main() {
  test('article_id varsa o', () {
    expect(Variant.fromJson({'article_id': 3775, 'uid': 'ntr:var:00009999'}).articleId, 3775);
  });

  test('yalnız uid (detay ucu) → uid içindeki numara', () {
    expect(Variant.fromJson({'uid': 'ntr:var:00003266', 'slug': 'x'}).articleId, 3266);
  });

  test('metin olarak gelen kimlik', () {
    expect(Variant.fromJson({'article_id': '3843'}).articleId, 3843);
  });

  test('hiçbiri yoksa 0', () {
    expect(Variant.fromJson({'slug': 'x'}).articleId, 0);
  });
}
