import 'dart:async';
import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dio/dio.dart';
import '../core/secure_storage.dart';
import 'auth_config.dart';

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? email;

  /// Auth0 `sub` claim — kullanıcının kalıcı kimliği.
  /// RevenueCat appUserID olarak kullanılır (cihaz/yeniden kurulum bağımsız).
  final String? sub;

  AuthTokens({required this.accessToken, this.refreshToken, this.expiresAt, this.email, this.sub});

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
    'email': email,
    'sub': sub,
  };

  static AuthTokens? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return AuthTokens(
      accessToken: j['accessToken'] ?? '',
      refreshToken: j['refreshToken'],
      expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt']) : null,
      email: j['email'],
      sub: j['sub'],
    );
  }

  /// Decode JWT payload claims (no signature verification — display/identity only)
  static Map<String, dynamic>? decodeJwtClaims(String jwt) {
    try {
      final parts = jwt.split('.');
      if (parts.length != 3) return null;

      String payload = parts[1];
      while (payload.length % 4 != 0) {
        payload += '=';
      }
      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Failed to decode JWT claims: $e');
      return null;
    }
  }

  /// Extract email from JWT token payload
  static String? extractEmailFromJwt(String jwt) =>
      decodeJwtClaims(jwt)?['email'] as String?;

  /// Extract Auth0 sub (stable user id) from JWT token payload
  static String? extractSubFromJwt(String jwt) =>
      decodeJwtClaims(jwt)?['sub'] as String?;
}

class AuthRepository {
  static const _k = 'auth_tokens';
  final _appAuth = const FlutterAppAuth();
  final _cfg = AuthConfig();

  Future<AuthTokens?> load() async {
    final s = await SecureStore.read(_k);
    if (s == null) return null;
    return AuthTokens.fromJson(jsonDecode(s));
  }

  Future<void> save(AuthTokens? t) async {
    if (t == null) { await SecureStore.delete(_k); return; }
    await SecureStore.write(_k, jsonEncode(t.toJson()));
  }

  bool _isExpired(AuthTokens t) {
    if (t.expiresAt == null) return false;
    return DateTime.now().add(const Duration(seconds: 60)).isAfter(t.expiresAt!);
  }

  /// Token'ı gerekiyorsa yeniler.
  ///
  /// [force] true ise süre dolmamış olsa da yenilemeyi dener (401 sonrası retry
  /// için) ve yenileme BAŞARISIZSA null döner ki çağıran oturumun öldüğünü
  /// anlayabilsin. Normal modda başarısız yenilemede eldeki token'la devam
  /// edilir (geçici ağ hatalarında oturumu düşürmemek için).
  Future<AuthTokens?> ensureFresh(AuthTokens? current, {bool force = false}) async {
    if (current == null) return null;
    if (!force && !_isExpired(current)) return current;
    if ((current.refreshToken ?? '').isEmpty) return force ? null : current;
    try {
      final token = await _appAuth.token(TokenRequest(
        _cfg.clientId,
        _cfg.redirectUrl,
        issuer: _cfg.issuer,
        refreshToken: current.refreshToken,
        scopes: _cfg.scopes,
      ));
      if (token == null || token.accessToken == null) {
        return force ? null : current;
      }

      // Girişteki gibi ID token'ı tercih et: Joomla backend şifreli access
      // token'ı (JWE) çözemiyor. Eski kod burada access token kaydettiği için
      // ilk yenilemeden sonra API çağrıları sessizce bozuluyordu.
      final tokenToUse = token.idToken ?? token.accessToken!;

      final fresh = AuthTokens(
        accessToken: tokenToUse,
        refreshToken: token.refreshToken ?? current.refreshToken,
        expiresAt: token.accessTokenExpirationDateTime,
        email: (token.idToken != null
                ? AuthTokens.extractEmailFromJwt(token.idToken!)
                : null) ??
            current.email,
        sub: (token.idToken != null
                ? AuthTokens.extractSubFromJwt(token.idToken!)
                : null) ??
            current.sub,
      );
      await save(fresh);
      return fresh;
    } catch (e) {
      debugPrint('refresh failed: $e');
      return force ? null : current;
    }
  }

