/// Language Helper
///
/// Provides utilities for handling bilingual content (Turkish/English)
/// Manages alias suffix handling for language-specific content

class LanguageHelper {
  /// Get language code from locale
  /// Returns 'tr' or 'en'
  static String getLanguageCode(String localeCode) {
    if (localeCode.startsWith('tr')) {
      return 'tr';
    } else if (localeCode.startsWith('en')) {
      return 'en';
    }
    return 'tr'; // Default to Turkish
  }

  /// Get language suffix for alias
  /// Returns '-tr' or '-en'
  static String getLanguageSuffix(String localeCode) {
    return '-${getLanguageCode(localeCode)}';
  }

  /// Get Joomla language code
  /// Returns 'tr-TR' or 'en-GB'
  static String getJoomlaLanguageCode(String localeCode) {
    if (localeCode.startsWith('tr')) {
      return 'tr-TR';
    } else if (localeCode.startsWith('en')) {
      return 'en-GB';
    }
    return 'tr-TR'; // Default to Turkish
  }

  /// Add language suffix to alias
  ///
  /// Example:
  /// ```dart
  /// final alias = LanguageHelper.addLanguageSuffix('ephesos', 'tr');
  /// // Returns: 'ephesos-tr'
  /// ```
  static String addLanguageSuffix(String alias, String localeCode) {
    final suffix = getLanguageSuffix(localeCode);

    // Check if suffix already exists
    if (alias.endsWith(suffix)) {
      return alias;
    }

    // Remove other language suffix if present
    final otherSuffix = localeCode.startsWith('tr') ? '-en' : '-tr';
    if (alias.endsWith(otherSuffix)) {
      alias = alias.substring(0, alias.length - 3);
    }

    return '$alias$suffix';
  }

  /// Remove language suffix from alias
  ///
  /// Example:
  /// ```dart
  /// final baseAlias = LanguageHelper.removeLanguageSuffix('ephesos-tr');
  /// // Returns: 'ephesos'
  /// ```
  static String removeLanguageSuffix(String alias) {
    if (alias.endsWith('-tr') || alias.endsWith('-en')) {
      return alias.substring(0, alias.length - 3);
    }
    return alias;
  }

  /// Get base alias without language suffix
  /// Alias for removeLanguageSuffix for clarity
  static String getBaseAlias(String alias) {
    return removeLanguageSuffix(alias);
  }

  /// Check if alias has language suffix
  static bool hasLanguageSuffix(String alias) {
    return alias.endsWith('-tr') || alias.endsWith('-en');
  }

  /// Get the language from alias suffix
  /// Returns 'tr', 'en', or null if no suffix
  static String? getLanguageFromAlias(String alias) {
    if (alias.endsWith('-tr')) {
      return 'tr';
    } else if (alias.endsWith('-en')) {
      return 'en';
    }
    return null;
  }

  /// Convert alias for current locale
  ///
  /// Ensures the alias has the correct language suffix for the current locale.
  /// If alias has no suffix, adds it. If it has wrong suffix, replaces it.
  ///
  /// Example:
  /// ```dart
  /// // Current locale: 'tr'
  /// final trAlias = LanguageHelper.convertAliasForLocale('ephesos-en', 'tr');
  /// // Returns: 'ephesos-tr'
  ///
  /// // Current locale: 'en'
  /// final enAlias = LanguageHelper.convertAliasForLocale('ephesos', 'en');
  /// // Returns: 'ephesos-en'
  /// ```
  static String convertAliasForLocale(String alias, String localeCode) {
    final baseAlias = removeLanguageSuffix(alias);
    return addLanguageSuffix(baseAlias, localeCode);
  }
}
