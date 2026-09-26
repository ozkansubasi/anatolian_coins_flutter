import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import '../../auth/auth_controller.dart';
import '../../core/env.dart';
import '../../core/navigation.dart';
import '../../core/num_colors.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// Modern Login Screen with Email/Password + Social Login options
/// Uses ProKit styling with NumisTR gold accents
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final error =
        await ref.read(authControllerProvider.notifier).signInWithPassword(
              _emailController.text.trim(),
              _passwordController.text,
            );

    if (error != null && mounted) {
      setState(() => _errorMessage = error);
    } else if (mounted) {
      context.go('/');
    }
  }

  /// Auth0 şifre sıfırlama e-postası ister.
  ///
  /// Auth0'ın `/dbconnections/change_password` ucu bir API'dir (tarayıcıda
  /// açılmaz); tenant ve client_id Env'den gelir, sabit yazılmaz.
  Future<bool> _requestPasswordReset(String email) async {
    try {
      final response = await Dio().post(
        '${Env.oidcIssuer}/dbconnections/change_password',
        data: {
          'client_id': Env.oidcClientId,
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
        debugPrint(
            '! Password reset failed (${response.statusCode}): ${response.data}');
      }

      return ok;
    } catch (e) {
      debugPrint('! Password reset error: $e');
      return false;
    }
  }

  Future<void> _handleSocialLogin(String connection) async {
    setState(() => _errorMessage = null);

    try {
      await ref
          .read(authControllerProvider.notifier)
          .signInWithSocial(connection);
      if (mounted && ref.read(authControllerProvider).authenticated) {
        context.go('/');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Social login failed: $e');
        setState(() => _errorMessage = 'login_failed');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;
    final c = context.numColors;

    return Scaffold(
      body: Container(
        width: size.width,
        height: size.height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              numPrimary.withValues(alpha: 0.1),
              Theme.of(context).scaffoldBackgroundColor,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Back button
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.popOrGoHome(),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: c.card,
                      elevation: 2,
                    ),
                  ),
                ),

                32.height,

                // Logo & Title
                _buildHeader(l10n),

                40.height,

                // Error message
                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  16.height,
                ],

                // Login Form
                _buildLoginForm(l10n, authState.loading),

                24.height,

                // Divider with "or"
                _buildDivider(l10n),

                24.height,

                // Social Login Buttons
                _buildSocialButtons(l10n, authState.loading),

                32.height,

                // Register link
                _buildRegisterLink(l10n),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    final c = context.numColors;
    return Column(
      children: [
        // App icon logo - rectangular like header
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: numPrimary.withValues(alpha: 0.3),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/icon/app_icon.png',
              width: 100,
              height: 100,
              fit: BoxFit.contain,
            ),
          ),
        ),
        20.height,
        Text(
          l10n.translate('welcome'),
          style: boldTextStyle(size: 22, color: c.text),
        ),
        6.height,
        Text(
          l10n.translate('login_subtitle'),
          style: secondaryTextStyle(size: 14, color: c.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: boxDecorationWithRoundedCorners(
        backgroundColor: Colors.red.shade50,
        borderRadius: radius(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.red.shade700),
          12.width,
          Expanded(
            child: Text(
              AppLocalizations.of(context).translate(_errorMessage!),
              style: primaryTextStyle(color: Colors.red.shade700),
            ),
          ),
          IconButton(
            onPressed: () => setState(() => _errorMessage = null),
            icon: const Icon(Icons.close, size: 20),
            color: Colors.red.shade700,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(AppLocalizations l10n, bool loading) {
    final c = context.numColors;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Email field
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            enabled: !loading,
            decoration: InputDecoration(
              labelText: l10n.translate('email'),
              hintText: l10n.translate('enter_email'),
              prefixIcon: const Icon(Icons.email_outlined),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide(color: numPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.translate('email_required');
              }
              if (!value.contains('@')) {
                return l10n.translate('invalid_email');
              }
              return null;
            },
          ),

          16.height,

          // Password field
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            enabled: !loading,
            onFieldSubmitted: (_) => _handleEmailLogin(),
            decoration: InputDecoration(
              labelText: l10n.translate('password'),
              hintText: l10n.translate('enter_password'),
              prefixIcon: const Icon(Icons.lock_outlined),
              suffixIcon: IconButton(
                onPressed: () =>
                    setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined),
              ),
              filled: true,
              fillColor: c.surface,
              border: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide(color: c.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: BorderSide(color: numPrimary, width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: radius(12),
                borderSide: const BorderSide(color: Colors.red),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.translate('password_required');
              }
              if (value.length < 6) {
                return l10n.translate('password_min_length');
              }
              return null;
            },
          ),

          12.height,

          // Forgot password link
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: loading
                  ? null
                  : () async {
                      // Show password reset dialog
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16)),
                          title: Text(l10n.translate('forgot_password'),
                              style: boldTextStyle(size: 18, color: c.text)),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                l10n.translate('forgot_password_message'),
                                style: secondaryTextStyle(
                                    size: 14, color: c.textMuted),
                                textAlign: TextAlign.center,
                              ),
                              16.height,
                              TextField(
                                controller: _emailController,
                                keyboardType: TextInputType.emailAddress,
                                decoration: InputDecoration(
                                  labelText: l10n.translate('email'),
                                  hintText: l10n.translate('enter_email'),
                                  prefixIcon: const Icon(Icons.email_outlined),
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                              ),
                            ],
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: Text(l10n.translate('cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                final resetEmail = _emailController.text.trim();
                                if (resetEmail.isEmpty ||
                                    !resetEmail.contains('@')) {
                                  toast(l10n.translate('invalid_email'));
                                  return;
                                }
                                Navigator.pop(ctx);

                                final sent =
                                    await _requestPasswordReset(resetEmail);
                                if (!mounted) return;

                                toast(l10n.translate(
                                  sent
                                      ? 'password_reset_sent'
                                      : 'password_reset_failed',
                                ));
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: numPrimary,
                                foregroundColor: Colors.white,
                              ),
                              child: Text(l10n.translate('send_reset_link')),
                            ),
                          ],
                        ),
                      );
                    },
              child: Text(
                l10n.translate('forgot_password'),
                style: primaryTextStyle(color: c.accent),
              ),
            ),
          ),

          16.height,

          // Login button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: loading ? null : _handleEmailLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: numPrimary,
                foregroundColor: Colors.white,
                elevation: 4,
                shadowColor: numPrimary.withValues(alpha: 0.4),
                shape: RoundedRectangleBorder(
                  borderRadius: radius(12),
                ),
              ),
              child: loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : Text(
                      l10n.translate('sign_in'),
                      style: boldTextStyle(size: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider(AppLocalizations l10n) {
    final c = context.numColors;
    return Row(
      children: [
        Expanded(child: Divider(color: c.divider)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            l10n.translate('or_continue_with'),
            style: secondaryTextStyle(color: c.textMuted),
          ),
        ),
        Expanded(child: Divider(color: c.divider)),
      ],
    );
  }

  Widget _buildSocialButtons(AppLocalizations l10n, bool loading) {
    final c = context.numColors;
    return Column(
      children: [
        // Google button
        _SocialLoginButton(
          // Resmi Google "G" logosu (developers.google.com/identity/images/g-logo.png).
          // Dosya eksikti; yerine kırmızı bir "G" harfi + boş 24 px çiziliyordu.
          icon: 'assets/images/google_icon.png',
          label: l10n.translate('continue_with_google'),
          backgroundColor: c.card,
          textColor: c.text,
          borderColor: c.border,
          onPressed: loading ? null : () => _handleSocialLogin('google-oauth2'),
        ),

        12.height,

        // Apple button — Auth0 bağlantısı açılana kadar gizli (Env.appleSignInEnabled)
        if (Env.appleSignInEnabled) ...[
          _SocialLoginButton(
            iconWidget: const Icon(Icons.apple, color: Colors.white, size: 24),
            label: l10n.translate('continue_with_apple'),
            backgroundColor: Colors.black,
            textColor: Colors.white,
            onPressed: loading ? null : () => _handleSocialLogin('apple'),
          ),
          12.height,
        ],

        // Auth0 Universal Login (fallback)
        OutlinedButton.icon(
          onPressed: loading
              ? null
              : () async {
                  try {
                    await ref.read(authControllerProvider.notifier).signIn();
                    if (mounted &&
                        ref.read(authControllerProvider).authenticated) {
                      context.go('/');
                    }
                  } catch (e) {
                    // User cancelled or error occurred - just dismiss spinner
                    if (mounted) {
                      setState(() =>
                          _errorMessage = null); // Clear any previous errors
                    }
                  }
                },
          icon: const Icon(Icons.login_rounded),
          label: Text(l10n.translate('other_login_options')),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            side: BorderSide(color: c.border),
            shape: RoundedRectangleBorder(borderRadius: radius(12)),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterLink(AppLocalizations l10n) {
    final c = context.numColors;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          l10n.translate('dont_have_account'),
          style: secondaryTextStyle(color: c.textMuted),
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            l10n.translate('sign_up'),
            style: boldTextStyle(color: c.accent),
          ),
        ),
      ],
    );
  }
}

/// Reusable Social Login Button
class _SocialLoginButton extends StatelessWidget {
  final String? icon;
  final Widget? iconWidget;
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final Color? borderColor;
  final VoidCallback? onPressed;

  const _SocialLoginButton({
    this.icon,
    this.iconWidget,
    required this.label,
    required this.backgroundColor,
    required this.textColor,
    this.borderColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: textColor,
          elevation: borderColor != null ? 0 : 2,
          shape: RoundedRectangleBorder(
            borderRadius: radius(12),
            side: borderColor != null
                ? BorderSide(color: borderColor!)
                : BorderSide.none,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null) iconWidget!,
            if (icon != null)
              Image.asset(
                icon!,
                width: 24,
                height: 24,
                errorBuilder: (_, __, ___) => const SizedBox(width: 24),
              ),
            12.width,
            Text(
              label,
              style: boldTextStyle(size: 16, color: textColor),
            ),
          ],
        ),
      ),
    );
  }
}