  Future<AuthTokens?> signIn() async {
    debugPrint('🔥🔥🔥 NEW CODE - AuthRepository.signIn() started 🔥🔥🔥');
    debugPrint('🔵 AuthRepository.signIn() started');
    debugPrint('🔵 Config: issuer=${_cfg.issuer}, clientId=${_cfg.clientId}');
    debugPrint('🔵 Redirect URL: ${_cfg.redirectUrl}');

    try {
      debugPrint('🔵 Calling FlutterAppAuth.authorizeAndExchangeCode...');
      debugPrint('🔵 preferEphemeralSession: true (using Chrome Custom Tabs with explicit packages)');

      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _cfg.clientId,
          _cfg.redirectUrl,
          issuer: _cfg.issuer,
          scopes: _cfg.scopes,
          preferEphemeralSession: true, // Try Custom Tabs again with explicit browser packages
          promptValues: ['login'], // Force Auth0 to always show account selection screen
          allowInsecureConnections: false,
        ),
      );

      debugPrint('🔵 authorizeAndExchangeCode completed');
      debugPrint('🔵 Result: $result');

      if (result == null || result.accessToken == null) {
        debugPrint('⚠️ Sign in cancelled or failed (result is null)');
        return null;
      }

      debugPrint('✅ Access token received: ${result.accessToken?.substring(0, 20)}...');
      debugPrint('✅ ID token received: ${result.idToken?.substring(0, 20)}...');

      // TEMP FIX: Use ID Token instead of encrypted Access Token
      // ID Token is plaintext JWT that backend can decode
      // Access Token is encrypted JWE that requires decryption
      final tokenToUse = result.idToken ?? result.accessToken!;
      debugPrint('🔵 Using ID Token for API calls (plaintext JWT)');

      // Extract identity claims from ID token
      final email = result.idToken != null
          ? AuthTokens.extractEmailFromJwt(result.idToken!)
          : null;
      final sub = result.idToken != null
          ? AuthTokens.extractSubFromJwt(result.idToken!)
          : null;
      debugPrint('🔵 Extracted email: $email, sub: $sub');

      final t = AuthTokens(
        accessToken: tokenToUse,
        refreshToken: result.refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
        email: email,
        sub: sub,
      );

      debugPrint('🔵 Saving tokens...');
      await save(t);
      debugPrint('✅ Tokens saved successfully');

