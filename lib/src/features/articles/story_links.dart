import 'package:flutter/material.dart';

import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../models/article.dart';

/// Hikâye bağlantıları (28 Kas 2026): sikke detayının Kaynak sekmesi ve harita bilgi ekranı.
///
/// Liste API 1.31.0'dan gelir (`/variants/{id}/articles`, `/locations/{loc}/articles`); sıra sitedeki
/// "İlgili yazılar" ile aynı kuraldır (dönem süzgeci, darphane + hükümdar eşleşmesi önce).
/// Liste boşsa hiçbir şey çizilmez: bağ olmayan sikkede ya da kentte bölüm görünmez.
class StoryLinks extends StatelessWidget {
  final List<Article> stories;

  /// Dokununca: çağıran sayfa ölçüm olayını atar ve yazıyı kendi gezinme kuralıyla açar
  /// (harita tam ekranda önce kapanmalı).
  final void Function(int articleId) onOpen;

  /// Harita kartı için sıkı biçim: küçük yazı, kategori yok. Başlık iki biçimde de en çok 2 satır
  /// (28 Kas, kullanıcı: tek satırda "Kydnos'ta mor yelkenler: Antonius v…" gibi kesiliyordu).
  final bool compact;

  /// Sıkı biçimde listenin üstündeki küçük başlık (Kaynak sekmesinde başlığı kart taşır).
  final String? heading;

  const StoryLinks({
    super.key,
    required this.stories,
    required this.onOpen,
    this.compact = false,
    this.heading,
  });

  @override
  Widget build(BuildContext context) {
    if (stories.isEmpty) return const SizedBox.shrink();
    final c = context.numColors;
    final t = context.numText;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (heading != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(heading!, style: t.caption.copyWith(color: c.textMuted, fontWeight: FontWeight.w600)),
          ),
        for (final s in stories)
          InkWell(
            key: ValueKey('story-${s.id}'),
            onTap: () => onOpen(s.id),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 4 : 8),
              child: Row(
                crossAxisAlignment: compact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  Icon(Icons.auto_stories_outlined, size: compact ? 16 : 18, color: c.accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.title,
                          style: (compact ? t.caption : t.body).copyWith(color: c.text, fontWeight: FontWeight.w600),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (!compact && s.category.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(s.category, style: t.caption.copyWith(color: c.textMuted)),
                        ],
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: compact ? 16 : 20, color: c.textMuted),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
