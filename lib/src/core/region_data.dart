import '../l10n/app_localizations.dart';

class RegionData {
  /// Bölge kodları (kategori alias'ı). Görünen ad kodda değil, çeviri
  /// dosyasında: `region_<kod>` anahtarı → [name].
  static const List<String> regionCodes = [
    'pisidia-coins',
    'lydia-coins',
    'ionia-coins',
    'caria-coins',
    'lycia-coins',
    'phrygia-coins',
    'mysia-coins',
    'bithynia-coins',
    'pamphylia-coins',
    'cilicia-coins',
    'cappadocia-coins',
    'galatia-coins',
    'aeolis-coins',
    'troas-coins',
    'paphlagonia-coins',
    'pontus-coins',
    'other-ancient-regions-coins',
  ];

  /// Popularity order for regions (based on coin count and user interest)
  /// Higher number = more popular, shows first
  static const Map<String, int> regionPopularity = {
    'lydia-coins': 100,       // En popüler - Croeseid, Sardis
    'ionia-coins': 95,        // Ephesus, Miletus, Smyrna
    'caria-coins': 90,        // Halicarnassus, Knidos, Rhodes
    'lycia-coins': 85,        // Patara, Xanthos
    'phrygia-coins': 80,      // Laodiceia, Hierapolis
    'cilicia-coins': 75,      // Tarsus, Side
    'pamphylia-coins': 70,    // Aspendos, Perge, Side
    'mysia-coins': 65,        // Pergamum, Cyzicus
    'pisidia-coins': 60,      // Selge, Sagalassus
    'bithynia-coins': 55,     // Nicomedia, Nicaea
    'cappadocia-coins': 50,   // Caesarea
    'galatia-coins': 45,      // Ancyra
    'troas-coins': 40,        // Troy
    'aeolis-coins': 35,       // Ailios
    'pontus-coins': 30,       // Pontus
    'paphlagonia-coins': 25,  // Paflagonya
    'other-ancient-regions-coins': 0, // Her zaman en altta
  };

