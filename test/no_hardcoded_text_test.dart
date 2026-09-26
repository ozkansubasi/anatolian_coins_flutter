// Koda gömülü arayüz metni koruması (M3).
//
// Kural: kullanıcıya görünen her metin assets/l10n/<dil>.json'da anahtar olarak
// durur. Bu test lib/ altında Türkçe karakter içeren metin sabiti bulursa düşer
// (log satırları ve yorumlar hariç). İngilizce gömülü metni karakterden ayırt
// etmek mümkün değil; onu kod incelemesi yakalar.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _turkish = RegExp(r'[çğıöşüÇĞİÖŞÜ]');
final _stringLiteral = RegExp(r"""(?<![A-Za-z0-9_])(['"])((?:\\.|(?!\1).)*?)\1""");

/// Satır sonundaki `//` yorumunu atar (metin sabitinin içindeki `//` korunur).
String _stripComment(String line) {
  var inString = false;
  String? quote;
  for (var i = 0; i < line.length - 1; i++) {
    final ch = line[i];
    if (inString) {
      if (ch == r'\') {
        i++;
      } else if (ch == quote) {
        inString = false;
      }
    } else if (ch == "'" || ch == '"') {
      inString = true;
      quote = ch;
    } else if (ch == '/' && line[i + 1] == '/') {
      return line.substring(0, i);
    }
  }
  return line;
}

void main() {
  test('lib/ altında Türkçe metin sabiti yok (l10n dışında)', () {
    final violations = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart') && !f.path.contains('/l10n/'));

    for (final file in files) {
      final lines = file.readAsLinesSync();
      var inLogCall = false;
      for (var i = 0; i < lines.length; i++) {
        final trimmed = lines[i].trim();
        if (trimmed.contains('debugPrint(')) inLogCall = !trimmed.endsWith(');');
        final skip = trimmed.startsWith('//') ||
            trimmed.startsWith('*') ||
            trimmed.contains('debugPrint(') ||
            trimmed.contains('RegExp(') ||
            inLogCall;
        if (inLogCall && trimmed.endsWith(');')) inLogCall = false;
        if (skip) continue;

        final code = _stripComment(lines[i]);
        for (final m in _stringLiteral.allMatches(code)) {
          if (_turkish.hasMatch(m.group(2)!)) {
            violations.add('${file.path}:${i + 1}: $trimmed');
            break;
          }
        }
      }
    }

    expect(violations, isEmpty,
        reason: 'Metni assets/l10n/*.json\'a anahtar olarak taşıyın:\n${violations.join('\n')}');
  });
}
