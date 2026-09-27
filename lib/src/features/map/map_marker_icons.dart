import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Harita işaretleri Google Maps'te resim olarak çizilir. Görünüm, eski flutter_map
/// katmanındaki widget'larla aynı tutuldu (bölge etiketi kartı, darphane noktası);
/// yerleşim halkası sitedeki `/tr/antik-harita` işaretinin aynısı.
class MapMarkerIcons {
  MapMarkerIcons._();

  static final _cache = <String, BitmapDescriptor>{};

  /// Sitedeki darphane rengi (`mintIcon` fillColor).
  static const mintColor = Color(0xFFB7791F);

  /// Sitedeki yerleşim halkası rengi (`locationIcon` strokeColor).
  static const settlementColor = Color(0xFFC0392B);

  static Future<BitmapDescriptor> _render(
    String key,
    Size size,
    double dpr,
    void Function(Canvas canvas) paint,
  ) async {
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
    final icon = BitmapDescriptor.bytes(bytes!.buffer.asUint8List(), imagePixelRatio: dpr);
    _cache[key] = icon;
    return icon;
  }

  /// Bölge etiketi: beyaz %85 zemin, bölge renginde 2 px kenar, 8 px köşe, gölge,
  /// kalın 12 pt yazı (eski `_buildRegionLabels` kartı).
  static Future<BitmapDescriptor> regionLabel(
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

  /// Darphane noktası: dolu daire, beyaz kenar, içinde konum simgesi (eski
  /// `_buildMintMarkers`). [highlighted] = sikkenin kendi darphanesi (büyük, parlak).
  static Future<BitmapDescriptor> mintDot(Color color, double dpr, {bool highlighted = false}) {
    final d = highlighted ? 40.0 : 28.0;
    const margin = 8.0; // parıltı payı
    final size = Size(d + margin * 2, d + margin * 2);
    return _render('mint|${color.toARGB32()}|$highlighted|$dpr', size, dpr, (canvas) {
      final c = Offset(size.width / 2, size.height / 2);
      canvas.drawCircle(
        c,
        d / 2 + (highlighted ? 2 : 0),
        Paint()
          ..color = color.withValues(alpha: 0.4)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, highlighted ? 8 : 4),
      );
      canvas.drawCircle(c, d / 2, Paint()..color = Colors.white);
      canvas.drawCircle(
        c,
        d / 2 - (highlighted ? 3 : 2),
        Paint()..color = highlighted ? color : color.withValues(alpha: 0.9),
      );
      const icon = Icons.location_on;
      final tp = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: highlighted ? 24 : 16,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: Colors.white,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    });
  }

  /// Yerleşim: sitedeki gibi içi boş kırmızı halka (yarıçap 4,5, kalınlık 1,5).
  static Future<BitmapDescriptor> settlementRing(double dpr) {
    const size = Size(14, 14);
    return _render('settlement|$dpr', size, dpr, (canvas) {
      canvas.drawCircle(
        const Offset(7, 7),
        4.5,
        Paint()
          ..color = settlementColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    });
  }
}
