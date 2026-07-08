import 'package:flutter/material.dart';
import '../../prokit_ui/numistr_colors.dart';
import 'prokit_legal_page.dart';

/// Terms of Service / Kullanım Koşulları page
class TermsOfServicePage extends StatelessWidget {
  const TermsOfServicePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ProkitLegalPage(
      titleKey: 'terms_of_service',
      lastUpdated: '29.11.2025',
      headerIcon: Icons.gavel,
      headerColor: numPrimary,
      sections: const [
        // 1. Giriş ve Taraflar
        LegalSection(
          titleKey: 'tos_intro_title',
          contentKey: 'tos_intro_content',
          icon: Icons.business,
          iconColor: numPrimary,
        ),
        // 2. Kabul ve Onay
        LegalSection(
          titleKey: 'tos_acceptance_title',
          contentKey: 'tos_acceptance_content',
          icon: Icons.check_circle_outline,
          iconColor: numSuccess,
        ),
        // 3. Yaş Şartı
        LegalSection(
          titleKey: 'tos_acceptance_title',
          contentKey: 'tos_age_requirement',
          icon: Icons.person_outline,
          iconColor: numInfo,
        ),
        // 4. Hizmetin Niteliği ve Sorumluluk Reddi
        LegalSection(
          titleKey: 'tos_service_nature_title',
          contentKey: 'tos_service_nature_content',
          subSections: [
            LegalSubSection(
              titleKey: 'tos_accuracy_title',
              contentKey: 'tos_accuracy_content',
            ),
            LegalSubSection(
              titleKey: 'tos_valuation_title',
              contentKey: 'tos_valuation_content',
            ),
          ],
          icon: Icons.warning_amber,
          iconColor: numWarning,
        ),
        // 5. Lisans ve Erişim Hakkı
        LegalSection(
          titleKey: 'tos_license_title',
          contentKey: 'tos_license_content',
          bulletKeys: [
            'tos_usage_purpose',
            'tos_license_restrictions',
          ],
          icon: Icons.verified_user,
          iconColor: numSecondary,
        ),
        // 6. Üyelik, Abonelik ve Ödemeler
        LegalSection(
          titleKey: 'tos_subscription_title',
          contentKey: 'tos_subscription_content',
          bulletKeys: [
            'tos_subscription_pro',
            'tos_subscription_renewal',
          ],
          icon: Icons.payment,
          iconColor: numMaterialGold,
        ),
        // 7. Fikri Mülkiyet Hakları
        LegalSection(
          titleKey: 'tos_intellectual_title',
          contentKey: 'tos_intellectual_content',
          icon: Icons.copyright,
          iconColor: numWarning,
        ),
        // 8. Kullanıcı İçeriği
        LegalSection(
          titleKey: 'tos_user_content_title',
          contentKey: 'tos_user_content_content',
          icon: Icons.photo_camera,
          iconColor: numInfo,
        ),
        // 9. Yasaklanmış Kullanımlar
        LegalSection(
          titleKey: 'tos_prohibited_title',
          contentKey: 'tos_prohibited_content',
          bulletKeys: [
            'tos_prohibited_1',
            'tos_prohibited_2',
            'tos_prohibited_3',
            'tos_prohibited_4',
            'tos_prohibited_5',
          ],
          icon: Icons.block,
          iconColor: numError,
        ),
        // 10. Değişiklikler
        LegalSection(
          titleKey: 'tos_changes_title',
          contentKey: 'tos_changes_content',
          icon: Icons.update,
          iconColor: numInfo,
        ),
        // 11. Gizlilik Politikası Referansı
        LegalSection(
          titleKey: 'tos_privacy_reference_title',
          contentKey: 'tos_privacy_reference_content',
          icon: Icons.privacy_tip,
          iconColor: numSecondary,
        ),
        // 12. Uyuşmazlıkların Çözümü
        LegalSection(
          titleKey: 'tos_governing_law_title',
          contentKey: 'tos_governing_law_content',
          icon: Icons.account_balance,
          iconColor: numPrimary,
        ),
        // 13. İletişim
        LegalSection(
          titleKey: 'tos_contact_title',
          contentKey: 'tos_contact_content',
          bulletKeys: [
            'tos_company_name',
            'tos_company_email',
          ],
          icon: Icons.contact_mail,
          iconColor: numInfo,
        ),
      ],
    );
  }
}
