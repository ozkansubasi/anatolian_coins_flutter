import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Localization class for NumisTR app
///
/// Metinler koda gömülmez: her dil `assets/l10n/<dil>.json` dosyasında
/// anahtar → metin olarak durur. Yeni dil = yeni JSON dosyası +
/// [supportedLocales]'e bir satır. Bir dilde eksik anahtar [fallbackLanguage]
/// metnine, o da yoksa anahtarın kendisine düşer.
class AppLocalizations {
  final Locale locale;
  final Map<String, String> _values;
  final Map<String, String> _fallback;

  AppLocalizations(this.locale, this._values, [this._fallback = const {}]);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static const List<Locale> supportedLocales = [
    Locale('tr', ''),
    Locale('en', ''),
  ];

  static const String fallbackLanguage = 'en';

  static final Map<String, Map<String, String>> _cache = {};

  /// `assets/l10n/<languageCode>.json` → anahtar/metin tablosu (önbellekli).
  static Future<Map<String, String>> loadTable(String languageCode) async {
    final cached = _cache[languageCode];
    if (cached != null) return cached;
    // loadString 50 KB üstünü compute() ile ayrı isolate'te çözer; widget
    // testlerinin sahte zamanında bu hiç tamamlanmaz. Bayt okuyup burada çözülür.
    final data = await rootBundle.load('assets/l10n/$languageCode.json');
    final raw = utf8.decode(data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
    final table = (jsonDecode(raw) as Map<String, dynamic>).cast<String, String>();
    return _cache[languageCode] = table;
  }

  static Future<AppLocalizations> load(Locale locale) async {
    final values = await loadTable(locale.languageCode);
    final fallback = locale.languageCode == fallbackLanguage
        ? const <String, String>{}
        : await loadTable(fallbackLanguage);
    return AppLocalizations(locale, values, fallback);
  }

  String translate(String key, {Map<String, String>? params}) {
    String translation = _values[key] ?? _fallback[key] ?? key;

    // Replace parameters if provided
    if (params != null) {
      params.forEach((key, value) {
        translation = translation.replaceAll('{$key}', value);
      });
    }

    return translation;
  }

  // Convenience getters for common translations
  String get appName => translate('app_name');
  String get welcome => translate('welcome');
  String get loading => translate('loading');
  String get error => translate('error');
  String get cancel => translate('cancel');
  String get ok => translate('ok');
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((l) => l.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) => AppLocalizations.load(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
