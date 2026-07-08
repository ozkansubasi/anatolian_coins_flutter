import 'package:flutter/material.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'prokit_legal_page.dart';

/// Privacy Policy / Gizlilik Politikası page (KVKK + GDPR compliant)
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProkitLegalPage(
      titleKey: 'privacy_policy',
      lastUpdated: '29.11.2025',
      headerIcon: Icons.privacy_tip,
      headerColor: numSecondary,
      sections: const [
        // 1. Veri Sorumlusu
        LegalSection(
          titleKey: 'pp_controller_title',
          contentKey: 'pp_controller_content',
          icon: Icons.business,
          iconColor: numPrimary,
        ),
        // 2. İşlenen Kişisel Verileriniz
        LegalSection(
          titleKey: 'pp_data_collected_title',
          contentKey: 'pp_data_collected_content',
          subSections: [
            LegalSubSection(
              titleKey: 'pp_identity_data_title',
              contentKey: 'pp_identity_data_content',
            ),
            LegalSubSection(
              titleKey: 'pp_academic_data_title',
              contentKey: 'pp_academic_data_content',
            ),
            LegalSubSection(
              titleKey: 'pp_visual_data_title',
              contentKey: 'pp_visual_data_content',
            ),
            LegalSubSection(
              titleKey: 'pp_technical_data_title',
              contentKey: 'pp_technical_data_content',
            ),
            LegalSubSection(
              titleKey: 'pp_usage_data_title',
              contentKey: 'pp_usage_data_content',
            ),
          ],
          icon: Icons.folder_open,
          iconColor: numPrimary,
        ),
        // 3. Kişisel Verilerin İşlenme Amaçları
        LegalSection(
          titleKey: 'pp_purposes_title',
          contentKey: 'pp_purposes_content',
          bulletKeys: [
            'pp_purpose_service',
            'pp_purpose_academic',
            'pp_purpose_api',
            'pp_purpose_communication',
            'pp_purpose_improvement',
            'pp_purpose_personalization',
            'pp_purpose_legal',
          ],
          icon: Icons.analytics,
          iconColor: numSecondary,
        ),
        // 4. Kişisel Veri Toplama Yöntemi ve Hukuki Sebebi
        LegalSection(
          titleKey: 'pp_collection_method_title',
          contentKey: 'pp_collection_method_content',
          icon: Icons.settings_input_antenna,
          iconColor: numInfo,
        ),
        // 5. Hukuki Sebepler (KVKK Madde 5 / GDPR Madde 6)
        LegalSection(
          titleKey: 'pp_legal_basis_title',
          contentKey: 'pp_legal_basis_content',
          bulletKeys: [
            'pp_legal_basis_1',
            'pp_legal_basis_2',
            'pp_legal_basis_3',
          ],
          icon: Icons.gavel,
          iconColor: numWarning,
        ),
        // 6. Kişisel Verilerin Aktarılması
        LegalSection(
          titleKey: 'pp_data_transfer_title',
          contentKey: 'pp_data_transfer_content',
          subSections: [
            LegalSubSection(
              titleKey: 'pp_transfer_providers_title',
              contentKey: 'pp_transfer_technical',
            ),
          ],
          bulletKeys: [
            'pp_transfer_analytics',
            'pp_transfer_authorities',
          ],
          icon: Icons.share,
          iconColor: numWarning,
        ),
        // 7. Mobil Uygulama Kamera ve Galeri İzni
        LegalSection(
          titleKey: 'pp_camera_title',
          contentKey: 'pp_camera_content',
          bulletKeys: [
            'pp_camera_1',
            'pp_camera_2',
          ],
          icon: Icons.camera_alt,
          iconColor: numInfo,
        ),
        // 8. Veri Güvenliği
        LegalSection(
          titleKey: 'pp_security_title',
          contentKey: 'pp_security_content',
          icon: Icons.security,
          iconColor: numSuccess,
        ),
        // 9. Kişisel Veri Sahibinin Hakları (KVKK Madde 11 / GDPR)
        LegalSection(
          titleKey: 'pp_rights_title',
          contentKey: 'pp_rights_content',
          bulletKeys: [
            'pp_right_1',
            'pp_right_2',
            'pp_right_3',
            'pp_right_4',
            'pp_right_5',
            'pp_right_6',
            'pp_right_7',
            'pp_right_8',
          ],
          icon: Icons.person,
          iconColor: numPrimary,
        ),
        // 10. İletişim
        LegalSection(
          titleKey: 'pp_contact_title',
          contentKey: 'pp_contact_content',
          bulletKeys: [
            'pp_company_name',
            'pp_company_email',
          ],
          icon: Icons.contact_mail,
          iconColor: numInfo,
        ),
      ],
    );
  }
}
