import 'package:flutter/material.dart';
import 'language_helper.dart';

/// Extensions for Locale to simplify language operations
extension LocaleExtensions on Locale {
  /// Get language code ('tr' or 'en')
  String get languageCode => LanguageHelper.getLanguageCode(toString());

  /// Get language suffix for alias ('-tr' or '-en')
  String get languageSuffix => LanguageHelper.getLanguageSuffix(toString());

  /// Get Joomla language code ('tr-TR' or 'en-GB')
  String get joomlaLanguageCode =>
      LanguageHelper.getJoomlaLanguageCode(toString());

  /// Add language suffix to an alias
  ///
  /// Example:
  /// ```dart
  /// final locale = Locale('tr');
  /// final alias = locale.withSuffix('ephesos');
  /// // Returns: 'ephesos-tr'
  /// ```
  String withSuffix(String alias) {
    return LanguageHelper.addLanguageSuffix(alias, toString());
  }

  /// Convert alias for this locale
  ///
  /// Example:
  /// ```dart
  /// final locale = Locale('en');
  /// final enAlias = locale.convertAlias('ephesos-tr');
  /// // Returns: 'ephesos-en'
  /// ```
  String convertAlias(String alias) {
    return LanguageHelper.convertAliasForLocale(alias, toString());
  }
}
