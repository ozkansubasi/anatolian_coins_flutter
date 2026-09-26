import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import '../../core/coin_format.dart';
import '../../core/navigation.dart';
import '../../core/num_colors.dart';
import '../../core/num_text.dart';
import '../../core/region_data.dart';
import 'recognition_service.dart';
import '../history/scan_history_service.dart';
import '../../widgets/coin_list.dart';
import '../settings/settings_provider.dart';

/// Tanıma sonuçları (2026-09-21 yeniden tasarım, sikke detayıyla aynı dil).
///
/// Düzen: taranan sikke (kullanıcının fotoğrafı) → en yakın eşleşme (tek büyük
/// kart) → diğer olasılıklar (sade satırlar). Eski ekran "en iyi eşleşme"yi dört
/// kez söylüyordu (bant, sayaç, şerit, altın "1" rozeti), kullanıcının kendi
/// fotoğrafını hiç göstermiyordu, dönemi "-133 - -50" diye basıyordu ve geçerli
/// bir %55 eşleşmeyi hata kırmızısıyla boyuyordu.
class ProkitRecognitionResultsScreen extends ConsumerStatefulWidget {
  final dynamic imageData;

  const ProkitRecognitionResultsScreen({
    super.key,
    required this.imageData,
  });

  @override
  ConsumerState<ProkitRecognitionResultsScreen> createState() =>
      _ProkitRecognitionResultsScreenState();
}

