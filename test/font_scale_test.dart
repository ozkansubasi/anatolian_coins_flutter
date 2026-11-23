// Punto ölçeği tek kaynakta kalsın (2026-11-24 font incelemesi, B adımı).
//
// Ölçek NumText'te: 24 · 20 · 18 · 16 · 14 · 12 · 11. Kodda bundan başka punto yazılırsa bu
// test düşer. İstisnalar aşağıda adıyla ve gerekçesiyle durur; yenisi eklenecekse buraya yazılır.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _scale = <double>{11, 12, 14, 16, 18, 20, 24};

/// dosya adı → izinli ek puntolar
final _exceptions = <String, Set<double>>{
  // Material 3 büyük başlık ölçeği (displayLarge … titleLarge).
  'app_theme.dart': {22, 28, 32, 36, 45, 57},
  // Harita etiketleri: yerleşim testleri bu puntoya göre (map_label_layout_test).
  'ancient_map_widget.dart': {10},
  // Marka yazısı (Cinzel): logo gibi davranır, metin ölçeğine girmez.
  'brand_title.dart': {17},
  'prokit_subscription_page.dart': {22},
};

void main() {
  test('kodda ölçek dışı punto yok', () {
    final pattern = RegExp(
        r'(?:fontSize:\s*|(?:bold|primary|secondary)TextStyle\((?:[^()]|\([^()]*\))*?\bsize:\s*)(\d+(?:\.\d+)?)');
    final off = <String>[];
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final name = f.uri.pathSegments.last;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        for (final m in pattern.allMatches(lines[i])) {
          final v = double.parse(m.group(1)!);
          if (_scale.contains(v) || (_exceptions[name]?.contains(v) ?? false)) continue;
          off.add('${f.path}:${i + 1} → $v');
        }
      }
    }
    expect(off, isEmpty, reason: 'NumText ölçeğine taşı ya da gerekçesiyle istisna ekle');
  });
}
