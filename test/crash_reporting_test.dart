// Çökme raporlamanın gizlilik sözü (0.6.3, Sentry AB bölgesi).
//
// Gizlilik metni, App Store "Crash Data — kimliğe bağlı değil" ve Play Data safety "Crash logs"
// beyanları yalnız hata/çökme kaydı gönderildiğini söylüyor. Bu test o sözü bozan bir ayar
// değişikliğinde düşer — önce beyanları güncelle, sonra testi.

import 'package:flutter_test/flutter_test.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'package:anatolian_coins/src/core/crash_reporting.dart';

void main() {
  test('yalnız hata ve çökme kaydı: kimlik, IP, ekran, performans, oturum, konsol yok', () {
    final options = SentryFlutterOptions();
    configureCrashReporting(options);

    expect(options.sendDefaultPii, isFalse);
    expect(options.tracesSampleRate, isNull);
    expect(options.enableAutoSessionTracking, isFalse);
    expect(options.attachScreenshot, isFalse);
    expect(options.attachViewHierarchy, isFalse);
    expect(options.enablePrintBreadcrumbs, isFalse);
    expect(options.enableAutoNativeBreadcrumbs, isFalse);
    // İstenen kısım açık kalır.
    expect(options.enableNativeCrashHandling, isTrue);
  });

  test('DSN verilmeyen derlemede (testler, dev) çökme raporlama kapalı', () {
    expect(crashReportingEnabled, isFalse);
  });
}
