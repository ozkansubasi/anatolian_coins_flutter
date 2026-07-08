import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Locale state notifier for managing app language
class LocaleNotifier extends StateNotifier<Locale> {
  static const _storage = FlutterSecureStorage();
  static const _key = 'app_locale';

  LocaleNotifier() : super(const Locale('tr', '')) {
    _loadLocale();
  }

  /// Load saved locale from storage
  Future<void> _loadLocale() async {
    try {
      final savedLocale = await _storage.read(key: _key);
      if (savedLocale != null) {
        state = Locale(savedLocale, '');
      }
    } catch (e) {
      debugPrint('Failed to load locale: $e');
    }
  }

  /// Change app locale and persist to storage
  Future<void> setLocale(Locale locale) async {
    state = locale;
    try {
      await _storage.write(key: _key, value: locale.languageCode);
    } catch (e) {
      debugPrint('Failed to save locale: $e');
    }
  }
}

/// Provider for app locale state
final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});
