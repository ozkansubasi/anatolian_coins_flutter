import 'package:purchases_flutter/purchases_flutter.dart';

import '../l10n/app_localizations.dart';

/// Ürünün ücretsiz deneme dönemi (yoksa null).
///
/// Android: varsayılan teklifin ücretsiz aşaması — Google yalnız kullanıcının
/// uygun olduğu teklifleri döndürür, yani görünüyorsa kullanıcı uygundur.
/// iOS: fiyatı 0 olan tanıtım dönemi (uygunluk App Store'da denetlenir).
({int value, PeriodUnit unit})? freeTrialOf(StoreProduct product) {
  final period = product.defaultOption?.freePhase?.billingPeriod;
  if (period != null && period.value > 0) {
    return (value: period.value, unit: period.unit);
  }
  final intro = product.introductoryPrice;
  if (intro != null && intro.price == 0 && intro.periodNumberOfUnits > 0) {
    return (value: intro.periodNumberOfUnits * (intro.cycles > 0 ? intro.cycles : 1), unit: intro.periodUnit);
  }
  return null;
}

/// "7 gün ücretsiz" / "7-day free trial"; desteklenmeyen birimde null.
///
/// Hafta güne çevrilir (M27): App Store'da 7 gün seçeneği yok, teklif "1 hafta"
/// olarak gelir; Android'de aynı teklif 7 gün. İki platform aynı metni göstersin.
String? freeTrialLabel(StoreProduct product, AppLocalizations l10n) {
  final trial = freeTrialOf(product);
  if (trial == null) return null;
  final (key, count) = switch (trial.unit) {
    PeriodUnit.day => ('trial_days', trial.value),
    PeriodUnit.week => ('trial_days', trial.value * 7),
    PeriodUnit.month => ('trial_months', trial.value),
    _ => (null, 0),
  };
  return key == null ? null : l10n.translate(key, params: {'count': '$count'});
}
