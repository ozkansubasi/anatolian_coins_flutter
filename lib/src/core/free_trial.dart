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
String? freeTrialLabel(StoreProduct product, AppLocalizations l10n) {
  final trial = freeTrialOf(product);
  if (trial == null) return null;
  final key = switch (trial.unit) {
    PeriodUnit.day => 'trial_days',
    PeriodUnit.week => 'trial_weeks',
    PeriodUnit.month => 'trial_months',
    _ => null,
  };
  return key == null ? null : l10n.translate(key, params: {'count': '${trial.value}'});
}
