import 'package:flutter/material.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'prokit_legal_page.dart';

/// Subscription Agreement / Abonelik Sözleşmesi page
class SubscriptionAgreementPage extends StatelessWidget {
  const SubscriptionAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProkitLegalPage(
      titleKey: 'subscription_agreement',
      lastUpdated: '29.11.2025',
      headerIcon: Icons.workspace_premium,
      headerColor: numMaterialGold,
      sections: const [
        LegalSection(
          titleKey: 'sub_intro_title',
          contentKey: 'sub_intro_content',
          icon: Icons.info_outline,
          iconColor: numInfo,
        ),
        LegalSection(
          titleKey: 'sub_definitions_title',
          contentKey: 'sub_definitions_content',
          bulletKeys: [
            'sub_def_subscription',
            'sub_def_free_tier',
            'sub_def_pro_tier',
            'sub_def_billing_period',
          ],
          icon: Icons.menu_book,
          iconColor: numPrimary,
        ),
        LegalSection(
          titleKey: 'sub_tiers_title',
          contentKey: 'sub_tiers_content',
          subSections: [
            LegalSubSection(
              titleKey: 'sub_free_tier_title',
              contentKey: 'sub_free_tier_content',
            ),
            LegalSubSection(
              titleKey: 'sub_pro_tier_title',
              contentKey: 'sub_pro_tier_content',
            ),
            LegalSubSection(
              titleKey: 'sub_university_tier_title',
              contentKey: 'sub_university_tier_content',
            ),
          ],
          icon: Icons.layers,
          iconColor: numSecondary,
        ),
        LegalSection(
          titleKey: 'sub_payment_title',
          contentKey: 'sub_payment_content',
          bulletKeys: [
            'sub_payment_1',
            'sub_payment_2',
            'sub_payment_3',
            'sub_payment_4',
          ],
          icon: Icons.payment,
          iconColor: numSuccess,
        ),
        LegalSection(
          titleKey: 'sub_renewal_title',
          contentKey: 'sub_renewal_content',
          icon: Icons.autorenew,
          iconColor: numInfo,
        ),
        LegalSection(
          titleKey: 'sub_cancellation_title',
          contentKey: 'sub_cancellation_content',
          bulletKeys: [
            'sub_cancel_1',
            'sub_cancel_2',
            'sub_cancel_3',
            'sub_cancel_4',
          ],
          icon: Icons.cancel,
          iconColor: numError,
        ),
        LegalSection(
          titleKey: 'sub_refund_title',
          contentKey: 'sub_refund_content',
          icon: Icons.money_off,
          iconColor: numWarning,
        ),
        LegalSection(
          titleKey: 'sub_changes_title',
          contentKey: 'sub_changes_content',
          icon: Icons.edit,
          iconColor: numPrimary,
        ),
        LegalSection(
          titleKey: 'sub_suspension_title',
          contentKey: 'sub_suspension_content',
          icon: Icons.pause_circle,
          iconColor: numWarning,
        ),
        LegalSection(
          titleKey: 'sub_limitation_title',
          contentKey: 'sub_limitation_content',
          icon: Icons.warning_amber,
          iconColor: numError,
        ),
      ],
    );
  }
}
