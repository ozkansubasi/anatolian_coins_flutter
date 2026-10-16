import '../../l10n/app_localizations.dart';
import 'recognition_service.dart';

/// M28 (ADR-009 K5) — "Fotoğraftaki para … gibi görünüyor" cümlesi. OCR'ın okuyamadığı parça
/// (değer / yıl) cümleden çıkar; birim de yoksa cümle hiç kurulmaz (null). Tarama hakkından söz
/// edilmez (proje sahibi kararı, 2026-10-15) — muafiyet sunucuda uygulanır.
String? modernCoinSentence(AppLocalizations l10n, ModernCoin? coin) {
  if (coin == null || coin.unit == null) return null;
  final unitKey = 'modern_unit_${coin.unit}';
  final unitText = l10n.translate(unitKey);
  final unit = unitText == unitKey ? coin.unit! : unitText;
  final den = coin.denomination;
  final value = den == null ? null : (den == den.roundToDouble() ? den.toInt().toString() : den.toString());
  final year = coin.year?.toString();

  final key = switch ((value != null, year != null)) {
    (true, true) => 'modern_coin_seen_full',
    (true, false) => 'modern_coin_seen_value',
    (false, true) => 'modern_coin_seen_year',
    (false, false) => 'modern_coin_seen_unit',
  };
  return l10n.translate(key, params: {
    'unit': unit,
    if (value != null) 'value': value,
    if (year != null) 'year': year,
  });
}
