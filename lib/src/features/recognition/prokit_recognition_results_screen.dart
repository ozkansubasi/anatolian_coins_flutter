import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'recognition_service.dart';
import '../history/scan_history_service.dart';
import '../variants/variants_api.dart';
import '../settings/settings_provider.dart';

/// ProKit-styled recognition results screen
/// Modern card design with gradient accents and improved UX
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
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      try {
        File obverseFile;
        File? reverseFile;
        var attrs = const <String, String>{};
        if (widget.imageData is Map) {
          final map = widget.imageData as Map<String, dynamic>;
          obverseFile = File(map['obverse'] as String);
          final reversePath = map['reverse'] as String?;
          reverseFile = reversePath != null ? File(reversePath) : null;
          // Faz B: istege bagli nitelikler (metal / agirlik / cap)
          attrs = RecognitionService.attrFields(
            metal: map['metal'] as String?,
            weightG: map['weight_g'] as String?,
            diameterMm: map['diameter_mm'] as String?,
          );
        } else {
          obverseFile = File(widget.imageData as String);
        }
        if (reverseFile != null) {
          debugPrint('Starting dual recognition');
          await ref.read(recognitionControllerProvider.notifier).recognizeDual(
                obverseFile,
                reverseFile,
                attrs: attrs,
              );
        } else {
          debugPrint('Starting single recognition for: ${obverseFile.path}');
          await ref
              .read(recognitionControllerProvider.notifier)
              .recognize(obverseFile, attrs: attrs);
        }
        debugPrint('Recognition completed successfully');
        ref.invalidate(scanQuotaProvider);

        // Başarılı sonucu tarama geçmişine kaydet (hata olsa da akışı bozmaz)
        final result = ref.read(recognitionControllerProvider).value;
        if (result != null) {
          await ref.read(scanHistoryServiceProvider).recordScan(
                obverseImage: obverseFile,
                reverseImage: reverseFile,
                response: result,
              );
        }
      } catch (e, stack) {
        debugPrint('Recognition error: $e');
        debugPrint('Stack trace: $stack');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final recognitionState = ref.watch(recognitionControllerProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: numScaffoldLight,
      body: SafeArea(
        child: recognitionState.when(
          data: (results) => _buildResults(results, l10n),
          loading: () => _buildLoading(l10n),
          error: (error, stack) => _buildError(error, l10n),
        ),
      ),
    );
  }

  Widget _buildLoading(AppLocalizations l10n) {
    return Column(
      children: [
        // Header
        _buildHeader(l10n),

        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Animated coin icon
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    gradient: numGoldGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: numPrimary.withOpacity(0.3),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.monetization_on,
                    size: 60,
                    color: white,
                  ),
                ),
                32.height,
                Text(
                  l10n.translate('analyzing_coin'),
                  style: boldTextStyle(size: 20, color: numTextPrimary),
                ),
                12.height,
                Text(
                  l10n.translate('analyzing_wait'),
                  style: secondaryTextStyle(size: 14, color: numTextSecondary),
                ),
                32.height,
                SizedBox(
                  width: 200,
                  child: LinearProgressIndicator(
                    backgroundColor: numDividerColor,
                    valueColor: const AlwaysStoppedAnimation<Color>(numPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildError(Object error, AppLocalizations l10n) {
    return Column(
      children: [
        // Header
        _buildHeader(l10n),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: numError.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.error_outline, size: 50, color: numError),
                  ),
                  24.height,
                  Text(
                    l10n.translate('recognition_failed'),
                    style: boldTextStyle(size: 20, color: numTextPrimary),
                  ),
                  12.height,
                  Text(
                    error.toString(),
                    textAlign: TextAlign.center,
                    style: secondaryTextStyle(size: 14, color: numTextSecondary),
                  ),
                  32.height,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => GoRouter.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: Text(l10n.translate('go_back')),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: numTextSecondary,
                          side: const BorderSide(color: numBorder),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                      16.width,
                      ElevatedButton.icon(
                        onPressed: _retryRecognition,
                        icon: const Icon(Icons.refresh),
                        label: Text(l10n.translate('retry')),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: numPrimary,
                          foregroundColor: white,
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _retryRecognition() {
    if (widget.imageData is Map) {
      final map = widget.imageData as Map<String, dynamic>;
      ref.read(recognitionControllerProvider.notifier).recognizeDual(
            File(map['obverse'] as String),
            File(map['reverse'] as String),
          );
    } else {
      ref.read(recognitionControllerProvider.notifier).recognize(File(widget.imageData as String));
    }
  }

  Widget _buildResults(RecognitionResponse results, AppLocalizations l10n) {
    final confidenceThreshold = ref.watch(recognitionConfidenceThresholdProvider);
    final topK = ref.watch(recognitionTopKProvider);
    final filterRegion = ref.watch(recognitionFilterRegionProvider);
    final filterMaterial = ref.watch(recognitionFilterMaterialProvider);

    var filteredMatches = results.matches
        .where((match) => match.confidence >= confidenceThreshold)
        .toList();

    if (filterRegion != null) {
      filteredMatches = filteredMatches
          .where((match) => match.region?.toLowerCase() == filterRegion.toLowerCase())
          .toList();
    }

    if (filterMaterial != null) {
      filteredMatches = filteredMatches
          .where((match) {
            final matchTitle = match.title.toLowerCase();
            return matchTitle.contains(filterMaterial.toLowerCase());
          })
          .toList();
    }

    if (filteredMatches.length > topK) {
      filteredMatches = filteredMatches.sublist(0, topK);
    }

    if (filteredMatches.isEmpty) {
      return _buildNoResults(l10n, results.noMatchReason);
    }

    final isAmbiguous = results.noMatchReason == 'ambiguous_match';

    return Column(
      children: [
        // Header
        _buildHeader(l10n),

        // Results info banner
        Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          padding: const EdgeInsets.all(12),
          decoration: boxDecorationWithRoundedCorners(
            backgroundColor: numPrimary.withOpacity(0.1),
            borderRadius: radius(12),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: numPrimary.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.auto_awesome, color: numPrimary, size: 20),
              ),
              12.width,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.translate('showing_top_matches'),
                      style: boldTextStyle(size: 14, color: numPrimary),
                    ),
                    4.height,
                    Text(
                      '${filteredMatches.length} sonuç bulundu',
                      style: secondaryTextStyle(size: 12, color: numTextSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Ambiguity warning (Faz A: dusuk marj)
        if (isAmbiguous)
          Container(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(12),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: numWarning.withOpacity(0.12),
              borderRadius: radius(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, color: numWarning, size: 20),
                12.width,
                Expanded(
                  child: Text(
                    l10n.translate('reason_ambiguous_match'),
                    style: secondaryTextStyle(size: 12, color: numTextSecondary),
                  ),
                ),
              ],
            ),
          ),

        // Results list
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredMatches.length,
            itemBuilder: (context, index) {
              final match = filteredMatches[index];
              return _buildMatchCard(match, index + 1);
            },
          ),
        ),

        // Bottom action
        _buildBottomAction(l10n),
      ],
    );
  }

  Widget _buildNoResults(AppLocalizations l10n, [String? reason]) {
    final reasonKey = switch (reason) {
      'no_coin_detected' => 'reason_no_coin_detected',
      'low_detail_surface' => 'reason_low_detail_surface',
      'below_confidence' => 'reason_below_confidence',
      _ => null,
    };
    final title = reasonKey != null ? l10n.translate(reasonKey) : l10n.translate('no_matches');
    final desc = reasonKey != null
        ? l10n.translate('${reasonKey}_desc')
        : l10n.translate('try_clearer_photo');
    final icon = switch (reason) {
      'no_coin_detected' => Icons.image_search,
      'low_detail_surface' => Icons.texture,
      _ => Icons.search_off,
    };
    return Column(
      children: [
        // Header
        _buildHeader(l10n),

        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: numTextHint.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 50, color: numTextHint),
                  ),
                  24.height,
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: boldTextStyle(size: 20, color: numTextPrimary),
                  ),
                  12.height,
                  Text(
                    desc,
                    textAlign: TextAlign.center,
                    style: secondaryTextStyle(size: 14, color: numTextSecondary),
                  ),
                  32.height,
                  ElevatedButton.icon(
                    onPressed: () => GoRouter.of(context).pop(),
                    icon: const Icon(Icons.camera_alt),
                    label: Text(l10n.translate('take_another_photo')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: numPrimary,
                      foregroundColor: white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: radius(12)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => GoRouter.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios, color: numTextPrimary),
          ),
          Expanded(
            child: Text(
              l10n.translate('recognition_results_title'),
              style: boldTextStyle(size: 18, color: numTextPrimary),
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            onPressed: () => _showHelpDialog(l10n),
            icon: const Icon(Icons.help_outline, color: numTextSecondary),
          ),
        ],
      ),
    );
  }

  AppLocalizations get _l10n => AppLocalizations.of(context);

  Widget _buildMatchCard(CoinMatch match, int rank) {
    final isTopMatch = rank == 1;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: () => context.push('/variant/${match.articleId}'),
        borderRadius: radius(16),
        child: Container(
          decoration: boxDecorationWithRoundedCorners(
            backgroundColor: numCardLight,
            borderRadius: radius(16),
            border: isTopMatch ? Border.all(color: numPrimary, width: 2) : null,
            boxShadow: [
              BoxShadow(
                color: numShadow,
                blurRadius: isTopMatch ? 12 : 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Top match indicator
              if (isTopMatch)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  decoration: boxDecorationWithRoundedCorners(
                    backgroundColor: numPrimary,
                    borderRadius: radiusOnly(topLeft: 14, topRight: 14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.star, color: white, size: 16),
                      8.width,
                      Text(
                        'En İyi Eşleşme',
                        style: boldTextStyle(size: 12, color: white),
                      ),
                    ],
                  ),
                ),

              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rank badge
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _getRankGradient(rank),
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _getRankColor(rank).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$rank',
                          style: boldTextStyle(size: 16, color: white),
                        ),
                      ),
                    ),
                    12.width,

                    // Coin image
                    Container(
                      width: 72,
                      height: 72,
                      decoration: boxDecorationWithRoundedCorners(
                        backgroundColor: numSurfaceLight,
                        borderRadius: radius(12),
                        border: Border.all(color: numBorder),
                      ),
                      child: ClipRRect(
                        borderRadius: radius(11),
                        child: Consumer(
                          builder: (context, ref, _) {
                            final imageUrlFuture = ref.watch(
                              variantsApiProvider
                            ).getFirstImageUrl(match.articleId, wm: true);

                            return FutureBuilder<String?>(
                              future: imageUrlFuture,
                              builder: (context, snapshot) {
                                if (snapshot.hasData && snapshot.data != null) {
                                  return CachedNetworkImage(
                                    imageUrl: snapshot.data!,
                                    fit: BoxFit.cover,
                                    width: 72,
                                    height: 72,
                                    placeholder: (_, __) => const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                    errorWidget: (_, __, ___) => const Icon(
                                      Icons.image_not_supported,
                                      color: numTextHint,
                                    ),
                                  );
                                }
                                return const Icon(
                                  Icons.monetization_on,
                                  size: 32,
                                  color: numTextHint,
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
                    12.width,

                    // Coin info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            match.title,
                            style: boldTextStyle(size: 14, color: numTextPrimary),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          4.height,
                          if (match.regionName != null)
                            _buildInfoRow(Icons.place, match.regionName!),
                          if (match.mintName != null)
                            _buildInfoRow(Icons.location_city, match.mintName!),
                          if (match.dateRange != null)
                            _buildInfoRow(Icons.calendar_today, match.dateRange!),
                          8.height,
                          // Confidence bar
                          _buildConfidenceBar(match.confidence),
                          if (match.obverseScore != null || match.reverseScore != null) ...[
                            4.height,
                            Text(
                              [
                                if (match.obverseScore != null)
                                  '${_l10n.translate('obverse')}: ${(match.obverseScore! * 100).toInt()}%',
                                if (match.reverseScore != null)
                                  '${_l10n.translate('reverse')}: ${(match.reverseScore! * 100).toInt()}%',
                              ].join('  ·  '),
                              style: secondaryTextStyle(size: 11, color: numTextHint),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Arrow
                    const Icon(Icons.chevron_right, color: numTextHint),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Icon(icon, size: 12, color: numTextHint),
          4.width,
          Expanded(
            child: Text(
              text,
              style: secondaryTextStyle(size: 12, color: numTextSecondary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBar(double confidence) {
    final color = _getConfidenceColor(confidence);

    return Row(
      children: [
        Expanded(
          child: Stack(
            children: [
              Container(
                height: 6,
                decoration: boxDecorationWithRoundedCorners(
                  backgroundColor: numDividerColor,
                  borderRadius: radius(3),
                ),
              ),
              FractionallySizedBox(
                widthFactor: confidence,
                child: Container(
                  height: 6,
                  decoration: boxDecorationWithRoundedCorners(
                    backgroundColor: color,
                    borderRadius: radius(3),
                  ),
                ),
              ),
            ],
          ),
        ),
        8.width,
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: boxDecorationWithRoundedCorners(
            backgroundColor: color.withOpacity(0.1),
            borderRadius: radius(8),
          ),
          child: Text(
            '${(confidence * 100).toInt()}%',
            style: boldTextStyle(size: 12, color: color),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomAction(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: boxDecorationWithShadow(
        backgroundColor: numCardLight,
        shadowColor: numShadow,
        blurRadius: 10,
        offset: const Offset(0, -4),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              GoRouter.of(context).pop();
              GoRouter.of(context).pop();
            },
            icon: const Icon(Icons.camera_alt),
            label: Text(l10n.translate('scan_another')),
            style: OutlinedButton.styleFrom(
              foregroundColor: numPrimary,
              side: const BorderSide(color: numPrimary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: radius(12)),
            ),
          ),
        ),
      ),
    );
  }

  List<Color> _getRankGradient(int rank) {
    switch (rank) {
      case 1:
        return [const Color(0xFFFFD700), const Color(0xFFFFA500)]; // Gold
      case 2:
        return [const Color(0xFFC0C0C0), const Color(0xFF909090)]; // Silver
      case 3:
        return [const Color(0xFFCD7F32), const Color(0xFF8B4513)]; // Bronze
      default:
        return [numTextSecondary, numTextHint];
    }
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return numTextSecondary;
    }
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence >= 0.8) return numSuccess;
    if (confidence >= 0.6) return numWarning;
    return numError;
  }

  void _showHelpDialog(AppLocalizations l10n) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Row(
          children: [
            const Icon(Icons.help_outline, color: numPrimary),
            12.width,
            Text(l10n.translate('help'), style: boldTextStyle(size: 18)),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildHelpSection(
                l10n.translate('help_recognition_title'),
                l10n.translate('help_recognition_text'),
              ),
              16.height,
              _buildHelpSection(
                l10n.translate('help_results_title'),
                l10n.translate('help_results_text'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('close'), style: primaryTextStyle(color: numPrimary)),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection(String title, String text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: boldTextStyle(size: 14, color: numTextPrimary)),
        8.height,
        Text(text, style: secondaryTextStyle(size: 14, color: numTextSecondary)),
      ],
    );
  }
}
