import 'package:flutter/material.dart';
import '../../../prokit_ui/numistr_colors.dart';

/// Ana sayfa banner'i: gorsel banner'i KAPLAR, slogan altta ayri zeminli seritte.
///
/// 2026-09-20 tasarim notu — neden slogan gorselin UZERINDE degil altta:
/// sikke gorselleri muze/arsiv fotografi ve ZEMINLERI BEYAZ. Gorselin uzerine
/// yazilan beyaz slogan okunmaz, koyu bir perde (scrim) eklense bu kez fotografin
/// yarisi kararir. Alt serit hem sloganı garanti okunur kilar hem de fotografi
/// oldugu gibi birakir.
///
/// Gorsel oturtma (fit) banner'a gore degisir:
/// - Sikke fotograflari kare ve nesne ortada: [BoxFit.contain] + krem zemin
///   (cover kullanilsa 480x480 sikkeden yatay bir dilim gorunurdu).
/// - Manzara fotograflari: [BoxFit.cover], cerceveyi doldurur.
/// Arsiv fotograflarinin beyaz zemininin cevrildigi sicak plaka tonu.
const Color _plakaZemin = Color(0xFFF3E8D6);

class HomeBanner extends StatelessWidget {
  final String image;
  final String slogan;
  final VoidCallback onTap;
  final BoxFit fit;

  /// Gorsel uzerinde dikkat cekilecek noktalar (bos ise isaret cizilmez).
  /// Konum, gorsel alanina gore -1..1 araliginda (Alignment).
  final List<BannerMarker> markers;

  const HomeBanner({
    super.key,
    required this.image,
    required this.slogan,
    required this.onTap,
    this.fit = BoxFit.cover,
    this.markers = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Material(
        color: Colors.transparent,
        // CERCEVE: beyaz zeminli arsiv fotograflari cercevesiz birakilinca
        // banner'in siniri kaybolup "bosluk" hissi veriyordu (2026-09-20).
        // Altin kenarlik, gorsel alani ile slogan seridini tek parca yapar.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: numPrimary.withAlpha(90)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          // Slogan seridi gorselin UZERINE BINMEZ, altinda ayri satirdir.
          // Onceki surumde Stack ile bindiriliyordu; beyaz zeminli sikke
          // fotograflarinda seridin altinda kalan kisim kesik gorunuyordu.
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Gorsel: kendi alanini kaplar
                    Container(
                      // contain modunda zemin BEYAZ: arsiv fotograflarinin kendi
                      // zemini beyaz, krem zeminde ortada gorunur bir dikis birakiyordu.
                      color: fit == BoxFit.contain ? _plakaZemin : numPrimaryDark,
                      child: ColorFiltered(
                        // Arsiv fotograflarinin BEYAZ zeminini sicak bir plaka
                        // tonuna cevirir (carpma karisimi): beyaz -> krem, sikke
                        // tonu korunur. Manzara fotografinda filtre uygulanmaz.
                        colorFilter: ColorFilter.mode(
                          fit == BoxFit.contain ? _plakaZemin : Colors.transparent,
                          fit == BoxFit.contain ? BlendMode.multiply : BlendMode.dst,
                        ),
                        child: Image.asset(
                          image,
                          fit: fit,
                          errorBuilder: (_, __, ___) => Container(
                            color: numPrimaryDark,
                            child: const Icon(Icons.image_not_supported_outlined,
                                color: Colors.white38, size: 32),
                          ),
                        ),
                      ),
                    ),

                    // Isaretler yalniz gorsel alanina konur
                    for (final m in markers)
                      Align(
                        alignment: m.at,
                        child: _MarkerRing(label: m.label),
                      ),
                  ],
                ),
              ),

              // Slogan seridi: gorselin ALTINDA, ayri zeminde
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [numPrimaryDark, numPrimary],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                ),
                child: Text(
                  slogan,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gorsel uzerindeki tek bir isaret: halka + kisa etiket.
class BannerMarker {
  final Alignment at;
  final String label;
  const BannerMarker(this.at, this.label);
}

class _MarkerRing extends StatelessWidget {
  final String label;
  const _MarkerRing({required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            // Beyaz zeminli arsiv fotografinda beyaz halka kaybolur -> altin.
            border: Border.all(color: numPrimary, width: 2),
          ),
        ),
        const SizedBox(height: 3),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: numPrimaryDark.withAlpha(230),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
