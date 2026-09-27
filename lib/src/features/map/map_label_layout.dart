import 'dart:math' as math;
import 'dart:ui';

/// Web Mercator dünya pikseli (256 px karo) — [zoom]'da iki noktanın ekrandaki uzaklığı
/// bunların farkıdır; görünür alanı bilmeden etiket çakışması hesaplanabilir.
Offset worldPixel(double lat, double lng, double zoom) {
  final scale = 256 * math.pow(2, zoom);
  final s = math.sin(lat * math.pi / 180).clamp(-0.9999, 0.9999);
  return Offset(
    (lng + 180) / 360 * scale,
    (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * scale,
  );
}

/// Adlı işaretleri üst üste bindirmeden yerleştirir: [candidates] öncelik sırasıyla
/// dolaşılır; kutusu bir engelle ya da önce yerleşmiş bir kutuyla çakışan atlanır.
/// Dönen: yerleşenlerin anahtarları.
Set<K> placeLabels<K>(Iterable<MapEntry<K, Rect>> candidates, Iterable<Rect> obstacles, {double spacing = 3}) {
  final taken = [for (final r in obstacles) r.inflate(spacing / 2)];
  final placed = <K>{};
  for (final c in candidates) {
    final box = c.value.inflate(spacing / 2);
    if (taken.any(box.overlaps)) continue;
    taken.add(box);
    placed.add(c.key);
  }
  return placed;
}
