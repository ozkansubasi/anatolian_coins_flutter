import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'auth_repository.dart';

class AuthState {
  final bool loading;
  final bool authenticated;
  final String? accessToken;

  const AuthState({required this.loading, required this.authenticated, this.accessToken});

  AuthState copyWith({bool? loading, bool? authenticated, String? accessToken}) =>
      AuthState(loading: loading ?? this.loading, authenticated: authenticated ?? this.authenticated, accessToken: accessToken ?? this.accessToken);
}

class AuthController extends StateNotifier<AuthState> {
  final AuthRepository _repo;

  AuthController(this._repo) : super(const AuthState(loading: true, authenticated: false)) {
    _init();
  }

  Future<void> _init() async {
    final t = await _repo.load();
    final fresh = await _repo.ensureFresh(t);
    state = AuthState(loading: false, authenticated: fresh != null, accessToken: fresh?.accessToken);
  }

  Future<void> signIn() async {
    state = state.copyWith(loading: true);
    final t = await _repo.signIn();
    state = AuthState(loading: false, authenticated: t != null, accessToken: t?.accessToken);
  }

  Future<void> signOut() async {
    state = state.copyWith(loading: true);
    await _repo.signOut();
    state = const AuthState(loading: false, authenticated: false, accessToken: null);
  }

  Future<String?> getValidAccessToken() async {
    final t = await _repo.load();
    final fresh = await _repo.ensureFresh(t);
    if (fresh != null && fresh.accessToken != state.accessToken) {
      state = state.copyWith(authenticated: true, accessToken: fresh.accessToken);
    }
    return fresh?.accessToken;
  }
}

final authControllerProvider = StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(AuthRepository());
});
