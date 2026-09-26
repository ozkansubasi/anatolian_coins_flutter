/// Ortam yapılandırması (dev/prod ayrımı --dart-define ile yapılır).
///
/// Varsayılan değerler DEV ortamıdır; parametre verilmeden `flutter run`
/// dev ayarlarıyla çalışır. Prod build için:
///
///   flutter build appbundle --dart-define-from-file=env/prod.json
///
/// Dev değerlerini açıkça vermek istersen: --dart-define-from-file=env/dev.json
class Env {
  // Ortam adı: 'dev' | 'prod'
  static const environment =
      String.fromEnvironment('APP_ENV', defaultValue: 'dev');

  static const isProduction = environment == 'prod';

  // NumisTR API base URL (Joomla REST API)
  static const baseUrl = String.fromEnvironment(
    'BASE_URL',
    defaultValue: 'https://www.numistr.org/api/index.php/v1',
  );

  // AI Recognition Service base URL
  static const aiServiceUrl = String.fromEnvironment(
    'AI_SERVICE_URL',
    defaultValue: 'https://ai.numistr.org',
  );

  // ---- Auth0 (OIDC + PKCE) ----
  /// "Apple ile devam et" düğmesi. Auth0'da `apple` bağlantısı açılana kadar
  /// KAPALI: 2026-09-26 Play ön-yayın robotu düğmeye bastı, Auth0 "the connection
  /// is not enabled" döndü — Android'de gerçek kullanıcı da aynı hatayı alırdı.
  /// iOS yayınından önce açılmalı (App Store 4.8: Google girişi varsa Apple şart).
  static const appleSignInEnabled =
      bool.fromEnvironment('APPLE_SIGNIN_ENABLED', defaultValue: false);

  static const oidcIssuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'https://dev-ja5k8sumb7005j4n.us.auth0.com',
  );
  static const oidcClientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: '5AFSce7JEdmyxBrwjwEI7IcnRnvXKF8c',
  );

  // Auth0'ın KANONİK tenant alan adı — [oidcIssuer] custom domain'e (login.numistr.org)
  // geçse bile bu DEĞİŞMEZ. Management API'nin (`/api/v2/`) tanımlayıcısı her zaman kanonik
  // alan adıdır; audience olarak custom domain verilirse Auth0 "Service not enabled within
  // domain" döndürür. Auth0 dokümanı: "Continue to use your default tenant domain name
  // (such as https://YOUR_DOMAIN/userinfo and https://YOUR_DOMAIN/api/v2/) instead of your
  // custom domain when specifying an audience."
  static const oidcCanonicalDomain = String.fromEnvironment(
    'OIDC_CANONICAL_DOMAIN',
    defaultValue: 'dev-ja5k8sumb7005j4n.us.auth0.com',
  );

  /// ROPG (uygulama içi e-posta/şifre girişi) için Management API audience'ı.
  static String get oidcManagementAudience => 'https://$oidcCanonicalDomain/api/v2/';

  // Callback & Logout URI'leri (Auth0 Allowed URLs ile birebir)
  static const oidcRedirectUrl = String.fromEnvironment(
    'OIDC_REDIRECT_URL',
    defaultValue: 'com.anatoliancoins.app://callback',
  );
  static const oidcLogoutRedirectUrl = String.fromEnvironment(
    'OIDC_LOGOUT_REDIRECT_URL',
    defaultValue: 'com.anatoliancoins.app://logout',
  );

  // Refresh token için offline_access gerekir
  static const oidcScopes = ['openid', 'profile', 'email', 'offline_access'];

  // ---- RevenueCat (public SDK anahtarları) ----
  // iOS anahtarı App Store uygulaması RevenueCat'e eklenince oluşacak (appl_...)
  static const revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: 'goog_HqITgfhcdtQNphhibhFTMbQHjGg',
  );
  static const revenueCatIosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '',
  );
}
