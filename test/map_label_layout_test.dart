// Sade harita: kentler adlarıyla, üst üste binmeden yerleşir (2026-09-27 kullanıcı:
// "haritada çok fazla lokasyon noktası var").

import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/features/map/ancient_map_widget.dart';
import 'package:anatolian_coins/src/features/map/map_label_layout.dart';

void main() {
  test('worldPixel: zoom başına iki kat, ekvator/başlangıç meridyeni merkez', () {
    expect(worldPixel(0, 0, 0), const Offset(128, 128));
    final a = worldPixel(38.5, 32, 8);
    final b = worldPixel(38.5, 32, 9);
    expect(b.dx, closeTo(a.dx * 2, 1e-6));
    expect(b.dy, closeTo(a.dy * 2, 1e-6));
    // Kuzey yukarıda: daha büyük enlem → daha küçük y
    expect(worldPixel(40, 32, 8).dy, lessThan(worldPixel(38, 32, 8).dy));
  });

  test('placeLabels: çakışanlardan önceliklisi kalır, engelle çakışan atlanır', () {
    const a = Rect.fromLTWH(0, 0, 50, 14);
    const b = Rect.fromLTWH(30, 5, 50, 14); // a ile çakışır
    const c = Rect.fromLTWH(200, 0, 50, 14);
    const d = Rect.fromLTWH(400, 0, 50, 14); // engelle çakışır
    final placed = placeLabels<String>(
      const [MapEntry('a', a), MapEntry('b', b), MapEntry('c', c), MapEntry('d', d)],
      const [Rect.fromLTWH(420, 5, 40, 20)],
    );
    expect(placed, {'a', 'c'});
  });

  test('önemli kentler: sitedeki 130 kent, adlar tekil, Anadolu çevresinde', () {
    final cities = [
      for (final c in jsonDecode(File('assets/data/ancient_major_cities.json').readAsStringSync()) as List)
        AncientMapCity.fromJson(c as Map<String, dynamic>),
    ];
    expect(cities.length, 130);
    expect(cities.map((c) => c.name).toSet().length, cities.length);
    for (final c in cities) {
      expect(c.lat, inInclusiveRange(34, 43), reason: c.name);
      expect(c.lng, inInclusiveRange(25, 45), reason: c.name);
    }
  });
}
