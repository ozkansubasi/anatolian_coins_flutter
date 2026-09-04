import '../core/env.dart';

class AuthConfig {
  final String issuer = Env.oidcIssuer;               // https://TENANT.region.auth0.com
  final String clientId = Env.oidcClientId;           // Auth0 app client id
  final String redirectUrl = Env.oidcRedirectUrl;     // com.anatoliancoins.app://callback
  final String logoutRedirectUrl = Env.oidcLogoutRedirectUrl; // com.anatoliancoins.app://logout
  final List<String> scopes = Env.oidcScopes;         // include offline_access

  /// Management API audience. [issuer] custom domain'e geçse de KANONİK tenant
  /// alan adını kullanır — custom domain audience olarak kabul edilmez.
  final String managementAudience = Env.oidcManagementAudience;
}
