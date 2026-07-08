import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Settings keys
class SettingsKeys {
  static const String autoSyncFavorites = 'auto_sync_favorites';
  static const String recognitionConfidenceThreshold = 'recognition_confidence_threshold';
  static const String recognitionTopK = 'recognition_top_k';
  static const String recognitionFilterRegion = 'recognition_filter_region';
  static const String recognitionFilterMaterial = 'recognition_filter_material';
  static const String themeMode = 'theme_mode'; // 'light', 'dark', 'system'
}

/// Settings repository for managing app preferences
class SettingsRepository {
  final SharedPreferences _prefs;

  SettingsRepository(this._prefs);

  /// Auto-sync favorites offline (default: true for Pro users)
  bool get autoSyncFavorites => _prefs.getBool(SettingsKeys.autoSyncFavorites) ?? true;

  Future<void> setAutoSyncFavorites(bool value) async {
    await _prefs.setBool(SettingsKeys.autoSyncFavorites, value);
  }

  /// Recognition confidence threshold (default: 0.4 = 40%)
  /// Note: EfficientNet-B3 + FAISS similarity search typically returns 40-60% scores
  double get recognitionConfidenceThreshold =>
      _prefs.getDouble(SettingsKeys.recognitionConfidenceThreshold) ?? 0.4;

  Future<void> setRecognitionConfidenceThreshold(double value) async {
    await _prefs.setDouble(SettingsKeys.recognitionConfidenceThreshold, value);
  }

  /// Recognition top-K results (default: 5)
  int get recognitionTopK => _prefs.getInt(SettingsKeys.recognitionTopK) ?? 5;

  Future<void> setRecognitionTopK(int value) async {
    await _prefs.setInt(SettingsKeys.recognitionTopK, value);
  }

  /// Recognition filter region (default: null = no filter)
  String? get recognitionFilterRegion =>
      _prefs.getString(SettingsKeys.recognitionFilterRegion);

  Future<void> setRecognitionFilterRegion(String? value) async {
    if (value == null) {
      await _prefs.remove(SettingsKeys.recognitionFilterRegion);
    } else {
      await _prefs.setString(SettingsKeys.recognitionFilterRegion, value);
    }
  }

  /// Recognition filter material (default: null = no filter)
  String? get recognitionFilterMaterial =>
      _prefs.getString(SettingsKeys.recognitionFilterMaterial);

  Future<void> setRecognitionFilterMaterial(String? value) async {
    if (value == null) {
      await _prefs.remove(SettingsKeys.recognitionFilterMaterial);
    } else {
      await _prefs.setString(SettingsKeys.recognitionFilterMaterial, value);
    }
  }

  /// Theme mode (default: system)
  ThemeMode get themeMode {
    final value = _prefs.getString(SettingsKeys.themeMode);
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    String value;
    switch (mode) {
      case ThemeMode.light:
        value = 'light';
        break;
      case ThemeMode.dark:
        value = 'dark';
        break;
      case ThemeMode.system:
        value = 'system';
        break;
    }
    await _prefs.setString(SettingsKeys.themeMode, value);
  }
}

/// Shared preferences provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences not initialized. Call initProviders() first.');
});

/// Settings repository provider
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SettingsRepository(prefs);
});

/// Auto-sync favorites setting provider
final autoSyncFavoritesProvider = StateNotifierProvider<AutoSyncFavoritesNotifier, bool>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return AutoSyncFavoritesNotifier(repo);
});

/// Auto-sync favorites state notifier
class AutoSyncFavoritesNotifier extends StateNotifier<bool> {
  final SettingsRepository _repo;

  AutoSyncFavoritesNotifier(this._repo) : super(_repo.autoSyncFavorites);

  Future<void> toggle() async {
    final newValue = !state;
    await _repo.setAutoSyncFavorites(newValue);
    state = newValue;
  }

  Future<void> set(bool value) async {
    await _repo.setAutoSyncFavorites(value);
    state = value;
  }
}

/// Recognition confidence threshold provider
final recognitionConfidenceThresholdProvider =
    StateNotifierProvider<RecognitionConfidenceNotifier, double>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return RecognitionConfidenceNotifier(repo);
});

/// Recognition confidence threshold state notifier
class RecognitionConfidenceNotifier extends StateNotifier<double> {
  final SettingsRepository _repo;

  RecognitionConfidenceNotifier(this._repo)
      : super(_repo.recognitionConfidenceThreshold);

  Future<void> set(double value) async {
    await _repo.setRecognitionConfidenceThreshold(value);
    state = value;
  }
}

/// Recognition top-K provider
final recognitionTopKProvider =
    StateNotifierProvider<RecognitionTopKNotifier, int>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return RecognitionTopKNotifier(repo);
});

/// Recognition top-K state notifier
class RecognitionTopKNotifier extends StateNotifier<int> {
  final SettingsRepository _repo;

  RecognitionTopKNotifier(this._repo) : super(_repo.recognitionTopK);

  Future<void> set(int value) async {
    await _repo.setRecognitionTopK(value);
    state = value;
  }
}

/// Recognition filter region provider
final recognitionFilterRegionProvider =
    StateNotifierProvider<RecognitionFilterRegionNotifier, String?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return RecognitionFilterRegionNotifier(repo);
});

/// Recognition filter region state notifier
class RecognitionFilterRegionNotifier extends StateNotifier<String?> {
  final SettingsRepository _repo;

  RecognitionFilterRegionNotifier(this._repo)
      : super(_repo.recognitionFilterRegion);

  Future<void> set(String? value) async {
    await _repo.setRecognitionFilterRegion(value);
    state = value;
  }

  Future<void> clear() async {
    await set(null);
  }
}

/// Recognition filter material provider
final recognitionFilterMaterialProvider =
    StateNotifierProvider<RecognitionFilterMaterialNotifier, String?>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return RecognitionFilterMaterialNotifier(repo);
});

/// Recognition filter material state notifier
class RecognitionFilterMaterialNotifier extends StateNotifier<String?> {
  final SettingsRepository _repo;

  RecognitionFilterMaterialNotifier(this._repo)
      : super(_repo.recognitionFilterMaterial);

  Future<void> set(String? value) async {
    await _repo.setRecognitionFilterMaterial(value);
    state = value;
  }

  Future<void> clear() async {
    await set(null);
  }
}

/// Theme mode provider
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  final repo = ref.watch(settingsRepositoryProvider);
  return ThemeModeNotifier(repo);
});

/// Theme mode state notifier
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  final SettingsRepository _repo;

  ThemeModeNotifier(this._repo) : super(_repo.themeMode);

  Future<void> set(ThemeMode mode) async {
    await _repo.setThemeMode(mode);
    state = mode;
  }

  Future<void> toggleDarkMode() async {
    final newMode = state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await set(newMode);
  }

  Future<void> setSystem() async {
    await set(ThemeMode.system);
  }
}
