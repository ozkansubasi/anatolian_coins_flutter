import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

class AuthState {
  final bool loading;
  final bool authenticated;
  final String? accessToken;
  final String? email;

  /// Auth0 `sub` claim — kalıcı kullanıcı kimliği (RevenueCat appUserID için)
  final String? userId;

  /// Görünen ad (Google girişinde ad-soyad; şifreli hesapta null)
  final String? name;

  const AuthState({
    required this.loading,
    required this.authenticated,
    this.accessToken,
    this.email,
    this.userId,
    this.name,
  });

  /// Şifreyle açılmış (Auth0 veritabanı) hesap mı? Şifre değiştirme yalnız
  /// bunlarda anlamlı; Google girişli hesabın şifresi yoktur.
  bool get isPasswordAccount => userId?.startsWith('auth0|') ?? false;

  AuthState copyWith({bool? loading, bool? authenticated, String? accessToken, String? email, String? userId, String? name}) =>
      AuthState(
        loading: loading ?? this.loading,
        authenticated: authenticated ?? this.authenticated,
        accessToken: accessToken ?? this.accessToken,
        email: email ?? this.email,
        userId: userId ?? this.userId,
        name: name ?? this.name,
      );
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthState(loading: true, authenticated: false)) {
    _init();
  }

  AuthState _stateFromTokens(AuthTokens? t) => AuthState(
        loading: false,
        authenticated: t != null,
        accessToken: t?.accessToken,
        email: t?.email,
        userId: t?.sub,
        name: t?.displayName,
      );

  Future<void> _init() async {
    final t = await _repo.load();
    final fresh = await _repo.ensureFresh(t);
    state = _stateFromTokens(fresh);
  }

  /// Original signIn (browser-based Auth0 Universal Login)
  Future<void> signIn() async {
    debugPrint('🔵 AuthController.signIn() started');
    state = state.copyWith(loading: true);

    final t = await _repo.signIn();
    debugPrint('🔵 AuthController.signIn() returned: token=${t != null}');

    state = _stateFromTokens(t);
  }

  /// Sign in with email/password (in-app, no browser)
  Future<String?> signInWithPassword(String email, String password) async {
    debugPrint('🔵 AuthController.signInWithPassword() started');
    state = state.copyWith(loading: true);

    try {
      final t = await _repo.signInWithPassword(email, password);
      state = _stateFromTokens(t);
      return null; // Success, no error
    } on AuthException catch (e) {
      state = state.copyWith(loading: false);
      return e.message; // l10n anahtarı
    } catch (e) {
      debugPrint('signInWithPassword failed: $e');
      state = state.copyWith(loading: false);
      return 'login_failed';
    }
  }

  /// In-app signup: hesabı oluşturur, başarılıysa otomatik giriş yapar.
  ///
  /// Dönüş: null = başarı; aksi hâlde l10n anahtarı (signup_user_exists,
  /// signup_weak_password, signup_failed) — UI çevirip gösterir.
  Future<String?> signUpWithPassword(String email, String password) async {
    debugPrint('🔵 AuthController.signUpWithPassword() started');
    state = state.copyWith(loading: true);

    try {
      await _repo.signUp(email, password);
      final t = await _repo.signInWithPassword(email, password);
      state = _stateFromTokens(t);
      return null;
    } on SignUpException catch (e) {
      state = state.copyWith(loading: false);
      return e.code;
    } on AuthException {
      // Hesap oluştu ama otomatik giriş başarısız — kullanıcı login'den girer.
      state = state.copyWith(loading: false);
      return 'signup_login_failed';
    } catch (e) {
      state = state.copyWith(loading: false);
      return 'signup_failed';
    }
  }

  /// Sign in with social provider (Google, Apple - opens browser)
  Future<void> signInWithSocial(String connection) async {
    debugPrint('🔵 AuthController.signInWithSocial($connection) started');
    state = state.copyWith(loading: true);

    try {
      final t = await _repo.signInWithSocial(connection);
      state = _stateFromTokens(t);
    } catch (e) {
      state = state.copyWith(loading: false);
      rethrow;
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true);
    await _repo.signOut();
    state = const AuthState(loading: false, authenticated: false, accessToken: null);
  }

  /// Oturum sunucu tarafında geçersiz (401 + refresh başarısız).
  /// Browser logout açmadan yalnızca lokal oturumu kapatır.
  Future<void> sessionExpired() async {
    debugPrint('⚠️ AuthController.sessionExpired() — clearing local session');
    await _repo.save(null);
    state = const AuthState(loading: false, authenticated: false, accessToken: null);
  }

  /// Şifre değiştirme bağlantısını e-postaya gönderir (bkz. AuthRepository).
  Future<bool> requestPasswordReset(String email) => _repo.requestPasswordReset(email);

  Future<String?> getValidAccessToken() async {
    final t = await _repo.load();
    final fresh = await _repo.ensureFresh(t);
    if (fresh != null && fresh.accessToken != state.accessToken) {
      state = state.copyWith(authenticated: true, accessToken: fresh.accessToken, email: fresh.email, userId: fresh.sub);
    }
    return fresh?.accessToken;
  }

  /// 401 sonrası: süreye bakmadan yenilemeyi zorlar.
  /// Yenileme başarısızsa null döner (oturum ölü demektir).
  Future<String?> forceRefreshToken() async {
    final t = await _repo.load();
    final fresh = await _repo.ensureFresh(t, force: true);
    if (fresh != null && fresh.accessToken != state.accessToken) {
      state = state.copyWith(authenticated: true, accessToken: fresh.accessToken, email: fresh.email, userId: fresh.sub);
    }
    return fresh?.accessToken;
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthRepository());
});
