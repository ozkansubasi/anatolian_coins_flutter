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

/// Play'deki paket adı (android/app/build.gradle.kts `applicationId`; geliştirme
/// sürümünün `.dev` eki satın almada kullanılmaz).
const androidPackageName = 'com.anatoliancoins.app';

/// App Store aboneliklerini yönetme (iptal) sayfası — hesap silinirken mağaza
/// aboneliği iptal edilmediği için kullanıcı buraya yönlendirilir.
Uri appStoreSubscriptionsUrl() => Uri.https('apps.apple.com', '/account/subscriptions');

/// Google Play'de bu uygulamanın aboneliğini yönetme (iptal) sayfası.
Uri playSubscriptionsUrl() => Uri.https(
    'play.google.com', '/store/account/subscriptions', {'package': androidPackageName});

/// Kullanım Koşulları — abonelik sayfasında satın alma düğmelerinin altında
/// (App Store 3.1.2(a)). İki dil de 2026-10-13'te 200.
Uri termsOfUseWebUrl(String languageCode) => languageCode == 'en'
    ? Uri.https('www.numistr.org', '/en/terms-of-use')
    : Uri.https('www.numistr.org', '/tr/kullanim-kosullari');

/// Gizlilik Politikası (TR: KVKK ve Gizlilik Politikası) — abonelik sayfası,
/// App Store 3.1.2(a). İki dil de 2026-10-13'te 200.
Uri privacyPolicyWebUrl(String languageCode) => languageCode == 'en'
    ? Uri.https('www.numistr.org', '/en/privacy-policy-gdpr')
    : Uri.https('www.numistr.org', '/tr/kvkk-ve-gizlilik-politikasi');
