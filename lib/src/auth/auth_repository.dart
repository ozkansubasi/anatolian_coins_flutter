import 'dart:async';
import 'dart:convert';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/secure_storage.dart';
import 'auth_config.dart';

class AuthTokens {
  final String accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;

  AuthTokens({required this.accessToken, this.refreshToken, this.expiresAt});

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
  };

  static AuthTokens? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return AuthTokens(
      accessToken: j['accessToken'] ?? '',
      refreshToken: j['refreshToken'],
      expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt']) : null,
    );
  }
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

  Future<AuthTokens?> ensureFresh(AuthTokens? current) async {
    if (current == null) return null;
    if (!_isExpired(current)) return current;
    if ((current.refreshToken ?? '').isEmpty) return current;
    try {
      final token = await _appAuth.token(TokenRequest(
        _cfg.clientId,
        _cfg.redirectUrl,
        issuer: _cfg.issuer,
        refreshToken: current.refreshToken,
        scopes: _cfg.scopes,
      ));
      if (token == null || token.accessToken == null) return current;
      final fresh = AuthTokens(
        accessToken: token.accessToken!,
        refreshToken: token.refreshToken ?? current.refreshToken,
        expiresAt: token.accessTokenExpirationDateTime,
      );
      await save(fresh);
      return fresh;
    } catch (e) {
      debugPrint('refresh failed: $e');
      return current;
    }
  }

  Future<AuthTokens?> signIn() async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _cfg.clientId,
        _cfg.redirectUrl,
        issuer: _cfg.issuer,
        scopes: _cfg.scopes,
      ),
    );
    if (result == null || result.accessToken == null) return null;
    final t = AuthTokens(
      accessToken: result.accessToken!,
      refreshToken: result.refreshToken,
      expiresAt: result.accessTokenExpirationDateTime,
    );
    await save(t);
    return t;
  }

  Future<void> signOut() async {
    final issuer = Uri.parse(_cfg.issuer);
    final logoutUrl = Uri.https(issuer.host, '/v2/logout', {
      'client_id': _cfg.clientId,
      'returnTo': _cfg.logoutRedirectUrl,
    });
    try { await launchUrl(logoutUrl, mode: LaunchMode.externalApplication); } catch (_) {}
    await save(null);
  }
}
