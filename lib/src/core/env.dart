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
  static const oidcIssuer = String.fromEnvironment(
    'OIDC_ISSUER',
    defaultValue: 'https://dev-ja5k8sumb7005j4n.us.auth0.com',
  );
  static const oidcClientId = String.fromEnvironment(
    'OIDC_CLIENT_ID',
    defaultValue: '5AFSce7JEdmyxBrwjwEI7IcnRnvXKF8c',
  );

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
