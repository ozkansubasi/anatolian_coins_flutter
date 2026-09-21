import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../prokit_ui/numistr_colors.dart';

/// Sikke verisini ekranda gösterim biçimine çeviren ortak yardımcılar.
///
/// NEDEN (2026-09-21): sikke detayı, tanıma sonuçları ve listeler aynı ham
/// veriyi ("aezanis", "bronze", -133) farklı biçimlerde — çoğu zaman hiç
/// biçimlemeden ("-133 - -50") — gösteriyordu. Tek kaynak burası.
class CoinFormat {
  CoinFormat._();

  /// TR "MÖ 133 – MÖ 50", EN "133 BC – 50 BC". Veri yoksa null.
  static String? dateRange(int? from, int? to, AppLocalizations l10n) {
    if (from == null && to == null) return null;
    final isEnglish = l10n.locale.languageCode == 'en';
    String one(int y) {
      final era = l10n.translate(y < 0 ? 'bc' : 'ad');
      return isEnglish ? '${y.abs()} $era' : '$era ${y.abs()}';
    }

    if (from == null) return one(to!);
    if (to == null || from == to) return one(from);
    return '${one(from)} – ${one(to)}';
  }

  /// Veri tabanında özel adlar küçük harf gelebiliyor ("aezanis", "smyrna").
  static String titleCase(String s) => s
      .trim()
      .split(RegExp(r'[\s_]+'))
      .where((w) => w.isNotEmpty)
      .map((w) => w[0].toUpperCase() + w.substring(1))
      .join(' ');

  /// "bronze" → "Bronz" (TR) / "Bronze" (EN); bilinmeyen değer baş harfi büyük.
  static String? material(String? raw, AppLocalizations l10n) {
    if (raw == null || raw.trim().isEmpty) return null;
    final key = 'material_${raw.trim().toLowerCase()}';
    final tr = l10n.translate(key);
    return tr == key ? titleCase(raw) : tr;
  }

  /// Materyal noktası rengi.
  static Color materialColor(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'gold':
      case 'au':
        return numMaterialGold;
      case 'silver':
      case 'ar':
        return numMaterialSilver;
      case 'electrum':
      case 'el':
        return const Color(0xFFE5E4E2);
      case 'lead':
      case 'pb':
        return const Color(0xFF3B3B3B);
      default:
        return numMaterialBronze;
    }
  }
}
