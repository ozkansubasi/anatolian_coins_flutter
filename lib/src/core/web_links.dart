/// numistr.org bağlantıları.
///
/// Sikke sayfaları sitede `/tr/anatolian-coins/<menü-bölgesi>/<id>-<alias>`
/// biçiminde; menü bölge adresi kategori kodundan farklı olabiliyor (Kilikya:
/// `clicia-coins`). Kimlik tabanlı Joomla adresi bölgeden bağımsız çalışır —
/// eski `/sikke/<…>` biçimi 404 veriyordu (2026-09-26 cihaz testi).
Uri coinWebUrl(int articleId, String languageCode) => Uri.https('www.numistr.org', '/index.php', {
      'option': 'com_content',
      'view': 'article',
      'id': '$articleId',
      'lang': languageCode,
    });
