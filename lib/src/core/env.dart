class Env {
  // NumisTR API base URL
  static const baseUrl = 'https://www.numistr.org/api/index.php/v1';

  // ---- Auth0 (OIDC + PKCE) ----
  static const oidcIssuer = 'https://dev-ja5k8sumb7005j4n.us.auth0.com';
  static const oidcClientId = '5AFSce7JEdmyxBrwjwEI7IcnRnvXKF8c';

  // Callback & Logout URI'leri (Auth0 Allowed URLs ile birebir)
  static const oidcRedirectUrl = 'com.anatoliancoins.app://callback';
  static const oidcLogoutRedirectUrl = 'com.anatoliancoins.app://logout';

  // Refresh token için offline_access gerekir
  static const oidcScopes = ['openid','profile','email','offline_access'];
}
