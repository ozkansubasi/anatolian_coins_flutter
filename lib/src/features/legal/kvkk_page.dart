import 'package:flutter/material.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'prokit_legal_page.dart';

/// KVKK Aydınlatma Metni / Personal Data Protection (Turkish GDPR) page
class KvkkPage extends StatelessWidget {
  const KvkkPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProkitLegalPage(
      titleKey: 'kvkk_title',
      lastUpdated: '30.08.2026',
      headerIcon: Icons.shield,
      headerColor: const Color(0xFF1565C0), // Deep blue for official/legal
      sections: const [
        LegalSection(
          titleKey: 'kvkk_intro_title',
          contentKey: 'kvkk_intro_content',
          icon: Icons.info_outline,
          iconColor: numInfo,
        ),
        LegalSection(
          titleKey: 'kvkk_controller_title',
          contentKey: 'kvkk_controller_content',
          icon: Icons.business,
          iconColor: numPrimary,
        ),
        LegalSection(
          titleKey: 'kvkk_data_categories_title',
          contentKey: 'kvkk_data_categories_content',
          subSections: [
            LegalSubSection(
              titleKey: 'kvkk_identity_data_title',
              contentKey: 'kvkk_identity_data_content',
            ),
            LegalSubSection(
              titleKey: 'kvkk_contact_data_title',
              contentKey: 'kvkk_contact_data_content',
            ),
            LegalSubSection(
              titleKey: 'kvkk_transaction_data_title',
              contentKey: 'kvkk_transaction_data_content',
            ),
            LegalSubSection(
              titleKey: 'kvkk_visual_data_title',
              contentKey: 'kvkk_visual_data_content',
            ),
          ],
          icon: Icons.category,
          iconColor: numSecondary,
        ),
        LegalSection(
          titleKey: 'kvkk_purposes_title',
          contentKey: 'kvkk_purposes_content',
          bulletKeys: [
            'kvkk_purpose_1',
            'kvkk_purpose_2',
            'kvkk_purpose_3',
            'kvkk_purpose_4',
            'kvkk_purpose_5',
          ],
          icon: Icons.track_changes,
          iconColor: numPrimary,
        ),
        LegalSection(
          titleKey: 'kvkk_legal_basis_title',
          contentKey: 'kvkk_legal_basis_content',
          bulletKeys: [
            'kvkk_basis_1',
            'kvkk_basis_2',
            'kvkk_basis_3',
            'kvkk_basis_4',
          ],
          icon: Icons.gavel,
          iconColor: numWarning,
        ),
        LegalSection(
          titleKey: 'kvkk_transfer_title',
          contentKey: 'kvkk_transfer_content',
          bulletKeys: [
            'kvkk_transfer_1',
            'kvkk_transfer_2',
            'kvkk_transfer_3',
          ],
          icon: Icons.swap_horiz,
          iconColor: numInfo,
        ),
        LegalSection(
          titleKey: 'kvkk_rights_title',
          contentKey: 'kvkk_rights_content',
          bulletKeys: [
            'kvkk_right_1',
            'kvkk_right_2',
            'kvkk_right_3',
            'kvkk_right_4',
            'kvkk_right_5',
            'kvkk_right_6',
            'kvkk_right_7',
            'kvkk_right_8',
          ],
          icon: Icons.verified_user,
          iconColor: numSuccess,
        ),
        LegalSection(
          titleKey: 'kvkk_application_title',
          contentKey: 'kvkk_application_content',
          icon: Icons.mail,
          iconColor: numPrimary,
        ),
        LegalSection(
          titleKey: 'kvkk_retention_title',
          contentKey: 'kvkk_retention_content',
          icon: Icons.access_time,
          iconColor: numSecondary,
        ),
      ],
    );
  }
}
