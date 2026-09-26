import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'src/core/app_log.dart';
import 'src/app_router.dart';
import 'src/l10n/app_localizations.dart';
import 'src/core/locale_provider.dart';
import 'src/core/app_theme.dart';
import 'src/core/app_typography.dart';
import 'src/core/env.dart';
import 'src/features/settings/settings_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Hata günlüğü (bkz. app_log.dart): widget hataları ve yakalanmamış
  // istisnalar logcat'e `[NumisTR]` etiketiyle, release'de de.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    appLog('UI', '${details.exceptionAsString()} | ${details.library ?? '-'}'
        ' | ${details.context?.toDescription() ?? '-'}');
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    appLog('UNCAUGHT', '${error.runtimeType}: $error | '
        '${stack.toString().split('\n').take(3).join(' <- ')}');
    return true;
  };

  // Tipografi seti: nb_utils (ProKit) stil varsayılanlarını tek kaynağa bağlar
  initNumistrTypography();

  // Release build'de debug loglarını tamamen sustur
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Release build dev ortam config'iyle derlenmişse yayına çıkmadan yakala.
  // Prod build: flutter build appbundle --dart-define-from-file=env/prod.json
  // Bilerek print: debugPrint release'de susturuluyor, bu uyarı görünmeli.
  if (kReleaseMode && !Env.isProduction) {
    // ignore: avoid_print
    print(
      'UYARI: Release build DEV ortam ayarlariyla derlendi '
      '(APP_ENV=${Env.environment}, issuer=${Env.oidcIssuer}). '
      'Store yayini icin env/prod.json ile derleyin.',
    );
  }

  // Sistem çubukları: YALNIZ ikon parlaklığı. Renk VERİLMEZ — Android 15'te
  // (API 35) uygulama zaten kenardan kenara çizilir ve Flutter motoru bir renk
  // verildiğinde kullanımdan kalkan Window.setStatusBarColor /
  // setNavigationBarColor'ı çağırır (Play Console "deprecated APIs for
  // edge-to-edge" uyarısı, 2026-09-21).
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // Enable edge-to-edge mode on Android
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
    overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom],
  );

  // Initialize SharedPreferences
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
      ],
      child: const AnatolianCoinsApp(),
    ),
  );
}

class AnatolianCoinsApp extends ConsumerWidget {
  const AnatolianCoinsApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'NumisTR',
      debugShowCheckedModeBanner: false,

      // Theme configuration
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,

      // Localization support
      locale: locale,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      routerConfig: ref.watch(appRouterProvider),

      // Sistem yazı-boyutu ayarını makul aralığa sıkıştır. Cihaz %125+ font
      // ölçeğindeyken tüm tipografi seti şişiyor ve yerleşimler bozuluyordu;
      // %90-110 aralığı erişilebilirlik tercihine kısmen saygı gösterirken
      // tasarım ölçeğini korur.
      builder: (context, child) => MediaQuery.withClampedTextScaling(
        minScaleFactor: 0.9,
        maxScaleFactor: 1.1,
        child: child!,
      ),
    );
  }
}
