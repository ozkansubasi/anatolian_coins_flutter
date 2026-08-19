import 'package:flutter/material.dart';
import 'package:nb_utils/nb_utils.dart';

/// NumisTR tipografi seti — TEK KAYNAK.
///
/// Uygulamadaki tüm yazı boyutları bu ölçekten seçilir; ara değer
/// (13, 15, 17...) KULLANILMAZ. Material tarafı AppTheme.textTheme'den,
/// ProKit/nb_utils tarafı (boldTextStyle/primaryTextStyle/secondaryTextStyle)
/// [initNumistrTypography] ile ayarlanan global varsayılanlardan beslenir.
///
/// Kullanım:
///   Text('başlık', style: boldTextStyle(size: NumTypo.title))
///   Text('gövde', style: primaryTextStyle())        // 16, set varsayılanı
///   Text('not', style: secondaryTextStyle())        // 14, set varsayılanı
class NumTypo {
  NumTypo._();

  /// 10 — çok küçük rozet/etiket
  static const int tiny = 10;

  /// 12 — caption, yardımcı metin (theme: bodySmall/labelMedium)
  static const int caption = 12;

  /// 14 — gövde metni (theme: bodyMedium)
  static const int body = 14;

  /// 16 — vurgulu gövde / alt başlık (theme: bodyLarge/titleMedium)
  static const int subtitle = 16;

  /// 18 — kart/bölüm başlığı
  static const int title = 18;

  /// 20 — ekran içi büyük başlık
  static const int h3 = 20;

  /// 22 — ekran başlığı (theme: titleLarge)
  static const int h2 = 22;

  /// 24 — öne çıkan başlık (theme: headlineSmall)
  static const int h1 = 24;

  /// 28+ — hero/display (theme: headlineMedium ve üstü)
  static const int display = 28;
}

/// nb_utils global tipografi varsayılanlarını NumisTR setine bağlar.
/// main() içinde runApp'ten ÖNCE bir kez çağrılır.
///
/// Bundan sonra size verilmeden yapılan her boldTextStyle()/primaryTextStyle()/
/// secondaryTextStyle() çağrısı bu sete uyar. Font ailesi bilinçli olarak
/// ayarlanmaz: TextStyle'da fontFamily boş kalınca DefaultTextStyle üzerinden
/// AppTheme'in Inter'i miras alınır (ayrı bir aile tanımlamak Inter'i ezerdi).
void initNumistrTypography() {
  textBoldSizeGlobal = NumTypo.subtitle.toDouble(); // 16
  textPrimarySizeGlobal = NumTypo.subtitle.toDouble(); // 16
  textSecondarySizeGlobal = NumTypo.body.toDouble(); // 14

  // ProKit görünümü: başlıklar w600 (AppTheme title/label stilleriyle aynı);
  // nb_utils'in varsayılan w700'ü Inter'de fazla ağır duruyor.
  fontWeightBoldGlobal = FontWeight.w600;
  fontWeightPrimaryGlobal = FontWeight.w400;
  fontWeightSecondaryGlobal = FontWeight.w400;
}
