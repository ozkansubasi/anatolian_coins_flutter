import 'package:flutter/material.dart';
import 'num_colors.dart';

/// NumisTR punto ölçeği — anlamsal roller, renk temadan.
///
/// NEDEN (S26 P2, 2026-09-21): ekranlarda 11 farklı punto (8–28) ve aynı rol
/// için farklı ağırlıklar vardı; sikke detayında sekme etiketleri taşıyor,
/// kart başlığı ile gövde aynı boyda duruyordu. Ekran kodu artık boyut SEÇMEZ,
/// rol seçer: `Text('…', style: context.numText.section)`.
///
/// Ölçek (Inter): 24 · 20 · 16 · 14 · 12 · 11. Ara değer yok.
/// Renk gerekiyorsa `.copyWith(color: …)`; varsayılanlar iki temada da okunur.
@immutable
class NumText {
  final NumColors _c;
  const NumText._(this._c);

  /// 24/700 — öne çıkan başlık (boş durum başlığı, hero).
  TextStyle get display => TextStyle(
      fontSize: 24, fontWeight: FontWeight.w700, height: 1.25, letterSpacing: -0.3, color: _c.text);

  /// 20/700 — sayfanın ana başlığı (sikke adı, makale başlığı).
  TextStyle get pageTitle => TextStyle(
      fontSize: 20, fontWeight: FontWeight.w700, height: 1.3, letterSpacing: -0.2, color: _c.text);

  /// 16/600 — kart ve bölüm başlığı.
  TextStyle get section =>
      TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.35, color: _c.text);

  /// 14/400 — okunan paragraf (tanım, açıklama, kaynak metni).
  TextStyle get body =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w400, height: 1.55, color: _c.text);

  /// 14/500 — alan değeri (Darphane: Aizanoi).
  TextStyle get value =>
      TextStyle(fontSize: 14, fontWeight: FontWeight.w500, height: 1.4, color: _c.text);

  /// 12/500 — alan etiketi, meta (Darphane, Dönem).
  TextStyle get label => TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500, height: 1.35, letterSpacing: 0.2, color: _c.textMuted);

  /// 12/400 — yardımcı metin, tarih, ipucu.
  TextStyle get caption =>
      TextStyle(fontSize: 12, fontWeight: FontWeight.w400, height: 1.4, color: _c.textMuted);

  /// 11/600 — küçük etiket/rozet, bölüm işareti (Ön Yüz / Arka Yüz).
  /// Büyük harfe ÇEVRİLMEZ (Dart `toUpperCase` Türkçe `i`yi bozar); aralık yeter.
  TextStyle get tag => TextStyle(
      fontSize: 11, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0.6, color: _c.accent);

  /// 12/600 — sekme etiketi.
  TextStyle get tab =>
      const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 1.2, letterSpacing: 0.1);
}

extension NumTextContext on BuildContext {
  /// Temaya göre punto rolleri. Tema değişince çağıran widget yeniden çizilir.
  NumText get numText => NumText._(numColors);
}
