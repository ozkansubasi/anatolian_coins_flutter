import 'package:flutter/material.dart';
import '../prokit_ui/numistr_colors.dart';

/// NumisTR anlamsal renkleri — açık ve koyu temada doğru değeri kendisi verir.
///
/// NEDEN (S26 P2, 2026-09-21): ekranlar `numTextPrimary` (#212121) ve
/// `Colors.white` gibi sabitleri doğrudan yazıyordu; tema varsayılanı "sistem"
/// olduğu için telefonu koyu modda olan her kullanıcı siyah zeminde siyah
/// başlık ve bembeyaz kart adaları görüyordu (cihazda ölçüldü).
///
/// Kural: ekran kodu METİN, KART, KENARLIK rengini buradan alır.
/// Marka rengi `numPrimary` buton/rozet ZEMİNİ olarak kalabilir (iki temada da
/// üstündeki beyaz metin okunur); ama altın METİN/İKON için [accent] kullanılır —
/// #8B6914 koyu zeminde yalnız ~3:1.
///
/// Kullanım: `final c = context.numColors;` → `color: c.text`
@immutable
class NumColors extends ThemeExtension<NumColors> {
  /// Ana metin.
  final Color text;

  /// İkincil metin (alt başlık, açıklama, meta).
  final Color textMuted;

  /// İpucu / devre dışı metin, soluk ikon.
  final Color hint;

  /// Kart ve sayfa üstü yüzeyler (açıkta beyaz).
  final Color card;

  /// Kartın içindeki hafif ayrışan yüzey (arama kutusu, çip zemini, yer tutucu).
  final Color surface;

  /// Kart ve alan kenarlıkları.
  final Color border;

  /// Ayraç çizgileri.
  final Color divider;

  /// Altın vurgu METNİ ve İKONU (bağlantı, "Tümü", seçili durum).
  final Color accent;

  /// Kart gölgesi.
  final Color shadow;

  const NumColors({
    required this.text,
    required this.textMuted,
    required this.hint,
    required this.card,
    required this.surface,
    required this.border,
    required this.divider,
    required this.accent,
    required this.shadow,
  });

  static const light = NumColors(
    text: numTextPrimary, // #212121
    textMuted: numTextSecondary, // #757575
    hint: numTextHint, // #BDBDBD
    card: numCardLight, // #FFFFFF
    surface: numSurfaceLight, // #F5F2ED
    border: numBorder, // #E8E8E8
    divider: numDividerColor, // #E0E0E0
    accent: numPrimary, // #8B6914 — fildişinde 5,04:1
    shadow: numShadow,
  );

  static const dark = NumColors(
    text: Color(0xFFEDE6DA), // sıcak kırık beyaz; kart #2D2D2D üzerinde ~11:1
    textMuted: Color(0xFFB5AA9A), // ~5,8:1
    hint: Color(0xFF7D7468),
    card: numCardDark, // #2D2D2D
    surface: numSurfaceDark, // #242424
    border: Color(0xFF3D3A36),
    divider: Color(0xFF3A3632),
    accent: Color(0xFFE8C766), // desatüre altın, koyu zeminde 11:1 (S26 §5.3)
    shadow: Color(0x40000000),
  );

  @override
  NumColors copyWith({
    Color? text,
    Color? textMuted,
    Color? hint,
    Color? card,
    Color? surface,
    Color? border,
    Color? divider,
    Color? accent,
    Color? shadow,
  }) {
    return NumColors(
      text: text ?? this.text,
      textMuted: textMuted ?? this.textMuted,
      hint: hint ?? this.hint,
      card: card ?? this.card,
      surface: surface ?? this.surface,
      border: border ?? this.border,
      divider: divider ?? this.divider,
      accent: accent ?? this.accent,
      shadow: shadow ?? this.shadow,
    );
  }

  @override
  NumColors lerp(covariant NumColors? other, double t) {
    if (other == null) return this;
    return NumColors(
      text: Color.lerp(text, other.text, t)!,
      textMuted: Color.lerp(textMuted, other.textMuted, t)!,
      hint: Color.lerp(hint, other.hint, t)!,
      card: Color.lerp(card, other.card, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      border: Color.lerp(border, other.border, t)!,
      divider: Color.lerp(divider, other.divider, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}

extension NumColorsContext on BuildContext {
  /// Temaya göre anlamsal renkler. Tema değişince çağıran widget yeniden çizilir.
  NumColors get numColors =>
      Theme.of(this).extension<NumColors>() ??
      (Theme.of(this).brightness == Brightness.dark ? NumColors.dark : NumColors.light);
}
