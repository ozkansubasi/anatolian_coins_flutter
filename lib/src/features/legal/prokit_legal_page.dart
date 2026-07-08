import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// ProKit-styled legal document page template
/// Used for Terms of Service, Privacy Policy, KVKK, Subscription Agreement
class ProkitLegalPage extends ConsumerWidget {
  final String titleKey;
  final String lastUpdated;
  final List<LegalSection> sections;
  final IconData headerIcon;
  final Color headerColor;

  const ProkitLegalPage({
    super.key,
    required this.titleKey,
    required this.lastUpdated,
    required this.sections,
    this.headerIcon = Icons.description,
    this.headerColor = numPrimary,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: numScaffoldLight,
      body: CustomScrollView(
        slivers: [
          // Header
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: headerColor,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios, color: white),
              onPressed: () => GoRouter.of(context).pop(),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [headerColor, headerColor.withAlpha(200)],
                  ),
                ),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: white.withAlpha(50),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(headerIcon, size: 40, color: white),
                      ),
                      12.height,
                      Text(
                        l10n.translate(titleKey),
                        style: boldTextStyle(size: 20, color: white),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Last updated info
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: numInfo.withAlpha(26),
                borderRadius: radius(12),
                border: Border.all(color: numInfo.withAlpha(50)),
              ),
              child: Row(
                children: [
                  Icon(Icons.update, color: numInfo, size: 20),
                  12.width,
                  Expanded(
                    child: Text(
                      '${l10n.translate('last_updated')}: $lastUpdated',
                      style: primaryTextStyle(size: 13, color: numInfo),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Content sections
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) {
                final section = sections[index];
                return _buildSection(context, l10n, section, index);
              },
              childCount: sections.length,
            ),
          ),

          // Footer
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: boxDecorationWithRoundedCorners(
                backgroundColor: numSurfaceLight,
                borderRadius: radius(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.contact_mail, color: numTextHint, size: 32),
                  12.height,
                  Text(
                    l10n.translate('legal_contact_title'),
                    style: boldTextStyle(size: 14, color: numTextPrimary),
                  ),
                  8.height,
                  Text(
                    l10n.translate('legal_contact_desc'),
                    style: secondaryTextStyle(size: 12),
                    textAlign: TextAlign.center,
                  ),
                  12.height,
                  Text(
                    'destek@numistr.org',
                    style: primaryTextStyle(size: 13, color: numPrimary),
                  ),
                ],
              ),
            ),
          ),

          // Bottom padding
          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    AppLocalizations l10n,
    LegalSection section,
    int index,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: numCardLight,
        borderRadius: radius(16),
        border: Border.all(color: numBorder),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: index < 2, // First 2 sections expanded by default
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: section.iconColor.withAlpha(26),
              borderRadius: radius(10),
            ),
            child: Icon(section.icon, color: section.iconColor, size: 20),
          ),
          title: Text(
            l10n.translate(section.titleKey),
            style: boldTextStyle(size: 15, color: numTextPrimary),
          ),
          children: [
            // Section content
            if (section.contentKey != null)
              Text(
                l10n.translate(section.contentKey!),
                style: secondaryTextStyle(size: 13, height: 1.6),
              ),

            // Bullet points
            if (section.bulletKeys != null && section.bulletKeys!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: section.bulletKeys!.map((key) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 6),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: section.iconColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        12.width,
                        Expanded(
                          child: Text(
                            l10n.translate(key),
                            style: secondaryTextStyle(size: 13, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),

            // Sub-sections
            if (section.subSections != null && section.subSections!.isNotEmpty)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: section.subSections!.map((sub) {
                  return Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: boxDecorationWithRoundedCorners(
                      backgroundColor: numSurfaceLight,
                      borderRadius: radius(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.translate(sub.titleKey),
                          style: boldTextStyle(size: 13, color: numTextPrimary),
                        ),
                        8.height,
                        Text(
                          l10n.translate(sub.contentKey),
                          style: secondaryTextStyle(size: 12, height: 1.5),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}

/// Legal section model
class LegalSection {
  final String titleKey;
  final String? contentKey;
  final List<String>? bulletKeys;
  final List<LegalSubSection>? subSections;
  final IconData icon;
  final Color iconColor;

  const LegalSection({
    required this.titleKey,
    this.contentKey,
    this.bulletKeys,
    this.subSections,
    required this.icon,
    this.iconColor = numPrimary,
  });
}

/// Legal sub-section model
class LegalSubSection {
  final String titleKey;
  final String contentKey;

  const LegalSubSection({
    required this.titleKey,
    required this.contentKey,
  });
}
