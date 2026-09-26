// Ücretsiz deneme gösterimi: Android (varsayılan teklifin ücretsiz aşaması)
// ve iOS (fiyatı 0 olan tanıtım dönemi) ayrı alanlardan gelir.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:anatolian_coins/src/core/free_trial.dart';
import 'package:anatolian_coins/src/l10n/app_localizations.dart';

const _fullPrice = PricingPhase(
  Period(PeriodUnit.month, 1, 'P1M'),
  RecurrenceMode.infiniteRecurring,
  null,
  Price('₺99,99', 99990000, 'TRY'),
  null,
);

SubscriptionOption _option({PricingPhase? free}) => SubscriptionOption(
      'monthly:trial', 'numistr_pro_monthly:monthly', 'numistr_pro_monthly',
      [if (free != null) free, _fullPrice], const [], free == null,
      const Period(PeriodUnit.month, 1, 'P1M'), false, _fullPrice, free, null, null, null,
    );

StoreProduct _product({SubscriptionOption? option, IntroductoryPrice? intro}) => StoreProduct(
      'numistr_pro_monthly', 'Pro', 'Pro', 99.99, '₺99,99', 'TRY',
      defaultOption: option,
      introductoryPrice: intro,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations tr;
  late AppLocalizations en;

  setUpAll(() async {
    tr = await AppLocalizations.load(const Locale('tr'));
    en = await AppLocalizations.load(const Locale('en'));
  });

  test('Android: ücretsiz aşama → 7 gün', () {
    const free = PricingPhase(
      Period(PeriodUnit.day, 7, 'P7D'),
      RecurrenceMode.finiteRecurring,
      1,
      Price('Free', 0, 'TRY'),
      OfferPaymentMode.freeTrial,
    );
    final p = _product(option: _option(free: free));
    expect(freeTrialLabel(p, tr), '7 gün ücretsiz');
    expect(freeTrialLabel(p, en), '7-day free trial');
  });

  test('Android: yalnız taban plan (deneme yok ya da kullanıcı uygun değil)', () {
    expect(freeTrialLabel(_product(option: _option()), tr), isNull);
  });

  test('iOS: fiyatı 0 olan tanıtım dönemi → 1 hafta', () {
    const intro = IntroductoryPrice(0, 'Free', 'P1W', 1, PeriodUnit.week, 1);
    expect(freeTrialLabel(_product(intro: intro), tr), '1 hafta ücretsiz');
  });

  test('iOS: ücretli tanıtım fiyatı deneme sayılmaz', () {
    const intro = IntroductoryPrice(49.99, '₺49,99', 'P1M', 1, PeriodUnit.month, 1);
    expect(freeTrialLabel(_product(intro: intro), tr), isNull);
  });
}
