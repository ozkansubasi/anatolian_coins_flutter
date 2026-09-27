import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Çizilmiş işaret: resim + mantıksal boyut + konumun resimdeki yeri (Google Maps `anchor`).
/// Boyut, kent adlarının üst üste binmesini önleyen yerleşimde kullanılır.
class MapIcon {
  final BitmapDescriptor icon;
  final Size size;
  final Offset anchor;

  const MapIcon(this.icon, this.size, [this.anchor = const Offset(0.5, 0.5)]);
}

/// Harita işaretleri Google Maps'te resim olarak çizilir. Bölge etiketi eski flutter_map
/// katmanındaki kartın aynısı; kent işareti sitedeki `/tr/antik-harita` yerleşim halkası +
/// kent adı (`.map-city-label`).
class MapMarkerIcons {
  MapMarkerIcons._();

  static final _cache = <String, MapIcon>{};

  /// Sitedeki yerleşim halkası rengi (`locationIcon` strokeColor).
  static const settlementColor = Color(0xFFC0392B);

  /// Sitedeki kent adı rengi (`.map-city-label`) ve kara zemin rengi (yazı halesi).
  static const cityTextColor = Color(0xFF495057);
  static const landColor = Color(0xFFF3E0C5);

  static Future<MapIcon> _render(
    String key,
    Size size,
    double dpr,
    void Function(Canvas canvas) paint, {
    Offset anchor = const Offset(0.5, 0.5),
  }) async {
    final cached = _cache[key];
    if (cached != null) return cached;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(dpr);
    paint(canvas);
    final image = await recorder
        .endRecording()
        .toImage((size.width * dpr).ceil(), (size.height * dpr).ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final icon = MapIcon(
      BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr),
      size,
      anchor,
    );
    _cache[key] = icon;
    return icon;
  }

  /// Bölge etiketi: beyaz %85 zemin, bölge renginde 2 px kenar, 8 px köşe, gölge,
  /// kalın 12 pt yazı (eski `_buildRegionLabels` kartı).
  static Future<MapIcon> regionLabel(
    String text,
    Color color,
    double dpr, {
    String? fontFamily,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: color, fontFamily: fontFamily),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 104);
    const pad = EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    const margin = 4.0; // gölge payı
    final box = Size(tp.width + pad.horizontal, tp.height + pad.vertical);
    final size = Size(box.width + margin * 2, box.height + margin * 2);
    return _render('label|$text|${color.toARGB32()}|$dpr|$fontFamily', size, dpr, (canvas) {
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(margin, margin, box.width, box.height),
        const Radius.circular(8),
      );
      canvas.drawRRect(
        rrect.shift(const Offset(0, 2)),
        Paint()
          ..color = Colors.black.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawRRect(rrect, Paint()..color = Colors.white.withValues(alpha: 0.85));
      canvas.drawRRect(
        rrect.deflate(1),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      tp.paint(canvas, Offset(margin + pad.left, margin + pad.top));
    });
  }

  /// Sikkenin kendi darphanesi — kentlerden ayrılsın diye sikke biçiminde: altın disk +
  /// koyu kenar + iç halka + tapınak (darphane) simgesi, dışta kırmızı vurgu halkası.
  static const coinHighlightColor = Color(0xFFB03A2E);

  static Future<MapIcon> coinMarker(double dpr) {
    const d = 40.0;
    const margin = 10.0;
    const size = Size(d + margin * 2, d + margin * 2);
    return _render('coin|$dpr', size, dpr, (canvas) {
      final c = Offset(size.width / 2, size.height / 2);
      const r = d / 2;
      canvas.drawCircle(
        c,
        r + 4,
        Paint()
          ..color = coinHighlightColor.withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
      );
      canvas.drawCircle(
        c,
        r + 2,
        Paint()
          ..color = coinHighlightColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.3, -0.35),
            colors: [Color(0xFFF7E3A1), Color(0xFFD4A52A), Color(0xFF9C7412)],
            stops: [0.0, 0.65, 1.0],
          ).createShader(Rect.fromCircle(center: c, radius: r)),
      );
      canvas.drawCircle(
        c,
        r - 1,
        Paint()
          ..color = const Color(0xFF6B4A0A)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        c,
        r - 5,
        Paint()
          ..color = const Color(0xFF8A6A1C).withValues(alpha: 0.7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
      const icon = Icons.account_balance;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 18,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: const Color(0xFF4A3205),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    });
  }

  /// Önemli kent: sitedeki yerleşim halkası (içi boş kırmızı, yarıçap 4,5, kalınlık 1,5) ve
  /// sağında sitedeki kent adı (11 pt, #495057) kara rengi haleyle. Konum halkanın merkezi.
  static Future<MapIcon> cityMarker(String name, double dpr, {String? fontFamily}) {
    TextPainter painter(Paint? halo) => TextPainter(
          text: TextSpan(
            text: name,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              fontFamily: fontFamily,
              color: halo == null ? cityTextColor : null,
              foreground: halo,
            ),
          ),
          textDirection: TextDirection.ltr,
          maxLines: 1,
        )..layout();
    final text = painter(null);
    final halo = painter(Paint()
      ..color = landColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeJoin = StrokeJoin.round);
    const ring = 14.0;
    const pad = 2.0; // hale payı
    final height = math.max(ring, text.height + pad * 2);
    final size = Size(ring + text.width + pad * 2, height);
    final center = Offset(ring / 2, height / 2);
    return _render(
      'city|$name|$dpr|$fontFamily',
      size,
      dpr,
      (canvas) {
        canvas.drawCircle(center, 5.5, Paint()..color = landColor.withValues(alpha: 0.7));
        canvas.drawCircle(
          center,
          4.5,
          Paint()
            ..color = settlementColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
        final at = Offset(ring + pad, (height - text.height) / 2);
        halo.paint(canvas, at);
        text.paint(canvas, at);
      },
      anchor: Offset(center.dx / size.width, 0.5),
    );
  }
}
