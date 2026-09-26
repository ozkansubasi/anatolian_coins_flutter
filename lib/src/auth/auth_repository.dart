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

  /// OIDC `id_token`.
  ///
  /// Çıkışta gerekiyor: `EndSessionRequest`, `postLogoutRedirectUrl` verildiğinde
  /// `idTokenHint`'i ZORUNLU kılıyor (paket içinde assert var). Hint olmadan
  /// uygulamaya geri dönüş yapılamaz, dolayısıyla oturum kapatma akışı tamamlanmaz.
  final String? idToken;

  AuthTokens({
    required this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.email,
    this.sub,
    this.idToken,
  });

  Map<String, dynamic> toJson() => {
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'expiresAt': expiresAt?.toIso8601String(),
    'email': email,
    'sub': sub,
    'idToken': idToken,
  };

  static AuthTokens? fromJson(Map<String, dynamic>? j) {
    if (j == null) return null;
    return AuthTokens(
      accessToken: j['accessToken'] ?? '',
      refreshToken: j['refreshToken'],
      expiresAt: j['expiresAt'] != null ? DateTime.tryParse(j['expiresAt']) : null,
      email: j['email'],
      sub: j['sub'],
      idToken: j['idToken'],
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

  /// Görünen ad (Hesabım başlığı). Google girişinde `name` gerçek ad-soyaddır;
  /// şifreli (veritabanı) hesaplarda Auth0 `name`'e e-postayı yazar — o zaman
  /// null döner ve başlık yalnız e-postayı gösterir.
  String? get displayName {
    final claims = idToken == null ? null : decodeJwtClaims(idToken!);
    if (claims == null) return null;
    final name = (claims['name'] as String?)?.trim();
    if (name != null && name.isNotEmpty && !name.contains('@')) return name;
    final parts = [claims['given_name'], claims['family_name']]
        .whereType<String>()
        .where((p) => p.trim().isNotEmpty);
    return parts.isEmpty ? null : parts.join(' ');
  }
}

class AuthRepository {
  static const _k = 'auth_tokens';

  /// Şifre değiştirme / sıfırlama bağlantısını e-postaya gönderir (Auth0
  /// `dbconnections/change_password`). Yalnız şifreli hesaplar içindir; Google
  /// girişli hesapta Auth0 "User does not exist" döner ve e-posta gitmez.
  Future<bool> requestPasswordReset(String email) async {
    try {
      final response = await Dio().post(
        '${_cfg.issuer}/dbconnections/change_password',
        data: {
          'client_id': _cfg.clientId,
          'email': email,
          'connection': 'Username-Password-Authentication',
        },
        options: Options(
          contentType: Headers.jsonContentType,
          // Auth0 düz metin döner; hata durumlarını kendimiz değerlendirelim
          responseType: ResponseType.plain,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final ok = (response.statusCode ?? 500) < 300;
      if (!ok) {
        debugPrint('! Password reset failed (${response.statusCode}): ${response.data}');
      }
      return ok;
    } catch (e) {
      debugPrint('! Password reset error: $e');
      return false;
    }
  }

  /// `LocaleNotifier`'in dili sakladigi anahtar (core/locale_provider.dart).
  /// Ayni depo okunur ki Auth0'a gonderilen dil ile uygulamanin dili ayrismasin.
  static const _localeKey = 'app_locale';

  final _appAuth = const FlutterAppAuth();
  final _cfg = AuthConfig();

  /// Auth0'a gonderilecek dil kodu. Kullanici dil secmemisse Turkce.
  ///
  /// Iki yerde kullanilir:
  /// - `ui_locales` → Auth0 Universal Login **sayfalarinin** dili
  /// - signup `user_metadata.locale` → Auth0 **e-postalarinin** dili
  ///   (sablonlar Liquid ile bu alana bakar; bkz. claudedocs/auth0/README.md)
  Future<String> _localeCode() async {
    try {
      final saved = await SecureStore.read(_localeKey);
      return saved == 'en' ? 'en' : 'tr';
    } catch (_) {
      return 'tr';
    }
  }

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
        idToken: token.idToken ?? current.idToken,
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
          additionalParameters: {'ui_locales': await _localeCode()},
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
        idToken: result.idToken,
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
          'audience': _cfg.managementAudience,
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

        // Tanı: sunucu 401 verdiğinde token'ın gerçekte ne taşıdığını görmek için
        if (idToken != null) {
          final c = AuthTokens.decodeJwtClaims(idToken);
          debugPrint('🔎 ROPG idToken claims: email=${c?['email']} '
              'email_verified=${c?['email_verified']} aud=${c?['aud']} '
              'iss=${c?['iss']} sub=${c?['sub']}');
        } else {
          debugPrint('🔎 ROPG yanıtında idToken YOK — accessToken kullanılacak');
        }

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
          idToken: idToken,
        );

        await save(t);
        debugPrint('✅ Password login successful');
        return t;
      }

      return null;
    } on DioException catch (e) {
      debugPrint('❌ Password login failed: ${e.response?.data}');
      final errorData = e.response?.data;
      // Auth0 hata kodu → l10n anahtarı; sunucunun İngilizce
      // `error_description` metni kullanıcıya gösterilmez.
      final code = errorData is Map<String, dynamic> ? errorData['error'] : null;
      throw AuthException(switch (code) {
        'invalid_grant' => 'login_invalid_credentials',
        'too_many_attempts' => 'login_too_many_attempts',
        _ => 'login_failed',
      });
    } catch (e) {
      debugPrint('❌ Password login exception: $e');
      throw AuthException('login_failed');
    }
  }

  /// Auth0 Database Connection'da yeni kullanıcı oluşturur (in-app signup).
  ///
  /// `/dbconnections/signup` ucu public client_id ile çalışır; başarılıysa
  /// çağıran taraf [signInWithPassword] ile oturum açmalıdır. Hata durumunda
  /// [SignUpException] fırlatır — `code` alanı UI'da l10n anahtarına eşlenir.
  Future<void> signUp(String email, String password) async {
    debugPrint('🔵 AuthRepository.signUp() started');

    try {
      final response = await Dio().post(
        '${_cfg.issuer}/dbconnections/signup',
        options: Options(
          contentType: Headers.jsonContentType,
          validateStatus: (status) => status != null && status < 500,
        ),
        data: {
          'client_id': _cfg.clientId,
          'email': email,
          'password': password,
          'connection': 'Username-Password-Authentication',
          // E-posta sablonlari bu alana bakar (dogrulama + sifre sifirlama).
          'user_metadata': {'locale': await _localeCode()},
        },
      );

      if ((response.statusCode ?? 500) < 300) {
        debugPrint('✅ Sign up successful');
        return;
      }

      debugPrint('❌ Sign up failed (${response.statusCode}): ${response.data}');
      throw _mapSignUpError(response.data);
    } on SignUpException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Sign up exception: $e');
      throw SignUpException.generic();
    }
  }

  /// Auth0 signup hata gövdesini tipli hataya çevirir.
  /// Bilinen gövdeler: {"code":"invalid_signup"} (kullanıcı zaten var),
  /// {"name":"PasswordStrengthError","code":"invalid_password"} (zayıf şifre).
  SignUpException _mapSignUpError(dynamic data) {
    if (data is Map) {
      final code = data['code']?.toString() ?? '';
      final name = data['name']?.toString() ?? '';
      if (code == 'invalid_signup' || code == 'user_exists') {
        return SignUpException('signup_user_exists');
      }
      if (code == 'invalid_password' || name == 'PasswordStrengthError') {
        return SignUpException('signup_weak_password');
      }
    }
    return SignUpException.generic();
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
            'ui_locales': await _localeCode(),
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
        idToken: result.idToken,
      );

      await save(t);
      debugPrint('✅ Social login successful');
      return t;
    } catch (e) {
      debugPrint('❌ Social login exception: $e');
      rethrow;
    }
  }

  /// Oturumu kapat.
  ///
  /// OIDC `endSession` kullanılıyor: iOS'ta `ASWebAuthenticationSession` içinde
  /// açılıp kendiliğinden kapanır. Eski yol (`/v2/logout` + harici Safari) boş bir
  /// sayfa gösterip iOS'un "uygulamaya dönülsün mü?" onayını tetikliyordu.
  ///
  /// Bilinçli takas (kullanıcı kararı, 2026-09-13): `endSession` **federated**
  /// çıkış yapmaz — Auth0 oturumu kapanır, Google oturumu cihazda kalır. Tekrar
  /// girişte "Google ile devam et" şifre sormadan geçer. Tek kişilik cihazda
  /// istenen davranış bu; kullanıcı uygulamadan çıkmak istiyor, Google
  /// hesabından çıkmak istemiyor.
  ///
  /// Yedek yol korunuyor: `id_token` yoksa (bu sürümden ÖNCE giriş yapmış
  /// kullanıcılarda saklanmıyordu) `EndSessionRequest` kurulamaz — paket
  /// `postLogoutRedirectUrl` ile `idTokenHint`'i birlikte zorunlu kılıyor —
  /// o durumda eski tarayıcı akışına düşülür.
  Future<void> signOut() async {
    debugPrint('🔵 AuthRepository.signOut() started');

    final current = await load();
    final idToken = current?.idToken;

    if (idToken != null && idToken.isNotEmpty) {
      try {
        await _appAuth.endSession(EndSessionRequest(
          issuer: _cfg.issuer,
          idTokenHint: idToken,
          postLogoutRedirectUrl: _cfg.logoutRedirectUrl,
        ));
        debugPrint('✅ endSession completed');
      } catch (e) {
        // Kullanıcı sistem sayfasını kapatmış olabilir; yerel oturum yine kapanır.
        debugPrint('⚠️ endSession failed/cancelled: $e');
      }
    } else {
      debugPrint('🔵 No id_token stored — falling back to browser logout');
      final issuer = Uri.parse(_cfg.issuer);
      final logoutUrl = Uri.https(issuer.host, '/v2/logout', {
        'client_id': _cfg.clientId,
        'returnTo': _cfg.logoutRedirectUrl,
      });

      try {
        await launchUrl(
          logoutUrl,
          mode: LaunchMode.externalApplication,
          webOnlyWindowName: '_self',
        );
      } catch (e) {
        debugPrint('⚠️ Failed to launch logout URL: $e');
      }
    }

    // Clear local tokens
    await save(null);
    debugPrint('✅ Local tokens cleared');
  }
}

/// Custom exception for auth errors
class AuthException implements Exception {
  /// l10n anahtarı (arayüz çevirir).
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

/// Signup hatası — [code] bir l10n anahtarıdır (signup_user_exists,
/// signup_weak_password, signup_failed); UI çevirisini kendisi yapar.
class SignUpException implements Exception {
  final String code;
  SignUpException(this.code);

  SignUpException.generic() : code = 'signup_failed';

  @override
  String toString() => code;
}
