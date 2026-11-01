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

  /// Kırpmadan önceki (yönü uygulanmış) görüntü boyutu — tanı logu için.
  final int srcWidth;
  final int srcHeight;

  const ProcessedCapture(this.jpeg, this.sharpness, this.side,
      {this.srcWidth = 0, this.srcHeight = 0});
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
    srcWidth: im.width,
    srcHeight: im.height,
  );
}

/// Görüntüyü [degrees] kadar SAAT YÖNÜNDE döndürür (önizlemedeki `Transform.rotate` ile aynı
/// yön). Döndürülmüş karenin tamamı korunur ve görüntü merkezi çıktının merkezinde kalır:
/// sunucu sikke bölütlemesini karenin ortasından başlatır, uygulama küçük resimleri de ortadan
/// gösterir. Köşelerde açılan boşluk kenarların ortalama rengiyle doldurulur (siyah köşe
/// bölütlemeyi ve ham-kare gömmesini şaşırtmasın). `compute` ile çağrılır.
///
/// 2026-11-01 kök neden: eskiden özgün boyuta kırpılıyordu. Dikey fotoğraf ~90° dönünce kırpma
/// başlangıcı negatif oluyor, `copyCrop` bunu 0'a sıkıştırıyor ve sikke karenin üstüne kayıyordu.
Uint8List rotateImageBytes(Uint8List bytes, double degrees, {int quality = 92}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('image decode failed');
  final out = _rotatedFrame(img.bakeOrientation(decoded), degrees);
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

img.Image _rotatedFrame(img.Image src, double degrees) {
  final d = degrees % 360;
  if (d == 0) return src;
  final rot = img.copyRotate(src.convert(numChannels: 4),
      angle: d, interpolation: img.Interpolation.linear);
  final canvas = img.Image(width: rot.width, height: rot.height);
  img.fill(canvas, color: _borderMean(src));
  img.compositeImage(canvas, rot);
  return canvas;
}

/// Önizlemedeki yakınlaştırma durumu: görüntü kutusunun boyutu ve `InteractiveViewer`
/// dönüşümü (görünüm = içerik × [scale] + ([tx], [ty])).
class PreviewViewport {
  final double viewWidth;
  final double viewHeight;
  final double scale;
  final double tx;
  final double ty;

  const PreviewViewport({
    required this.viewWidth,
    required this.viewHeight,
    required this.scale,
    required this.tx,
    required this.ty,
  });
}

/// Ekranda görünen bölgenin, döndürülmüş tam karedeki piksel dikdörtgeni.
///
/// Görsel kutuya döndürülmeden "contain" ile oturur ve kutu merkezi çevresinde döner; bu yüzden
/// kutu merkezi döndürülmüş karenin merkezine, bir görünüm birimi 1/k piksele karşılık gelir.
/// Görünen bölge görselin dışında kalıyorsa ya da çok küçükse `null` döner (tam kare gider).
({int x, int y, int width, int height})? viewportCropRect({
  required int srcWidth,
  required int srcHeight,
  required int frameWidth,
  required int frameHeight,
  required PreviewViewport viewport,
  int minSide = 64,
}) {
  final v = viewport;
  final k = math.min(v.viewWidth / srcWidth, v.viewHeight / srcHeight);
  double toFrameX(double viewX) =>
      ((viewX - v.tx) / v.scale - v.viewWidth / 2) / k + frameWidth / 2;
  double toFrameY(double viewY) =>
      ((viewY - v.ty) / v.scale - v.viewHeight / 2) / k + frameHeight / 2;
  final x0 = toFrameX(0).clamp(0.0, frameWidth.toDouble()).round();
  final x1 = toFrameX(v.viewWidth).clamp(0.0, frameWidth.toDouble()).round();
  final y0 = toFrameY(0).clamp(0.0, frameHeight.toDouble()).round();
  final y1 = toFrameY(v.viewHeight).clamp(0.0, frameHeight.toDouble()).round();
  if (x1 - x0 < minSide || y1 - y0 < minSide) return null;
  return (x: x0, y: y0, width: x1 - x0, height: y1 - y0);
}

/// Yakınlaştırılmış görünümde görsel [deltaDegrees] dönerken ekran ortasındaki noktanın yerinde
/// kalması için gereken yeni öteleme. Sikke yakınlaştırılmışken döndürülünce ekrandan kaçmasın.
({double tx, double ty}) translationAfterRotation({
  required double viewWidth,
  required double viewHeight,
  required double scale,
  required double tx,
  required double ty,
  required double deltaDegrees,
}) {
  final cx = viewWidth / 2;
  final cy = viewHeight / 2;
  final rx = (cx - tx) / scale - cx;
  final ry = (cy - ty) / scale - cy;
  final a = deltaDegrees * math.pi / 180;
  final nx = rx * math.cos(a) - ry * math.sin(a);
  final ny = rx * math.sin(a) + ry * math.cos(a);
  return (tx: cx - scale * (cx + nx), ty: cy - scale * (cy + ny));
}

/// Taranacak görseli önizlemedeki hale getirir: döndürür, [viewport] verilmişse yalnız ekranda
/// görünen bölgeyi bırakır. Kırpma sıkıştırmadan önce yapıldığı için çözünürlük kaybolmaz.
/// `compute` ile çağrılır.
Uint8List prepareScanImage(Uint8List bytes, double degrees, PreviewViewport? viewport,
    {int quality = 92}) {
  final decoded = img.decodeImage(bytes);
  if (decoded == null) throw const FormatException('image decode failed');
  final src = img.bakeOrientation(decoded);
  final frame = _rotatedFrame(src, degrees);
  if (viewport == null) return Uint8List.fromList(img.encodeJpg(frame, quality: quality));
  final r = viewportCropRect(
    srcWidth: src.width,
    srcHeight: src.height,
    frameWidth: frame.width,
    frameHeight: frame.height,
    viewport: viewport,
  );
  final out =
      r == null ? frame : img.copyCrop(frame, x: r.x, y: r.y, width: r.width, height: r.height);
  return Uint8List.fromList(img.encodeJpg(out, quality: quality));
}

img.Color _borderMean(img.Image im) {
  var r = 0.0, g = 0.0, b = 0.0, n = 0;
  void add(int x, int y) {
    final p = im.getPixel(x, y);
    r += p.r;
    g += p.g;
    b += p.b;
    n++;
  }

  final stepX = math.max(1, im.width ~/ 64);
  final stepY = math.max(1, im.height ~/ 64);
  for (var x = 0; x < im.width; x += stepX) {
    add(x, 0);
    add(x, im.height - 1);
  }
  for (var y = 0; y < im.height; y += stepY) {
    add(0, y);
    add(im.width - 1, y);
  }
  return img.ColorRgb8((r / n).round(), (g / n).round(), (b / n).round());
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
