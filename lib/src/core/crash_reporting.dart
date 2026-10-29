import 'package:sentry_flutter/sentry_flutter.dart';

import 'env.dart';

/// Çökme raporlama — Sentry, AB (Frankfurt) bölgesi, 0.6.3.
///
/// Yalnız hata ve çökme kaydı gider: istisna/çökme ayrıntısı, cihaz modeli, işletim sistemi ve
/// uygulama sürümü. Kullanıcı kimliği, IP adresi, ekran görüntüsü, görünüm ağacı, performans
/// izleme, oturum sayımı, konsol satırları ve yerel olay izleri (dokunma, ağ adresleri) GÖNDERİLMEZ.
/// Gizlilik metni, App Store "Crash Data — kimliğe bağlı değil" ve Play Data safety "Crash logs"
/// beyanları bu ayarlara dayanır; değiştirmeden önce o metinleri de güncelle
/// (test/crash_reporting_test.dart bu sözü korur).
bool get crashReportingEnabled => Env.sentryDsn.isNotEmpty;

void configureCrashReporting(SentryFlutterOptions options) {
  options
    ..dsn = Env.sentryDsn
    ..environment = Env.environment
    ..sendDefaultPii = false
    ..tracesSampleRate = null
    ..enableAutoSessionTracking = false
    ..attachScreenshot = false
    ..attachViewHierarchy = false
    ..enablePrintBreadcrumbs = false
    ..enableAutoNativeBreadcrumbs = false;
}
