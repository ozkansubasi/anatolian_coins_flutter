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
  // Önizlemede 15°'lik döndürme (2026-09-28 kullanıcı isteği): yön Transform.rotate ile aynı
  // (pozitif = saat yönü), boyut korunur, köşe boşluğu kenar rengiyle dolar.
  img.Image markerImage() {
    final im = img.Image(width: 300, height: 300);
    img.fill(im, color: img.ColorRgb8(120, 120, 120));
    img.fillRect(im, x1: 140, y1: 10, x2: 160, y2: 60, color: img.ColorRgb8(255, 0, 0)); // üst-orta
    return im;
  }

  ({double x, double y}) redCentroid(img.Image im) {
    var sx = 0.0, sy = 0.0, n = 0;
    for (final p in im) {
      if (p.r > 180 && p.g < 90 && p.b < 90) {
        sx += p.x;
        sy += p.y;
        n++;
      }
    }
    return (x: sx / n, y: sy / n);
  }

  test('rotateImageBytes: +45° saat yönü — üstteki işaret sağa kayar, kare kırpılmaz', () {
    final bytes = Uint8List.fromList(img.encodeJpg(markerImage(), quality: 100));
    final out = img.decodeJpg(rotateImageBytes(bytes, 45))!;
    expect(out.width, greaterThan(300)); // döndürülmüş karenin tamamı korunur
    expect(out.height, out.width);
    final c = redCentroid(out);
    expect(c.x, greaterThan(out.width / 2 + 20)); // merkezin sağında
    expect(c.y, lessThan(out.height / 2 - 30)); // hâlâ üst yarıda
  });

  test('rotateImageBytes: dikey fotoğrafta merkezdeki sikke her açıda merkezde kalır', () {
    // 2026-11-01 gerçek tarama: ~90° döndürülen dikey fotoğrafta sikke karenin üstüne kayıyordu.
    final portrait = img.Image(width: 300, height: 600);
    img.fill(portrait, color: img.ColorRgb8(120, 120, 120));
    img.fillCircle(portrait, x: 150, y: 300, radius: 40, color: img.ColorRgb8(255, 0, 0));
    final bytes = Uint8List.fromList(img.encodeJpg(portrait, quality: 100));
    for (final deg in <double>[15, 75, 90, 105, 180, -75, -90, -105]) {
      final out = img.decodeJpg(rotateImageBytes(bytes, deg))!;
      final c = redCentroid(out);
      expect(c.x, closeTo(out.width / 2, 4), reason: '$deg° x');
      expect(c.y, closeTo(out.height / 2, 4), reason: '$deg° y');
    }
  });

  test('rotateImageBytes: dikey fotoğrafta merkez dışındaki sikke 90° dönünce kaybolmaz', () {
    final portrait = img.Image(width: 300, height: 600);
    img.fill(portrait, color: img.ColorRgb8(120, 120, 120));
    img.fillCircle(portrait, x: 150, y: 80, radius: 40, color: img.ColorRgb8(255, 0, 0));
    final bytes = Uint8List.fromList(img.encodeJpg(portrait, quality: 100));
    final out = img.decodeJpg(rotateImageBytes(bytes, 90))!;
    expect(out.width, 600);
    expect(out.height, 300);
    expect(redCentroid(out).x, greaterThan(450)); // üstteki sikke saat yönünde sağa gelir
  });

  test('rotateImageBytes: -15° saat yönünün tersi — işaret sola kayar', () {
    final bytes = Uint8List.fromList(img.encodeJpg(markerImage(), quality: 100));
    final out = img.decodeJpg(rotateImageBytes(bytes, -15))!;
    expect(redCentroid(out).x, lessThan(out.width / 2 - 5));
  });

  test('rotateImageBytes: köşeler siyah değil, kenar rengiyle dolu', () {
    final bytes = Uint8List.fromList(img.encodeJpg(markerImage(), quality: 100));
    final out = img.decodeJpg(rotateImageBytes(bytes, 30))!;
    final corner = out.getPixel(2, 2);
    expect(corner.r, inInclusiveRange(100, 140));
    expect(corner.g, inInclusiveRange(100, 140));
  });

  group('yakınlaştırma', () {
    // 400×800 görsel, 400×800 kutu → k = 1: görünüm birimi = piksel.
    Uint8List disc(int cx, int cy) {
      final im = img.Image(width: 400, height: 800);
      img.fill(im, color: img.ColorRgb8(120, 120, 120));
      img.fillCircle(im, x: cx, y: cy, radius: 50, color: img.ColorRgb8(255, 0, 0));
      return Uint8List.fromList(img.encodeJpg(im, quality: 100));
    }

    /// Kutu merkezine ([px],[py]) içerik noktasını getiren görünüm.
    PreviewViewport look(double s, double px, double py, {double w = 400, double h = 800}) =>
        PreviewViewport(
            viewWidth: w, viewHeight: h, scale: s, tx: w / 2 - s * px, ty: h / 2 - s * py);

    test('görünen bölge kırpılır, sikke ortada ve büyük kalır', () {
      final out = img.decodeJpg(prepareScanImage(disc(100, 150), 0, look(4, 100, 150)))!;
      expect(out.width, 100);
      expect(out.height, 200);
      final c = redCentroid(out);
      expect(c.x, closeTo(50, 4));
      expect(c.y, closeTo(100, 4));
    });

    test('yakınlaştırma yoksa tam kare gider', () {
      final out = img.decodeJpg(prepareScanImage(disc(100, 150), 0, null))!;
      expect(out.width, 400);
      expect(out.height, 800);
    });

    test('döndürülmüş görselde ekrandaki nokta kırpımın ortasına gelir', () {
      // +90°: görsel merkeze göre (x,y) → (-y,x). (200,150) içerik noktası merkezden 250 yukarıda,
      // döndükten sonra merkezden 250 sağda: ekranda (450,400).
      final out =
          img.decodeJpg(prepareScanImage(disc(200, 150), 90, look(4, 450, 400)))!;
      final c = redCentroid(out);
      expect(c.x, closeTo(out.width / 2, 5));
      expect(c.y, closeTo(out.height / 2, 5));
    });

    test('küçük resim gibi kutuya sığdırma ölçeği hesaba katılır', () {
      // Kutu 200×400: görsel yarı boyutta görünür, kırpım yine özgün pikselde.
      final out = img.decodeJpg(prepareScanImage(
          disc(100, 150), 0, look(4, 50, 75, w: 200, h: 400)))!;
      expect(out.width, 100);
      expect(out.height, 200);
      expect(redCentroid(out).x, closeTo(50, 4));
    });

    test('görselin tamamen dışına kaydırılmışsa tam kare gider', () {
      final out = img.decodeJpg(prepareScanImage(disc(100, 150), 0, look(4, 2000, 2000)))!;
      expect(out.width, 400);
      expect(out.height, 800);
    });

    test('yakınlaşmış görünümde döndürünce ekran ortasındaki nokta yerinde kalır', () {
      // Kırmızı disk ekranın ortasındayken 90° dönsün: yeni öteleme diski yine ortaya getirmeli.
      final before = look(4, 100, 150);
      final t = translationAfterRotation(
          viewWidth: 400, viewHeight: 800, scale: 4, tx: before.tx, ty: before.ty, deltaDegrees: 90);
      final out = img.decodeJpg(prepareScanImage(disc(100, 150), 90,
          PreviewViewport(viewWidth: 400, viewHeight: 800, scale: 4, tx: t.tx, ty: t.ty)))!;
      final c = redCentroid(out);
      expect(c.x, closeTo(out.width / 2, 5));
      expect(c.y, closeTo(out.height / 2, 5));
    });
  });

  test('rotateImageBytes: 0° dokunmaz (boyut aynı)', () {
    final bytes = Uint8List.fromList(img.encodeJpg(markerImage(), quality: 100));
    final out = img.decodeJpg(rotateImageBytes(bytes, 360))!;
    expect(out.width, 300);
    expect(redCentroid(out).x, closeTo(150, 3));
  });
}
