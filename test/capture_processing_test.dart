// Kamera çekimi: çember bölgesinin kırpılması ve netlik ölçümü (2026-09-28, bulanık çekim sorunu).

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

import 'package:anatolian_coins/src/features/recognition/capture_processing.dart';

img.Image _checker(int size, int cell) {
  final im = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final on = ((x ~/ cell) + (y ~/ cell)).isEven;
      im.setPixelRgb(x, y, on ? 230 : 30, on ? 230 : 30, on ? 230 : 30);
    }
  }
  return im;
}

void main() {
  test('cropSideFraction: kutu = kare genişliği, çember %45 → %67,5 (1,5 pay)', () {
    final f = cropSideFraction(
      circleDiameter: 162, boxWidth: 360, boxHeight: 480, frameWidth: 360, frameHeight: 480);
    expect(f, closeTo(0.675, 1e-9));
  });

  test('cropSideFraction: cover ölçeği hesaba katılır (önizleme kutudan uzun)', () {
    // Kare 1080x1920 (9:16), kutu 360x480 → ölçek max(360/1080, 480/1920)=1/3 → kare genişliği 360
    final f = cropSideFraction(
      circleDiameter: 162, boxWidth: 360, boxHeight: 480, frameWidth: 1080, frameHeight: 1920);
    expect(f, closeTo(0.675, 1e-9));
    // Kutu kareden geniş oranlı → dikeyde taşar, yatay ölçek büyür → oran küçülür
    final g = cropSideFraction(
      circleDiameter: 162, boxWidth: 360, boxHeight: 900, frameWidth: 1080, frameHeight: 1920);
    expect(g, lessThan(f));
  });

  test('cropSideFraction sınırlar: 0,2–1,0', () {
    expect(cropSideFraction(circleDiameter: 10, boxWidth: 400, boxHeight: 400, frameWidth: 400, frameHeight: 400), 0.2);
    expect(cropSideFraction(circleDiameter: 900, boxWidth: 400, boxHeight: 400, frameWidth: 400, frameHeight: 400), 1.0);
  });

  test('laplacianVariance: net desen bulanığından çok yüksek', () {
    final sharp = _checker(400, 8);
    final blurred = img.gaussianBlur(sharp.clone(), radius: 6);
    final s = laplacianVariance(sharp);
    final b = laplacianVariance(blurred);
    expect(s, greaterThan(b * 10));
  });

  test('processCaptureBytes: ortadan kare kırpar, en çok 1200 px, JPEG döner', () {
    final big = img.Image(width: 2000, height: 2600);
    img.fill(big, color: img.ColorRgb8(200, 180, 120));
    final bytes = Uint8List.fromList(img.encodeJpg(big));
    final r = processCaptureBytes(bytes, 0.675);
    expect(r.side, 1200); // 0,675×2000 = 1350 → 1200'e indirildi
    final out = img.decodeJpg(r.jpeg)!;
    expect(out.width, 1200);
    expect(out.height, 1200);
  });
}