  /// Veritabanındaki gerçek darphane isimleri (nomisma.org formatında)
  static const Map<String, List<String>> mints = {
    'pisidia-coins': [
      'adada',
      'amblada',
      'andeda',
      'antiocheia_pisidia',
      'comama',
      'conana',
      'cremna',
      'etenna',
      'prostanna',
      'selge',
    ],
    'lydia-coins': [
      'apollonis',
      'caystriani',
      'magnesia_ad_sipylum',
      'mostene',
      'sardes',
      'thyatira',
      'thyessus',
      'tralles',
    ],
    'ionia-coins': [
      'chios',
      'clazomenae',
      'colophon',
      'ephesus',
      'erythrae',
      'lebedus',
      'magnesia_ad_maeandrum',
      'metropolis_ionia',
      'miletus',
      'myus',
      'phocaea',
      'phygela',
      'priene',
      'samos',
      'smyrna',
      'teos',
    ],
    'caria-coins': [
      'alinda',
      'amyzon',
      'antiocheia_ad_maeandrum',
      'astypalaea',
      'attuda',
      'bargylia',
      'calynda',
      'caunus',
      'ceramus',
      'cidramus',
      'cnidus',
      'cos',
      'cys',
      'euromus',
      'gordiuteichos',
      'halicarnassus',
      'harpasa',
      'hydisus',
      'iasus',
      'idyma',
      'mylasa',
      'myndus',
      'nisyros',
      'orthosia_caria',
      'plarasa',
      'rhodes',
      'stratoniceia',
      'syangela',
      'syme',
      'tabae',
      'telos',
      'thera',
    ],
    'lycia-coins': [
      'aperlae',
      'apollonia_lycia',
      'arycanda',
      'balbura',
      'candyba',
      'choma',
      'cibyra',
      'gagae',
      'masicytes',
      'myra',
      'oenoanda',
      'olympus',
      'patara',
      'phaselis',
      'phellus',
      'pinara',
      'podalia',
      'rhodiapolis',
      'sidyma',
      'telmessus',
      'tlos',
    ],
    'phrygia-coins': [
      'aezanis',
      'appia',
      'blaundus',
      'cibyra',
      'colossae',
      'dionysopolis_phrygia',
      'eumeneia',
      'laodiceia_ad_lycum',
      'peltae',
      'philomelium',
      'stectorium',
      'synnada',
    ],
    'mysia-coins': [
      'adramyteum',
      'apollonia_ad_rhyndacum',
      'cyzicus',
      'hadrianeia',
      'hadrianothera',
      'lampsacus',
      'miletopolis',
      'pergamum',
      'perperene',
      'placia',
      'priapus',
      'proconnesus',
      'teuthrania',
      'zeleia',
    ],
    'bithynia-coins': [
      'calchedon',
      'cius',
      'nicomedia',
      'prusa_ad_olympum',
      'tium',
    ],
    'pamphylia-coins': [
      'aspendus',
      'magydus',
      'side',
    ],
    'cilicia-coins': [
      'adana',
      'anazarbus',
      'aphrodisias_cilicia',
      'celenderis',
      'coropissus',
      'corycus',
      'epiphaneia_cilicia',
      'holmi',
      'issus',
      'mallus',
      'myriandrus',
      'nagidus',
      'rhosus',
      'soli-pompeiopolis',
      'tarsus',
    ],
    'cappadocia-coins': [
      'cybistra',
      'eusebeia',
      'tyana',
    ],
    'galatia-coins': [
      'pessinus',
      'tavium',
    ],
    'aeolis-coins': [
      'aegae_aeolis',
      'attaea',
      'cyme_aeolis',
      'elaea',
      'myrina_aeolis',
      'neonteichos',
      'pitane',
      'temnus',
      'tisna',
    ],
    'troas-coins': [
      'abydus',
      'antandrus',
      'assus',
      'birytis',
      'dardanus',
      'gargara',
      'gentinus',
      'hamaxitus',
      'ilium',
      'ophrynium',
      'scepsis',
      'sigeum',
      'tenedos',
    ],
    'paphlagonia-coins': [
      'amastris',
      'cromna',
      'sesamus',
      'sinope',
    ],
    'pontus-coins': [
      'amisus',
      'cabeira',
      'gaziura',
      'pharnaceia',
      'trapezus',
      'zela',
    ],
    'other-ancient-regions-coins': [
      'arkathiokerta',
      'iconium',
      'isaura',
      'laranda',
      'samsosata',
      'savatra',
    ],
  };

  /// Bölgenin arayüz dilindeki adı; bilinmeyen kod olduğu gibi döner.
  static String getRegionName(String? regionCode, AppLocalizations l10n) {
    if (regionCode == null || regionCode.isEmpty) return '-';
    if (!regionCodes.contains(regionCode)) return regionCode;
    return l10n.translate('region_$regionCode');
  }

  static List<String> getMintsForRegion(String? regionCode) {
    if (regionCode == null || regionCode.isEmpty) return [];
    return mints[regionCode] ?? [];
  }

  /// (kod, ad) çiftleri, ada göre alfabetik.
  static List<MapEntry<String, String>> getAllRegions(AppLocalizations l10n) {
    return [for (final c in regionCodes) MapEntry(c, getRegionName(c, l10n))]
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  /// (kod, ad) çiftleri, popülerliğe göre ("diğer" her zaman sonda).
  static List<MapEntry<String, String>> getRegionsByPopularity(AppLocalizations l10n) {
    final entries = [for (final c in regionCodes) MapEntry(c, getRegionName(c, l10n))];
    entries.sort((a, b) {
      final popA = regionPopularity[a.key] ?? 0;
      final popB = regionPopularity[b.key] ?? 0;
      return popB.compareTo(popA); // Descending order
    });
    return entries;
  }

  /// Get popularity score for a region
  static int getRegionPopularity(String? regionCode) {
    if (regionCode == null) return 0;
    return regionPopularity[regionCode] ?? 0;
  }
}
