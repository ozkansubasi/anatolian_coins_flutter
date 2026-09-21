import 'package:flutter/material.dart';
import '../numistr_colors.dart';

/// NumisTR ortak widget'ları.
///
/// 2026-09-21 (S26 P2): dosyadaki 21 yardımcıdan 20'si hiçbir yerden
/// çağrılmıyordu ve silindi; yalnız Ana Sayfa'nın kullandığı bölüm başlığı kaldı.

/// Bölüm başlığı: solda başlık, sağda isteğe bağlı eylem ("Tümü", "Daha Fazla").
Widget numSectionHeader({
  required String title,
  String? actionText,
  VoidCallback? onAction,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
}) {
  return Padding(
    padding: padding,
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: numTextPrimary,
            height: 1.3,
          ),
        ),
        if (actionText != null)
          TextButton(
            onPressed: onAction,
            child: Text(actionText),
          ),
      ],
    ),
  );
}