class _ProkitRecognitionResultsScreenState
    extends ConsumerState<ProkitRecognitionResultsScreen> {
  late final File _obverseFile;
  File? _reverseFile;
  Map<String, String> _attrs = const {};

  @override
  void initState() {
    super.initState();
    if (widget.imageData is Map) {
      final map = widget.imageData as Map<String, dynamic>;
      _obverseFile = File(map['obverse'] as String);
      final reversePath = map['reverse'] as String?;
      _reverseFile = reversePath != null ? File(reversePath) : null;
      // Faz B: istege bagli nitelikler (metal / agirlik / cap)
      _attrs = RecognitionService.attrFields(
        metal: map['metal'] as String?,
        weightG: map['weight_g'] as String?,
        diameterMm: map['diameter_mm'] as String?,
      );
    } else {
      _obverseFile = File(widget.imageData as String);
    }
    Future.microtask(_recognize);
  }

  Future<void> _recognize() async {
    try {
      final notifier = ref.read(recognitionControllerProvider.notifier);
      if (_reverseFile != null) {
        await notifier.recognizeDual(_obverseFile, _reverseFile!, attrs: _attrs);
      } else {
        await notifier.recognize(_obverseFile, attrs: _attrs);
      }
      ref.invalidate(scanQuotaProvider);

      // Başarılı sonucu tarama geçmişine kaydet (hata olsa da akışı bozmaz)
      final result = ref.read(recognitionControllerProvider).value;
      if (result != null) {
        await ref.read(scanHistoryServiceProvider).recordScan(
              obverseImage: _obverseFile,
              reverseImage: _reverseFile,
              response: result,
            );
      }
    } catch (e, stack) {
      debugPrint('Recognition error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = ref.watch(recognitionControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.popOrGoHome(),
        ),
        title: Text(l10n.translate('recognition_results_title')),
        actions: [
          IconButton(
            tooltip: l10n.translate('help'),
            icon: const Icon(Icons.help_outline),
            onPressed: () => _showHelpDialog(l10n),
          ),
        ],
      ),
      body: recognitionState.when(
        data: (results) => _buildResults(results, l10n),
        loading: () => _buildLoading(l10n),
        error: (error, _) => _buildError(error, l10n),
      ),
    );
  }

  // --- Durumlar --------------------------------------------------------------

  Widget _buildLoading(AppLocalizations l10n) {
    final t = context.numText;
    final c = context.numColors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Kullanıcının kendi fotoğrafı, etrafında ilerleme halkası
            SizedBox(
              width: 132,
              height: 132,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 132,
                    height: 132,
                    child: CircularProgressIndicator(strokeWidth: 3, color: c.accent),
                  ),
                  ClipOval(
                    child: Image.file(_obverseFile,
                        width: 116, height: 116, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Icon(Icons.monetization_on, size: 56, color: c.hint)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Text(l10n.translate('analyzing_coin'), style: t.section, textAlign: TextAlign.center),
            const SizedBox(height: 6),
            Text(l10n.translate('analyzing_wait'), style: t.caption, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildError(Object error, AppLocalizations l10n) {
    final t = context.numText;
    final c = context.numColors;
    // Ham istisna ("DioException [connection timeout]…") kullanıcıya gösterilmez.
    final s = error.toString().toLowerCase();
    final isNetwork = s.contains('socket') ||
        s.contains('timeout') ||
        s.contains('connection') ||
        s.contains('network');
    return _StateMessage(
      icon: isNetwork ? Icons.wifi_off_rounded : Icons.error_outline,
      iconColor: isNetwork ? c.hint : numError,
      title: l10n.translate('recognition_failed'),
      message: l10n.translate(isNetwork ? 'error_network' : 'recognition_error_generic'),
      actions: [
        OutlinedButton.icon(
          onPressed: () => context.popOrGoHome(),
          icon: const Icon(Icons.arrow_back),
          label: Text(l10n.translate('go_back')),
          style: OutlinedButton.styleFrom(
            foregroundColor: c.textMuted,
            side: BorderSide(color: c.border),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.icon(
          // Eski: (map['reverse'] as String) — tek yüzlü taramada null → çöküş.
          onPressed: _recognize,
          icon: const Icon(Icons.refresh),
          label: Text(l10n.translate('retry')),
          style: FilledButton.styleFrom(backgroundColor: numPrimary),
        ),
      ],
      textStyle: t,
    );
  }

  Widget _buildNoResults(AppLocalizations l10n, [String? reason]) {
    final reasonKey = switch (reason) {
      'no_coin_detected' => 'reason_no_coin_detected',
      'low_detail_surface' => 'reason_low_detail_surface',
      'below_confidence' => 'reason_below_confidence',
      _ => null,
    };
    final icon = switch (reason) {
      'no_coin_detected' => Icons.image_search,
      'low_detail_surface' => Icons.texture,
      _ => Icons.search_off,
    };
    return _StateMessage(
      icon: icon,
      iconColor: context.numColors.hint,
      title: l10n.translate(reasonKey ?? 'no_matches'),
      message: l10n.translate(reasonKey != null ? '${reasonKey}_desc' : 'try_clearer_photo'),
      actions: [
        FilledButton.icon(
          onPressed: _scanAnother,
          icon: const Icon(Icons.photo_camera_outlined),
          label: Text(l10n.translate('take_another_photo')),
          style: FilledButton.styleFrom(backgroundColor: numPrimary),
        ),
      ],
      textStyle: context.numText,
    );
  }

  /// Kameraya dön: Tara dalının köküne git. Eski çift `pop()` yığına bağlıydı.
  void _scanAnother() => context.go('/recognition');

  // --- Sonuçlar --------------------------------------------------------------

  Widget _buildResults(RecognitionResponse results, AppLocalizations l10n) {
    final confidenceThreshold = ref.watch(recognitionConfidenceThresholdProvider);
    final topK = ref.watch(recognitionTopKProvider);
    final filterRegion = ref.watch(recognitionFilterRegionProvider);
    final filterMaterial = ref.watch(recognitionFilterMaterialProvider);

    var matches = results.matches.where((m) => m.confidence >= confidenceThreshold).toList();
    if (filterRegion != null) {
      matches = matches
          .where((m) => m.region?.toLowerCase() == filterRegion.toLowerCase())
          .toList();
    }
    if (filterMaterial != null) {
      // Not: eşleşmede materyal alanı yok; süzgeç başlık metnine bakıyor (sınırlı).
      matches = matches
          .where((m) => m.title.toLowerCase().contains(filterMaterial.toLowerCase()))
          .toList();
    }
    if (matches.length > topK) matches = matches.sublist(0, topK);
    if (matches.isEmpty) return _buildNoResults(l10n, results.noMatchReason);

    final t = context.numText;
    final c = context.numColors;
    final isAmbiguous = results.noMatchReason == 'ambiguous_match';
    final others = matches.skip(1).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _ScannedCoinStrip(
                obverse: _obverseFile,
                reverse: _reverseFile,
                label: l10n.translate('scanned_coin'),
                summary: l10n.translate('possible_matches', params: {'n': '${matches.length}'}),
              ),
              const SizedBox(height: 16),

              if (isAmbiguous) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: numWarning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, color: numWarning, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(l10n.translate('reason_ambiguous_match'),
                            style: t.caption.copyWith(color: c.text)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              Text(l10n.translate('closest_match'), style: t.tag),
              const SizedBox(height: 8),
              _TopMatchCard(match: matches.first, l10n: l10n),

              if (others.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(l10n.translate('other_candidates'), style: t.section),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: c.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: c.border),
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < others.length; i++)
                        _CandidateRow(match: others[i], l10n: l10n, last: i == others.length - 1),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
        // Alt eylem
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _scanAnother,
                icon: const Icon(Icons.photo_camera_outlined),
                label: Text(l10n.translate('scan_another')),
                style: OutlinedButton.styleFrom(
                  foregroundColor: c.accent,
                  side: BorderSide(color: c.accent),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showHelpDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) {
        final t = context.numText;
        final c = context.numColors;
        Widget section(String title, String text) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.value),
                const SizedBox(height: 6),
                Text(text, style: t.body.copyWith(color: c.textMuted)),
              ],
            );
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Icon(Icons.help_outline, color: c.accent),
              const SizedBox(width: 12),
              Text(l10n.translate('help'), style: t.section),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                section(l10n.translate('help_recognition_title'), l10n.translate('help_recognition_text')),
                const SizedBox(height: 16),
                section(l10n.translate('help_results_title'), l10n.translate('help_results_text')),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(foregroundColor: c.accent),
              child: Text(l10n.translate('close')),
            ),
          ],
        );
      },
    );
  }
}

