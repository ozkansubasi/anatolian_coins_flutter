import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../l10n/app_localizations.dart';
import '../prokit_ui/numistr_colors.dart';

/// Altın üst çubuktaki marka: ince beyaz çerçeveli logo + Cinzel uygulama adı.
///
/// Ana sayfa ve Hesabım aynı başlığı taşır (kullanıcı kararı 2026-09-26).
/// Cinzel: numistr.org logosundaki yazıt harflerine (Trajan tarzı) en yakın
/// serbest yazı tipi; assets/google_fonts/ içinde gömülü.
class BrandTitle extends StatelessWidget {
  const BrandTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Altın bantta logo seçilsin diye çok ince beyaz çizgi (logoyu örtmez)
        Container(
          padding: const EdgeInsets.all(0.8),
          decoration: BoxDecoration(
              color: Colors.white, borderRadius: BorderRadius.circular(8.8)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'assets/icon/app_icon.png',
              height: 32,
              width: 32,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Container(
                height: 32,
                width: 32,
                decoration: BoxDecoration(
                  color: numPrimary.withAlpha(30),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.monetization_on,
                    color: numPrimary, size: 20),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            l10n.translate('app_name'),
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.cinzel(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
