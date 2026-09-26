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

/// Sıkça Sorulan Sorular (sitede; iki dilde ayrı adres, ikisi de 2026-09-09'da 200).
Uri faqWebUrl(String languageCode) => languageCode == 'en'
    ? Uri.https('numistr.org', '/en/faq')
    : Uri.https('numistr.org', '/tr/sikca-sorulan-sorular');
