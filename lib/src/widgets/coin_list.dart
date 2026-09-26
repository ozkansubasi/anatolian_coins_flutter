import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../core/coin_format.dart';
import '../core/num_colors.dart';
import '../core/num_text.dart';
import '../core/region_data.dart';
import '../l10n/app_localizations.dart';
import '../models/variant.dart';
import '../prokit_ui/numistr_colors.dart';
import '../features/variants/variants_api.dart';

/// Sikke listeleri için ortak parçalar (2026-09-21).
///
/// Koleksiyon detayı, tarama geçmişi ve tanıma sonuçları aynı satırı üç ayrı
/// kopyayla çiziyordu (çıplak ListTile + Divider, ham "bronze", ölçek dışı
/// w300 yazı). Tek kaynak burası; görünüm sikke detayıyla aynı dilde.

/// İlk görselin URL'si, sikke başına bir kez istenir ve önbellekte kalır.
final coinThumbUrlProvider = FutureProvider.autoDispose.family<String?, int>(
  (ref, articleId) => ref.read(variantsApiProvider).getFirstImageUrl(articleId, wm: true),
);

/// Sikkeleri PARALEL yükler, sırayı korur, yüklenemeyenleri atlar.
/// Eskiden tek tek sırayla bekleniyordu (50 sikkelik geçmiş = 50 ardışık istek).
Future<List<Variant>> loadVariantsInOrder(VariantsApi api, List<int> ids) async {
  final results = await Future.wait(ids.map((id) async {
    try {
      return await api.getVariant(id);
    } catch (e) {
      debugPrint('Failed to load variant $id: $e');
      return null;
    }
  }));
  return results.whereType<Variant>().toList();
}

/// "Frigya · Bronz · MÖ 133 – MÖ 50" — boş parçalar atlanır.
String coinMetaLine(Variant v, AppLocalizations l10n) {
  final region = RegionData.getRegionName(v.regionCode, l10n);
  return [
    if (region != '-') region,
    if (CoinFormat.material(v.material, l10n) case final m?) m,
    if (CoinFormat.dateRange(v.dateFrom, v.dateTo, l10n) case final d?) d,
  ].join(' · ');
}

/// Sikke görseli: beyaz fotoğraf plakası (müze fotoğrafları beyaz fonlu).
class CoinThumb extends ConsumerWidget {
  final int articleId;
  final double size;
  const CoinThumb({super.key, required this.articleId, this.size = 56});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final url = ref.watch(coinThumbUrlProvider(articleId)).valueOrNull;
    return _Plate(
      size: size,
      child: url == null
          ? Icon(Icons.monetization_on_outlined, color: numTextHint, size: size * 0.4)
          : CachedNetworkImage(
              imageUrl: url,
              fit: BoxFit.contain,
              errorWidget: (_, __, ___) =>
                  Icon(Icons.image_not_supported_outlined, color: numTextHint, size: size * 0.4),
            ),
    );
  }
}

/// Kullanıcının kendi fotoğrafı (tarama geçmişi).
class CoinPhotoThumb extends StatelessWidget {
  final String? path;
  final double size;
  const CoinPhotoThumb({super.key, required this.path, this.size = 56});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final exists = path != null && File(path!).existsSync();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: exists
          ? Image.file(File(path!), fit: BoxFit.cover, cacheWidth: (size * 3).round(),
              errorBuilder: (_, __, ___) => Icon(Icons.image_outlined, color: c.hint))
          : Icon(Icons.image_outlined, color: c.hint),
    );
  }
}

class _Plate extends StatelessWidget {
  final double size;
  final Widget child;
  const _Plate({required this.size, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.numColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

/// Satırları tek kartta toplar (ince kenarlık, radius 16).
class CoinRowCard extends StatelessWidget {
  final List<Widget> children;
  const CoinRowCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    return Container(
      decoration: BoxDecoration(
        color: c.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }
}

/// Sikke satırı: görsel · başlık + meta · sağ öğe. Dokunma hedefi ≥ 72 dp.
class CoinRow extends StatelessWidget {
  final Widget leading;
  final String title;
  final String? meta;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool last;

  /// Soluk başlık (ör. eşleşmesi olmayan tarama — tıklanamaz olduğu görülsün).
  final bool dim;

  const CoinRow({
    super.key,
    required this.leading,
    required this.title,
    this.meta,
    this.trailing,
    this.onTap,
    this.last = false,
    this.dim = false,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            leading,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: dim ? t.value.copyWith(color: c.textMuted) : t.value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (meta != null && meta!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta!, style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[const SizedBox(width: 4), trailing!],
          ],
        ),
      ),
    );
  }
}

/// Boş durum: ikon, başlık, açıklama, isteğe bağlı eylem.
class EmptyStateView extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  const EmptyStateView({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.actionIcon,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: c.accent),
            ),
            const SizedBox(height: 20),
            Text(title, style: t.section, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: t.body.copyWith(color: c.textMuted), textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: Icon(actionIcon ?? Icons.arrow_forward),
                label: Text(actionLabel!),
                style: FilledButton.styleFrom(backgroundColor: numPrimary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Onay diyaloğu: tehlikeli eylem düğmesi tema hata rengiyle.
Future<bool> confirmDestructive(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) async {
  final l10n = AppLocalizations.of(context);
  final t = context.numText;
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(title, style: t.section),
      content: Text(message, style: t.body.copyWith(color: ctx.numColors.textMuted)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          style: TextButton.styleFrom(foregroundColor: ctx.numColors.textMuted),
          child: Text(l10n.translate('cancel')),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(backgroundColor: Theme.of(ctx).colorScheme.error),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result == true;
}
