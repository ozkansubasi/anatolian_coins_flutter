class RegionData {
  static const Map<String, String> regionNames = {
    'pisidia-coins': 'Pisidia',
    'lydia-coins': 'Lidya',
    'ionia-coins': 'İonia',
    'caria-coins': 'Karya',
    'lycia-coins': 'Likya',
    'phrygia-coins': 'Frigya',
    'mysia-coins': 'Misia',
    'bithynia-coins': 'Bitinya',
    'pamphylia-coins': 'Pamfilya',
    'cilicia-coins': 'Kilikya',
    'cappadocia-coins': 'Kapadokya',
    'galatia-coins': 'Galatya',
    'aeolis-coins': 'Ailios',
    'troas-coins': 'Troya',
    'paphlagonia-coins': 'Paflagonya',
    'pontus-coins': 'Pontus',
    'other-ancient-regions-coins': 'Diğer',
  };

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

  static String getRegionName(String? regionCode) {
    if (regionCode == null || regionCode.isEmpty) return '-';
    return regionNames[regionCode] ?? regionCode;
  }

  static List<String> getMintsForRegion(String? regionCode) {
    if (regionCode == null || regionCode.isEmpty) return [];
    return mints[regionCode] ?? [];
  }

  static List<MapEntry<String, String>> getAllRegions() {
    return regionNames.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
  }

  /// Get regions sorted by popularity (most popular first)
  /// "Diğer Antik Bölgeler" is always last
  static List<MapEntry<String, String>> getRegionsByPopularity() {
    final entries = regionNames.entries.toList();

    // Sort by popularity (descending), "other" always last
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
