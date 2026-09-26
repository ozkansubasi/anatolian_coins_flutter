// Görsel atfı (ADR-008): API'nin credit/license alanları modele ve metne geçer.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:anatolian_coins/src/l10n/app_localizations.dart';
import 'package:anatolian_coins/src/models/variant_image.dart';
import 'package:anatolian_coins/src/widgets/image_credit.dart';

VariantImage _img(Map<String, dynamic> extra) => VariantImage.fromJson({
      'image_id': 1,
      'variant_id': 2,
      'url': '/u',
      'url_raw': '/r',
      ...extra,
    });

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppLocalizations tr;
  late AppLocalizations en;

  setUpAll(() async {
    tr = await AppLocalizations.load(const Locale('tr'));
    en = await AppLocalizations.load(const Locale('en'));
  });

  test('kurum + lisans', () {
    final img = _img({'credit': 'Berlin, Münzkabinett', 'license': 'PDM 1.0'});
    expect(ImageCredit.text(img, tr), 'Görsel: Berlin, Münzkabinett · PDM 1.0');
    expect(ImageCredit.text(img, en), 'Image: Berlin, Münzkabinett · PDM 1.0');
  });

  test('lisans yoksa yalnız kurum', () {
    expect(ImageCredit.text(_img({'credit': 'ANS', 'license': ''}), en), 'Image: ANS');
  });

  test('kurum yoksa atıf yok (boş/boşluk dahil)', () {
    expect(ImageCredit.text(_img({}), en), isNull);
    expect(ImageCredit.text(_img({'credit': '  ', 'license': 'CC BY 4.0'}), en), isNull);
  });

  test('çevrimdışı satırdan (aynı anahtarlar) okunur', () {
    final img = VariantImage.fromJson({
      'image_id': 1, 'variant_id': 2, 'url': 'u', 'url_raw': 'r',
      'credit': 'British Museum', 'license': 'CC BY-NC-SA 4.0', 'local_path': '/x.jpg',
    });
    expect(img.credit, 'British Museum');
    expect(img.license, 'CC BY-NC-SA 4.0');
  });
}
