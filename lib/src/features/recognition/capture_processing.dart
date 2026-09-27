import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Kamera çekimini tanımaya hazırlar: kılavuz çemberin çevresinden kare kırpar ve netliği ölçer.
///
/// 2026-09-28 kök neden: çember önizlemenin ~%60'ıydı; 20 mm sikkeyi doldurmak için telefon
/// ~2–3 cm'ye yaklaştırılıyordu, bu mesafe telefonların en kısa odak mesafesinin (7–10 cm)
/// altında → bulanık fotoğraf → eşleşme yok. Artık kullanıcı ~10 cm'de durur, yakınlaştırır;
/// çekilen tam kareden çember bölgesi kırpılır, sikke gönderilen görüntüyü doldurur.

/// Çemberin (paylı) kenarının, çekilen görüntü genişliğine oranı.
///
/// Önizleme kutuya "cover" ile oturur: kare [frameWidth]×[frameHeight] (dikey), kutu
/// [boxWidth]×[boxHeight]. Çember kutunun ortasında, çapı [circleDiameter] (mantıksal px).
/// Görüntü ve önizleme aynı merkezi ve yatay görüş açısını paylaşır; [margin] çekim anındaki
/// küçük kaymaları ve önizleme/çekim en-boy farkını karşılar.
double cropSideFraction({
  required double circleDiameter,
  required double boxWidth,
  required double boxHeight,
  required double frameWidth,
  required double frameHeight,
  double margin = 1.5,
}) {
  final scale = math.max(boxWidth / frameWidth, boxHeight / frameHeight);
  return (circleDiameter * margin / (frameWidth * scale)).clamp(0.2, 1.0).toDouble();
}

class ProcessedCapture {
  final Uint8List jpeg;

  /// Laplace varyansı (gri, 400 px genişlikte). Büyük = net.
  final double sharpness;
  final int side;

  const ProcessedCapture(this.jpeg, this.sharpness, this.side);
}

/// Görüntüyü çözer, yönünü uygular, ortadan [sideFraction]×genişlik kare kırpar
/// (en çok [maxSide] px), netliği ölçer ve JPEG döndürür. `compute` ile ayrı isolate'te çağrılır.
ProcessedCapture processCaptureBytes(Uint8List bytes, double sideFraction, {int maxSide = 1200}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('image decode failed');
  final im = img.bakeOrientation(decoded);
  final short = math.min(im.width, im.height);
  final side = (sideFraction * im.width).round().clamp(64, short);
  final x = ((im.width - side) / 2).round();
  final y = ((im.height - side) / 2).round();
  var crop = img.copyCrop(im, x: x, y: y, width: side, height: side);
  if (crop.width > maxSide) {
    crop = img.copyResize(crop, width: maxSide, height: maxSide, interpolation: img.Interpolation.average);
  }
  return ProcessedCapture(
    Uint8List.fromList(img.encodeJpg(crop, quality: 92)),
    laplacianVariance(crop),
    crop.width,
  );
}

/// Netlik ölçüsü: gri görüntünün Laplace (4 komşu) yanıtının varyansı. Bulanık görüntüde
/// kenarlar yumuşar, yanıt ve varyansı düşer. Ölçek etkisini sabitlemek için 400 px'e indirgenir.
double laplacianVariance(img.Image src) {
  final small = src.width > 400
      ? img.copyResize(src, width: 400, interpolation: img.Interpolation.average)
      : src;
  final w = small.width;
  final h = small.height;
  final lum = List<double>.filled(w * h, 0);
  for (var yy = 0; yy < h; yy++) {
    for (var xx = 0; xx < w; xx++) {
      lum[yy * w + xx] = img.getLuminance(small.getPixel(xx, yy)).toDouble();
    }
  }
  var sum = 0.0;
  var sumSq = 0.0;
  var n = 0;
  for (var yy = 1; yy < h - 1; yy++) {
    for (var xx = 1; xx < w - 1; xx++) {
      final i = yy * w + xx;
      final v = 4 * lum[i] - lum[i - 1] - lum[i + 1] - lum[i - w] - lum[i + w];
      sum += v;
      sumSq += v * v;
      n++;
    }
  }
  if (n == 0) return 0;
  final mean = sum / n;
  return sumSq / n - mean * mean;
}
