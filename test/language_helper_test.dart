import 'package:flutter_test/flutter_test.dart';
import 'package:anatolian_coins/src/core/language_helper.dart';

void main() {
  group('LanguageHelper', () {
    group('getLanguageCode', () {
      test('returns tr for Turkish locale', () {
        expect(LanguageHelper.getLanguageCode('tr'), 'tr');
        expect(LanguageHelper.getLanguageCode('tr_TR'), 'tr');
      });

      test('returns en for English locale', () {
        expect(LanguageHelper.getLanguageCode('en'), 'en');
        expect(LanguageHelper.getLanguageCode('en_GB'), 'en');
        expect(LanguageHelper.getLanguageCode('en_US'), 'en');
      });

      test('defaults to tr for unknown locales', () {
        expect(LanguageHelper.getLanguageCode('fr'), 'tr');
        expect(LanguageHelper.getLanguageCode('de'), 'tr');
      });
    });

    group('getLanguageSuffix', () {
      test('returns correct suffix', () {
        expect(LanguageHelper.getLanguageSuffix('tr'), '-tr');
        expect(LanguageHelper.getLanguageSuffix('en'), '-en');
      });
    });

    group('getJoomlaLanguageCode', () {
      test('returns correct Joomla codes', () {
        expect(LanguageHelper.getJoomlaLanguageCode('tr'), 'tr-TR');
        expect(LanguageHelper.getJoomlaLanguageCode('en'), 'en-GB');
      });
    });

    group('addLanguageSuffix', () {
      test('adds Turkish suffix', () {
        expect(
          LanguageHelper.addLanguageSuffix('ephesos', 'tr'),
          'ephesos-tr',
        );
      });

      test('adds English suffix', () {
        expect(
          LanguageHelper.addLanguageSuffix('ephesos', 'en'),
          'ephesos-en',
        );
      });

      test('does not add suffix if already present', () {
        expect(
          LanguageHelper.addLanguageSuffix('ephesos-tr', 'tr'),
          'ephesos-tr',
        );
        expect(
          LanguageHelper.addLanguageSuffix('ephesos-en', 'en'),
          'ephesos-en',
        );
      });

      test('replaces wrong language suffix', () {
        expect(
          LanguageHelper.addLanguageSuffix('ephesos-en', 'tr'),
          'ephesos-tr',
        );
        expect(
          LanguageHelper.addLanguageSuffix('ephesos-tr', 'en'),
          'ephesos-en',
        );
      });
    });

    group('removeLanguageSuffix', () {
      test('removes Turkish suffix', () {
        expect(
          LanguageHelper.removeLanguageSuffix('ephesos-tr'),
          'ephesos',
        );
      });

      test('removes English suffix', () {
        expect(
          LanguageHelper.removeLanguageSuffix('ephesos-en'),
          'ephesos',
        );
      });

      test('returns original if no suffix', () {
        expect(
          LanguageHelper.removeLanguageSuffix('ephesos'),
          'ephesos',
        );
      });
    });

    group('hasLanguageSuffix', () {
      test('detects Turkish suffix', () {
        expect(LanguageHelper.hasLanguageSuffix('ephesos-tr'), true);
      });

      test('detects English suffix', () {
        expect(LanguageHelper.hasLanguageSuffix('ephesos-en'), true);
      });

      test('returns false for no suffix', () {
        expect(LanguageHelper.hasLanguageSuffix('ephesos'), false);
      });
    });

    group('getLanguageFromAlias', () {
      test('extracts Turkish', () {
        expect(LanguageHelper.getLanguageFromAlias('ephesos-tr'), 'tr');
      });

      test('extracts English', () {
        expect(LanguageHelper.getLanguageFromAlias('ephesos-en'), 'en');
      });

      test('returns null for no suffix', () {
        expect(LanguageHelper.getLanguageFromAlias('ephesos'), null);
      });
    });

    group('convertAliasForLocale', () {
      test('converts Turkish to English', () {
        expect(
          LanguageHelper.convertAliasForLocale('ephesos-tr', 'en'),
          'ephesos-en',
        );
      });

      test('converts English to Turkish', () {
        expect(
          LanguageHelper.convertAliasForLocale('ephesos-en', 'tr'),
          'ephesos-tr',
        );
      });

      test('adds suffix to base alias', () {
        expect(
          LanguageHelper.convertAliasForLocale('ephesos', 'tr'),
          'ephesos-tr',
        );
        expect(
          LanguageHelper.convertAliasForLocale('ephesos', 'en'),
          'ephesos-en',
        );
      });

      test('handles complex aliases', () {
        expect(
          LanguageHelper.convertAliasForLocale('pompeiopolis-paphlagonia-tr', 'en'),
          'pompeiopolis-paphlagonia-en',
        );
      });
    });
  });
}
