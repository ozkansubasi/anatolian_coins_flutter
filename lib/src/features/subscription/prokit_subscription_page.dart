import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/num_colors.dart';
import '../../core/free_trial.dart';
import '../../core/subscription_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// ProKit-styled subscription/pricing page
/// Modern design with gradient cards and premium aesthetics
class ProkitSubscriptionPage extends ConsumerWidget {
  const ProkitSubscriptionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subscription = ref.watch(subscriptionProvider);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: subscription.isLoading
          ? const Center(child: CircularProgressIndicator(color: numPrimary))
          : subscription.isPro
              ? _buildProActiveView(context, ref, l10n, subscription)
              : _buildUpgradeView(context, ref, l10n),
    );
  }

  Widget _buildProActiveView(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    SubscriptionState subscription,
  ) {
    final c = context.numColors;
    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          pinned: true,
          backgroundColor: numPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: white),
            onPressed: () => GoRouter.of(context).pop(),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Container(
              decoration: const BoxDecoration(gradient: numGoldGradient),
              child: SafeArea(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: white.withAlpha(50),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.verified, size: 60, color: white),
                    ),
                    16.height,
                    Text(
                      l10n.translate('pro_active'),
                      style: boldTextStyle(size: 22, color: white),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                // Validity card
                if (subscription.expiryDate != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: numSuccess.withAlpha(26),
                      borderRadius: radius(16),
                      border: Border.all(color: numSuccess.withAlpha(50)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: numSuccess.withAlpha(50),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.event_available,
                              color: numSuccess),
                        ),
                        16.width,
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.translate('subscription_valid'),
                                style: secondaryTextStyle(
                                    size: 12, color: c.textMuted),
                              ),
                              4.height,
                              Text(
                                l10n.translate('valid_until', params: {
                                  'date': _formatDate(subscription.expiryDate!)
                                }),
                                style:
                                    boldTextStyle(size: 16, color: numSuccess),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                24.height,

                // Features list
                _buildProFeaturesGrid(context, l10n),

                32.height,

                // Manage subscription button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () => _showManageSubscriptionInfo(
                        context, l10n, subscription.managedByStore),
                    icon: const Icon(Icons.settings),
                    label: Text(l10n.translate('manage_subscription')),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: c.accent,
                      side: BorderSide(color: c.accent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: radius(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUpgradeView(
      BuildContext context, WidgetRef ref, AppLocalizations l10n) {
    final offeringsAsync = ref.watch(offeringsProvider);
    final c = context.numColors;

    return CustomScrollView(
      slivers: [
        // Hero Header
        SliverToBoxAdapter(
          child: Container(
            decoration: const BoxDecoration(gradient: numGoldGradient),
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Back button row
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios, color: white),
                          onPressed: () => GoRouter.of(context).pop(),
                        ),
                        const Spacer(),
                        TextButton.icon(
                          onPressed: () => _handleRestore(context, ref, l10n),
                          icon:
                              const Icon(Icons.restore, color: white, size: 18),
                          label: Text(
                            l10n.translate('restore_purchases'),
                            style: primaryTextStyle(size: 12, color: white),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Premium icon
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: white.withAlpha(50),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.workspace_premium,
                        size: 64, color: white),
                  ),
                  20.height,
                  Text(
                    l10n.translate('numistr_pro'),
                    style: boldTextStyle(size: 28, color: white),
                  ),
                  8.height,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      l10n.translate('upgrade_your_collection'),
                      style: primaryTextStyle(
                          size: 14, color: white.withAlpha(200)),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  32.height,
                ],
              ),
            ),
          ),
        ),

        // Pricing Cards
        SliverToBoxAdapter(
          child: Transform.translate(
            offset: const Offset(0, -20),
            child: Container(
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: radiusOnly(topLeft: 24, topRight: 24),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section title
                    Text(
                      l10n.translate('choose_your_plan'),
                      style: boldTextStyle(size: 20, color: c.text),
                    ),
                    8.height,
                    Text(
                      l10n.translate('unlock_all_features'),
                      style: secondaryTextStyle(size: 14, color: c.textMuted),
                    ),
                    24.height,

                    // Pricing cards
                    offeringsAsync.when(
                      data: (offerings) =>
                          _buildPricingCards(context, ref, l10n, offerings),
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(40),
                          child: CircularProgressIndicator(color: numPrimary),
                        ),
                      ),
                      error: (error, _) => _buildPricingError(
                          context, ref, l10n, error.toString()),
                    ),

                    32.height,

                    // Features Section
                    Text(
                      l10n.translate('pro_features'),
                      style: boldTextStyle(size: 20, color: c.text),
                    ),
                    16.height,
                    _buildFeaturesList(context, l10n),

                    32.height,

                    // Comparison Table
                    _buildComparisonCard(context, l10n),

                    16.height,

                    // ADR-006: her iki kademede geçerli güven mesajı
                    _buildTrustCard(context, l10n),

                    // University Student Banner
                    _buildUniversityBanner(context, l10n),

                    24.height,
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildUniversityBanner(BuildContext context, AppLocalizations l10n) {
    return GestureDetector(
      onTap: () => GoRouter.of(context).push('/university-application'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: boxDecorationWithRoundedCorners(
          backgroundColor: numInfo.withAlpha(26),
          borderRadius: radius(12),
          border: Border.all(color: numInfo.withAlpha(80)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: numInfo.withAlpha(50),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.school, color: numInfo, size: 24),
            ),
            16.width,
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.translate('university_subscription'),
                    style: boldTextStyle(size: 14, color: numInfo),
                  ),
                  4.height,
                  Text(
                    l10n.translate('free_for_students'),
                    style: secondaryTextStyle(
                        size: 12, color: context.numColors.textMuted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: numInfo),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingCards(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Offerings? offerings,
  ) {
    if (offerings == null || offerings.current == null) {
      return _buildPricingError(
          context, ref, l10n, l10n.translate('no_products_available'));
    }

    final packages = offerings.current!.availablePackages;
    if (packages.isEmpty) {
      return _buildPricingError(
          context, ref, l10n, l10n.translate('no_products_available'));
    }

    return Column(
      children: packages.map((package) {
        final isPopular = package.packageType == PackageType.annual;
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _buildPricingCard(
            context: context,
            package: package,
            l10n: l10n,
            isPopular: isPopular,
            onTap: () => _handlePurchase(context, ref, l10n, package),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPricingCard({
    required BuildContext context,
    required Package package,
    required AppLocalizations l10n,
    required bool isPopular,
    required VoidCallback onTap,
  }) {
    final product = package.storeProduct;
    final title = _getPackageTitle(package, l10n);
    final period = _getPackagePeriod(package, l10n);
    final trial = freeTrialLabel(product, l10n);
    final c = context.numColors;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: boxDecorationWithRoundedCorners(
          backgroundColor: isPopular ? numPrimary : c.card,
          borderRadius: radius(16),
          border: isPopular ? null : Border.all(color: c.border),
          boxShadow: isPopular
              ? [
                  BoxShadow(
                    color: numPrimary.withAlpha(80),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  )
                ]
              : null,
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Plan icon
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: isPopular
                          ? white.withAlpha(50)
                          : numPrimary.withAlpha(26),
                      borderRadius: radius(12),
                    ),
                    child: Icon(
                      _getPackageIcon(package),
                      color: isPopular ? white : c.accent,
                      size: 28,
                    ),
                  ),
                  16.width,

                  // Plan details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: boldTextStyle(
                            size: 18,
                            color: isPopular ? white : c.text,
                          ),
                        ),
                        if (trial != null) ...[
                          4.height,
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: boxDecorationWithRoundedCorners(
                              backgroundColor: isPopular
                                  ? white.withAlpha(50)
                                  : numSuccess.withAlpha(30),
                              borderRadius: radius(6),
                            ),
                            child: Text(
                              trial,
                              style: boldTextStyle(
                                  size: 12,
                                  color: isPopular ? white : numSuccess),
                            ),
                          ),
                        ],
                        4.height,
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              product.priceString,
                              style: boldTextStyle(
                                size: 24,
                                color: isPopular ? white : c.accent,
                              ),
                            ),
                            4.width,
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                period,
                                style: secondaryTextStyle(
                                  size: 12,
                                  color: isPopular
                                      ? white.withAlpha(180)
                                      : c.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Deneme koşulu: süre sonunda ne ödeneceği + iptal (mağaza kuralı)
                        if (trial != null) ...[
                          4.height,
                          Text(
                            l10n.translate('trial_terms', params: {
                              'price': product.priceString,
                              'period': period
                            }),
                            style: secondaryTextStyle(
                              size: 11,
                              color: isPopular
                                  ? white.withAlpha(200)
                                  : c.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Arrow
                  Icon(
                    Icons.arrow_forward_ios,
                    color: isPopular ? white : c.hint,
                    size: 18,
                  ),
                ],
              ),
            ),

            // Best value badge
            if (isPopular)
              Positioned(
                top: 0,
                right: 20,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: boxDecorationWithRoundedCorners(
                    backgroundColor: numMaterialGold,
                    borderRadius: radiusOnly(bottomLeft: 8, bottomRight: 8),
                  ),
                  child: Text(
                    l10n.translate('best_value'),
                    style: boldTextStyle(size: 10, color: numTextPrimary),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeaturesList(BuildContext context, AppLocalizations l10n) {
    final c = context.numColors;
    // ADR-006: her madde gerçek bir Pro farkına karşılık gelir.
    // "Reklamsız" kaldırıldı — uygulamada hiç reklam yok, ayrıcalık değil;
    // ücretsiz taraftaki güven mesajına dönüştü (bkz. _buildTrustCard).
    final features = [
      _Feature(
          Icons.camera_enhance, 'feature_unlimited_recognition', numSecondary),
      _Feature(Icons.all_inclusive, 'feature_unlimited_favorites', numError),
      _Feature(Icons.collections_bookmark, 'feature_unlimited_collections',
          c.accent),
      _Feature(Icons.smart_toy, 'feature_ai_assistant', numWarning),
      _Feature(Icons.high_quality, 'feature_high_res', numSuccess),
      _Feature(Icons.offline_bolt, 'feature_offline_access', numInfo),
    ];

    return Column(
      children: features.map((feature) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: c.card,
              borderRadius: radius(12),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: feature.color.withAlpha(26),
                    borderRadius: radius(10),
                  ),
                  child: Icon(feature.icon, color: feature.color, size: 22),
                ),
                16.width,
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.translate(feature.titleKey),
                        style: boldTextStyle(size: 14, color: c.text),
                      ),
                      4.height,
                      Text(
                        l10n.translate('${feature.titleKey}_desc'),
                        style: secondaryTextStyle(size: 12, color: c.textMuted),
                      ),
                    ],
                  ),
                ),
                8.width, // uzun açıklama ikona yapışıyordu
                const Icon(Icons.check_circle, color: numSuccess, size: 24),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildProFeaturesGrid(BuildContext context, AppLocalizations l10n) {
    // 'expert_support' ve 'no_ads' kaldırıldı (2026-09-21, BACKLOG A15 kararı):
    // uzman desteğinin arkasında akış yok; uygulamada hiç reklam yok, yani
    // "reklamsız" Pro ayrıcalığı değil. Ayrıca çevirileri olmadığı için ekranda
    // ham anahtar olarak görünüyorlardı (cihazda görüldü).
    final c = context.numColors;
    final features = [
      // Tek vurgu rengi (altın); kırmızı/mavi/yeşil ikon zeminleri paletle
      // çakışıyordu (2026-09-26 cihaz incelemesi).
      _Feature(Icons.all_inclusive, 'unlimited_favorites', numPrimary),
      _Feature(Icons.offline_bolt, 'offline_access', numPrimary),
      _Feature(Icons.camera_enhance, 'unlimited_scans', numPrimary),
      _Feature(Icons.high_quality, 'high_res_images', numPrimary),
    ];

    return GridView.builder(
      // padding: zero ŞART — verilmezse GridView MediaQuery'nin üst boşluğunu
      // (durum çubuğu) ekler; başlıkla kartlar arasında ~35 dp boşluk kalıyordu.
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      // 1.5 oranında iki satırlık etiket 10 px taşıyordu.
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.25,
      ),
      itemCount: features.length,
      itemBuilder: (context, index) {
        final feature = features[index];
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: boxDecorationWithRoundedCorners(
            backgroundColor: c.card,
            borderRadius: radius(12),
            border: Border.all(color: c.border),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: feature.color.withAlpha(26),
                  shape: BoxShape.circle,
                ),
                child: Icon(feature.icon, color: feature.color, size: 24),
              ),
              8.height,
              // Flexible: uzun etiket (ör. "Koleksiyon ve tarama geçmişine
              // çevrimdışı erişim") kartı taşırmaz, gerekirse kısalır.
              Flexible(
                child: Text(
                  l10n.translate(feature.titleKey),
                  style: boldTextStyle(size: 12, color: c.text),
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// ADR-006: "Reklamsız deneyim" bir Pro ayrıcalığı olarak satılamaz — uygulamada
  /// hiç reklam yok (pubspec'te reklam paketi, kodda tek çağrı yok). Üç madde de
  /// doğrulanmış olgudur; fotoğrafların saklanmadığı 2026-08-30'da sunucuda ölçüldü.
  Widget _buildTrustCard(BuildContext context, AppLocalizations l10n) {
    final c = context.numColors;
    final items = [
      ('trust_no_ads', Icons.block),
      ('trust_no_data_sale', Icons.lock_outline),
      ('trust_no_photo_storage', Icons.no_photography_outlined),
    ];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: c.card,
        borderRadius: radius(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.translate('trust_title'),
            style: boldTextStyle(size: 14, color: c.text),
          ),
          12.height,
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(item.$2, size: 18, color: numSuccess),
                  10.width,
                  Expanded(
                    child: Text(
                      l10n.translate(item.$1),
                      style: secondaryTextStyle(size: 13, color: c.textMuted),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonCard(BuildContext context, AppLocalizations l10n) {
    final c = context.numColors;
    return Container(
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: c.card,
        borderRadius: radius(16),
        border: Border.all(color: c.border),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: boxDecorationWithRoundedCorners(
              backgroundColor: c.surface,
              borderRadius: radiusOnly(topLeft: 16, topRight: 16),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(l10n.translate('feature'),
                      style: boldTextStyle(size: 14, color: c.text)),
                ),
                Expanded(
                  child: Text(
                    l10n.translate('free_tier'),
                    style: secondaryTextStyle(size: 12, color: c.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ),
                Expanded(
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: numPrimary,
                      borderRadius: radius(8),
                    ),
                    child: Text(
                      l10n.translate('pro_tier'),
                      style: boldTextStyle(size: 12, color: white),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Rows
          _buildComparisonRow(c, l10n.translate('coin_catalog'), true, true),
          _buildComparisonRow(c, l10n.translate('search_filter'), true, true),
          // ADR-005: tarama satırı "Sınırsız" DEĞİL — adil kullanım tavanı var.
          _buildComparisonRow(c, l10n.translate('monthly_scans'), '10',
              l10n.translate('high_capacity')),
          _buildComparisonRow(c, l10n.translate('favorites'), '10',
              l10n.translate('unlimited')),
          _buildComparisonRow(c, l10n.translate('collections'), '1',
              l10n.translate('unlimited')),
          _buildComparisonRow(
              c,
              l10n.translate('comparison_ai_assistant'),
              l10n.translate('assistant_free_daily'),
              l10n.translate('assistant_pro_daily')),
          _buildComparisonRow(c, l10n.translate('offline'), false, true),
          _buildComparisonRow(
              c, l10n.translate('comparison_high_res'), false, true,
              isLast: true),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(
      NumColors c, String feature, dynamic freeValue, dynamic proValue,
      {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: c.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child:
                Text(feature, style: primaryTextStyle(size: 14, color: c.text)),
          ),
          Expanded(
            child: _buildComparisonValue(c, freeValue, false),
          ),
          Expanded(
            child: _buildComparisonValue(c, proValue, true),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonValue(NumColors c, dynamic value, bool isPro) {
    if (value is bool) {
      return Icon(
        value ? Icons.check_circle : Icons.cancel,
        color: value ? numSuccess : c.hint,
        size: 20,
      );
    }
    return Text(
      value.toString(),
      style: isPro
          ? boldTextStyle(size: 12, color: c.accent)
          : secondaryTextStyle(size: 12, color: c.textMuted),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildPricingError(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    String error,
  ) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numError.withAlpha(26),
        borderRadius: radius(12),
        border: Border.all(color: numError.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline, color: numError, size: 48),
          12.height,
          Text(
            l10n.translate('products_load_error'),
            style: boldTextStyle(size: 16, color: numError),
          ),
          8.height,
          Text(
            error,
            style: secondaryTextStyle(
                size: 12, color: context.numColors.textMuted),
            textAlign: TextAlign.center,
          ),
          16.height,
          ElevatedButton.icon(
            onPressed: () => ref.invalidate(offeringsProvider),
            icon: const Icon(Icons.refresh),
            label: Text(l10n.translate('retry')),
            style: ElevatedButton.styleFrom(
              backgroundColor: numPrimary,
              foregroundColor: white,
            ),
          ),
        ],
      ),
    );
  }

  IconData _getPackageIcon(Package package) {
    switch (package.packageType) {
      case PackageType.monthly:
        return Icons.calendar_month;
      case PackageType.annual:
        return Icons.calendar_today;
      case PackageType.weekly:
        return Icons.date_range;
      case PackageType.lifetime:
        return Icons.all_inclusive;
      default:
        return Icons.star;
    }
  }

  String _getPackageTitle(Package package, AppLocalizations l10n) {
    switch (package.packageType) {
      case PackageType.monthly:
        return l10n.translate('monthly');
      case PackageType.annual:
        return l10n.translate('yearly');
      case PackageType.weekly:
        return l10n.translate('weekly');
      case PackageType.lifetime:
        return l10n.translate('lifetime');
      default:
        return package.storeProduct.title;
    }
  }

  String _getPackagePeriod(Package package, AppLocalizations l10n) {
    switch (package.packageType) {
      case PackageType.monthly:
        return '/${l10n.translate('month')}';
      case PackageType.annual:
        return '/${l10n.translate('year')}';
      case PackageType.weekly:
        return '/${l10n.translate('week')}';
      case PackageType.lifetime:
        return '';
      default:
        return '';
    }
  }

  /// Satın alma / geri yükleme sürerken ikinci bir işlemin başlamasını önler.
  static bool _busy = false;

  /// [message] ile ilerleme penceresi açar, [task] bitince — hata dahil — kapatır.
  ///
  /// Pencere kök navigator'a açılır; sayfa StatefulShellRoute dalında olduğu için
  /// `Navigator.of(context)` dal navigator'ını verir ve pencereyi kapatamaz (M1).
  /// Bu yüzden rota elde tutulur ve tam olarak o rota kaldırılır. Geri tuşu
  /// işlem sürerken pencereyi kapatamaz. İşlem zaten sürüyorsa `null` döner.
  Future<T?> _withProgress<T>(
    BuildContext context,
    String message,
    Future<T> Function() task,
  ) async {
    if (_busy) return null;
    _busy = true;

    final navigator = Navigator.of(context, rootNavigator: true);
    final route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: radius(16)),
          content: Row(
            children: [
              const CircularProgressIndicator(color: numPrimary),
              16.width,
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    );
    navigator.push(route);

    try {
      return await task();
    } finally {
      if (route.isActive) navigator.removeRoute(route);
      _busy = false;
    }
  }

  Future<void> _handlePurchase(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    Package package,
  ) async {
    try {
      final result = await _withProgress(
        context,
        l10n.translate('processing_purchase'),
        () => ref.read(subscriptionProvider.notifier).purchase(package),
      );
      if (result == null) return;

      if (result.success && result.isPro) {
        if (context.mounted) {
          toast(l10n.translate('purchase_success'), bgColor: numSuccess);
        }
      } else if (result.isCancelled) {
        // User cancelled - no message
      } else if (result.errorKey != null) {
        if (context.mounted) {
          toast(l10n.translate(result.errorKey!), bgColor: numError);
        }
      }
    } catch (e) {
      if (context.mounted) {
        toast('${l10n.translate('error')}: $e', bgColor: numError);
      }
    }
  }

  Future<void> _handleRestore(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    try {
      final result = await _withProgress(
        context,
        l10n.translate('restoring_purchases'),
        () => ref.read(subscriptionProvider.notifier).restorePurchases(),
      );
      if (result == null) return;

      if (result.success && result.isPro) {
        if (context.mounted) {
          toast(l10n.translate('restore_success'), bgColor: numSuccess);
        }
      } else if (result.success && !result.isPro) {
        if (context.mounted) {
          toast(l10n.translate('no_purchases_to_restore'));
        }
      } else if (result.errorKey != null) {
        if (context.mounted) {
          toast(l10n.translate(result.errorKey!), bgColor: numError);
        }
      }
    } catch (e) {
      if (context.mounted) {
        toast('${l10n.translate('error')}: $e', bgColor: numError);
      }
    }
  }

  /// Aboneliği yönetme bilgisi — kaynağa göre ayrışır.
  ///
  /// Mağaza aboneliği iOS/Android ayarlarından iptal edilir; web (iyzico)
  /// aboneliği edilemez, kullanıcı numistr.org Hesabım sayfasına yönlendirilir.
  /// Yanlış yönlendirme, iptal edemeyen kullanıcı demek.
  void _showManageSubscriptionInfo(
    BuildContext context,
    AppLocalizations l10n,
    bool managedByStore,
  ) {
    final isTr = Localizations.localeOf(context).languageCode == 'tr';
    final accountUrl = Uri.parse(isTr
        ? 'https://www.numistr.org/tr/hesabim'
        : 'https://www.numistr.org/en/my-account');

    final c = context.numColors;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: radius(16)),
        title: Row(
          children: [
            Icon(Icons.settings, color: c.accent),
            12.width,
            Expanded(
              child: Text(l10n.translate('manage_subscription'),
                  style: boldTextStyle(size: 18, color: c.text)),
            ),
          ],
        ),
        content: Text(
          l10n.translate(managedByStore
              ? 'manage_subscription_info'
              : 'manage_subscription_info_web'),
          style: secondaryTextStyle(size: 14, color: c.textMuted),
        ),
        actions: [
          if (!managedByStore)
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                if (await canLaunchUrl(accountUrl)) {
                  await launchUrl(accountUrl,
                      mode: LaunchMode.externalApplication);
                }
              },
              child: Text(l10n.translate('open_web_account'),
                  style: primaryTextStyle(color: c.accent)),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(l10n.translate('ok'),
                style: primaryTextStyle(color: c.accent)),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }
}

class _Feature {
  final IconData icon;
  final String titleKey;
  final Color color;

  _Feature(this.icon, this.titleKey, this.color);
}