// --- Parçalar ----------------------------------------------------------------

/// Taranan sikke: kullanıcının ön/arka yüz fotoğrafları + özet.
class _ScannedCoinStrip extends StatelessWidget {
  final File obverse;
  final File? reverse;
  final String label;
  final String summary;
  const _ScannedCoinStrip({
    required this.obverse,
    required this.reverse,
    required this.label,
    required this.summary,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    Widget face(File f) => Container(
          width: 56,
          height: 56,
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: c.border, width: 2),
          ),
          child: ClipOval(
            child: Image.file(f, fit: BoxFit.cover, cacheWidth: 168,
                errorBuilder: (_, __, ___) => Icon(Icons.monetization_on, color: c.hint)),
          ),
        );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          face(obverse),
          if (reverse != null) face(reverse!),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.label),
                const SizedBox(height: 2),
                Text(summary, style: t.value),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konum satırı: "Pamfilya · Aspendos · MÖ 400 – MÖ 350".
String _metaLine(CoinMatch m, AppLocalizations l10n) {
  final parts = <String>[
    if (RegionData.getRegionName(m.region, l10n) case final r when r != '-') r,
    if (m.mintName != null && m.mintName!.isNotEmpty) CoinFormat.titleCase(m.mintName!),
    if (CoinFormat.dateRange(m.dateFrom, m.dateTo, l10n) case final d?) d,
  ];
  return parts.join(' · ');
}

/// Benzerlik çubuğu: tek renk (altın). Eskiden %55'lik geçerli bir eşleşme
/// hata kırmızısıyla boyanıyordu; belirsizlik zaten ayrı uyarıyla bildiriliyor.
class _Similarity extends StatelessWidget {
  final double value;
  final String label;
  final bool compact;
  const _Similarity({required this.value, required this.label, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    final pct = '%${(value * 100).round()}';
    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: LinearProgressIndicator(
        value: value.clamp(0, 1),
        minHeight: compact ? 4 : 6,
        backgroundColor: c.divider,
        color: c.accent,
      ),
    );
    if (compact) {
      return SizedBox(
        width: 56,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(pct, style: t.value.copyWith(color: c.accent)),
            const SizedBox(height: 4),
            bar,
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: t.label),
            const Spacer(),
            Text(pct, style: t.section.copyWith(color: c.accent)),
          ],
        ),
        const SizedBox(height: 6),
        bar,
      ],
    );
  }
}

class _TopMatchCard extends StatelessWidget {
  final CoinMatch match;
  final AppLocalizations l10n;
  const _TopMatchCard({required this.match, required this.l10n});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    final meta = _metaLine(match, l10n);
    final faces = [
      if (match.obverseScore != null)
        '${l10n.translate('obverse')} %${(match.obverseScore! * 100).round()}',
      if (match.reverseScore != null)
        '${l10n.translate('reverse')} %${(match.reverseScore! * 100).round()}',
    ].join('  ·  ');

    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push('/variant/${match.articleId}'),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: c.accent.withValues(alpha: 0.6), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CoinThumb(articleId: match.articleId, size: 104),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(match.title, style: t.section, maxLines: 3, overflow: TextOverflow.ellipsis),
                        if (meta.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(meta, style: t.caption),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _Similarity(value: match.confidence, label: l10n.translate('similarity')),
              if (faces.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(faces, style: t.caption),
              ],
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.translate('view_details'), style: t.value.copyWith(color: c.accent)),
                    Icon(Icons.chevron_right, color: c.accent, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  final CoinMatch match;
  final AppLocalizations l10n;
  final bool last;
  const _CandidateRow({required this.match, required this.l10n, required this.last});

  @override
  Widget build(BuildContext context) {
    final c = context.numColors;
    final t = context.numText;
    final meta = _metaLine(match, l10n);
    return InkWell(
      onTap: () => context.push('/variant/${match.articleId}'),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        decoration: BoxDecoration(
          border: last ? null : Border(bottom: BorderSide(color: c.divider)),
        ),
        child: Row(
          children: [
            CoinThumb(articleId: match.articleId, size: 56),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(match.title, style: t.value, maxLines: 2, overflow: TextOverflow.ellipsis),
                  if (meta.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(meta, style: t.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            _Similarity(value: match.confidence, label: '', compact: true),
          ],
        ),
      ),
    );
  }
}

/// Boş / hata durumu: ikon, başlık, açıklama, eylemler.
class _StateMessage extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final List<Widget> actions;
  final NumText textStyle;
  const _StateMessage({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.actions,
    required this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: iconColor),
            ),
            const SizedBox(height: 20),
            Text(title, style: textStyle.section, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(message, style: textStyle.body.copyWith(color: context.numColors.textMuted),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: actions),
          ],
        ),
      ),
    );
  }
}