      return t;
    } catch (e, stack) {
      debugPrint('❌ Sign in exception: $e');
      debugPrint('❌ Stack trace: $stack');
      rethrow;
    }
  }

  /// Sign in with Email/Password using Resource Owner Password Grant
  /// This keeps the user in-app without browser redirect
  /// NOTE: Requires Auth0 Application to have "Password" grant type enabled
  Future<AuthTokens?> signInWithPassword(String email, String password) async {
    debugPrint('🔵 AuthRepository.signInWithPassword() started');
    debugPrint('🔵 Email: $email');

    final issuer = Uri.parse(_cfg.issuer);
    final tokenUrl = 'https://${issuer.host}/oauth/token';

    try {
      final dio = Dio();
      final response = await dio.post(
        tokenUrl,
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
        ),
        data: {
          'grant_type': 'password',
          'client_id': _cfg.clientId,
          'username': email,
          'password': password,
          'scope': _cfg.scopes.join(' '),
          'audience': 'https://${issuer.host}/api/v2/',
        },
      );

      debugPrint('🔵 Token response: ${response.statusCode}');

      if (response.statusCode == 200 && response.data != null) {
        final data = response.data as Map<String, dynamic>;
        final accessToken = data['access_token'] as String?;
        final idToken = data['id_token'] as String?;
        final refreshToken = data['refresh_token'] as String?;
        final expiresIn = data['expires_in'] as int?;

        if (accessToken == null) {
          throw Exception('No access token in response');
        }

        // Use ID token for API calls (same as social login)
        final tokenToUse = idToken ?? accessToken;

        // Extract identity claims from ID token
        final extractedEmail = idToken != null
            ? AuthTokens.extractEmailFromJwt(idToken)
            : email;
        final sub = idToken != null
            ? AuthTokens.extractSubFromJwt(idToken)
            : null;

        final t = AuthTokens(
          accessToken: tokenToUse,
          refreshToken: refreshToken,
          expiresAt: expiresIn != null
              ? DateTime.now().add(Duration(seconds: expiresIn))
              : null,
          email: extractedEmail,
          sub: sub,
        );

        await save(t);
        debugPrint('✅ Password login successful');
        return t;
      }

      return null;
    } on DioException catch (e) {
      debugPrint('❌ Password login failed: ${e.response?.data}');
      final errorData = e.response?.data;
      if (errorData is Map<String, dynamic>) {
        final errorDesc = errorData['error_description'] ?? errorData['error'] ?? 'Login failed';
        throw AuthException(errorDesc.toString());
      }
      throw AuthException('Login failed: ${e.message}');
    } catch (e) {
      debugPrint('❌ Password login exception: $e');
      throw AuthException('Login failed: $e');
    }
  }

  /// Sign in with Social Provider (Google, Apple, etc.)
  /// This opens Auth0 Universal Login in browser
  Future<AuthTokens?> signInWithSocial(String connection) async {
    debugPrint('🔵 AuthRepository.signInWithSocial($connection) started');

    try {
      final result = await _appAuth.authorizeAndExchangeCode(
        AuthorizationTokenRequest(
          _cfg.clientId,
          _cfg.redirectUrl,
          issuer: _cfg.issuer,
          scopes: _cfg.scopes,
          preferEphemeralSession: true,
          additionalParameters: {
            'connection': connection, // google-oauth2, apple, etc.
          },
          allowInsecureConnections: false,
        ),
      );

      if (result == null || result.accessToken == null) {
        debugPrint('⚠️ Social sign in cancelled');
        return null;
      }

      final tokenToUse = result.idToken ?? result.accessToken!;
      final email = result.idToken != null
          ? AuthTokens.extractEmailFromJwt(result.idToken!)
          : null;
      final sub = result.idToken != null
          ? AuthTokens.extractSubFromJwt(result.idToken!)
          : null;

      final t = AuthTokens(
        accessToken: tokenToUse,
        refreshToken: result.refreshToken,
        expiresAt: result.accessTokenExpirationDateTime,
        email: email,
        sub: sub,
      );

      await save(t);
      debugPrint('✅ Social login successful');
      return t;
    } catch (e) {
      debugPrint('❌ Social login exception: $e');
      rethrow;
    }
  }

  Future<void> signOut() async {
    debugPrint('🔵 AuthRepository.signOut() started');

    // Clear Auth0 SSO session completely (federated logout)
    final issuer = Uri.parse(_cfg.issuer);
    final logoutUrl = Uri.https(issuer.host, '/v2/logout', {
      'client_id': _cfg.clientId,
      'returnTo': _cfg.logoutRedirectUrl,
      'federated': '', // Force complete logout from all identity providers
    });

    debugPrint('🔵 Opening Auth0 logout URL: $logoutUrl');
    try {
      await launchUrl(
        logoutUrl,
        mode: LaunchMode.externalApplication,
        webOnlyWindowName: '_self',
      );
      debugPrint('✅ Auth0 logout URL launched');
    } catch (e) {
      debugPrint('⚠️ Failed to launch logout URL: $e');
    }

    // Clear local tokens
    await save(null);
    debugPrint('✅ Local tokens cleared');
  }
}

/// Custom exception for auth errors
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
