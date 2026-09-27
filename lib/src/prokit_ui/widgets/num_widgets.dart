import 'package:flutter/material.dart';
import '../../core/app_typography.dart';
import '../../core/num_colors.dart';

/// NumisTR ortak widget'ları.
///
/// 2026-09-21 (S26 P2): dosyadaki 21 yardımcıdan 20'si hiçbir yerden
/// çağrılmıyordu ve silindi; yalnız Ana Sayfa'nın kullandığı bölüm başlığı kaldı.

/// Bölüm başlığı: solda başlık, sağda isteğe bağlı eylem ("Tümü", "Daha Fazla").
///
/// Renk temadan gelir: başlık eskiden sabit #212121'di ve koyu temada
/// "Antik Bölgeler" / "Editör'den" siyah zeminde görünmüyordu (cihazda ölçüldü).
Widget numSectionHeader({
  required String title,
  String? actionText,
  VoidCallback? onAction,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
}) {
  return Builder(builder: (context) {
    final c = context.numColors;
    return Padding(
      padding: padding,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            // Slogan şeridiyle aynı vitrin yazı tipi (Marcellus tek ağırlık; 18
            // w600 Inter'in yerine 20 — ince harfte aynı ağırlığı verir).
            style: numShowcaseStyle(size: NumTypo.h3.toDouble(), color: c.text),
          ),
          if (actionText != null)
            TextButton(
              onPressed: onAction,
              style: TextButton.styleFrom(foregroundColor: c.accent),
              child: Text(actionText),
            ),
        ],
      ),
    );
  });
}
