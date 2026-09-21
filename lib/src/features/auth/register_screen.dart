import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:nb_utils/nb_utils.dart' hide ContextExtensions;
import '../../auth/auth_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../prokit_ui/numistr_colors.dart';

/// In-app Register Screen (Auth0 Database Connection signup)
/// Mirrors LoginScreen styling: ProKit + NumisTR gold accents
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _handleSignUp() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _errorMessage = null);

    final errorCode = await ref.read(authControllerProvider.notifier).signUpWithPassword(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (errorCode == null) {
      context.go('/');
    } else if (errorCode == 'signup_login_failed') {
      // Hesap oluştu ama otomatik giriş olmadı — login ekranına yönlendir.
      final l10n = AppLocalizations.of(context);
      toast(l10n.translate(errorCode));
      context.go('/login');
    } else {
      final l10n = AppLocalizations.of(context);
      setState(() => _errorMessage = l10n.translate(errorCode));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authControllerProvider);
    final l10n = AppLocalizations.of(context);
    final size = MediaQuery.of(context).size;

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
              Colors.white,
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
                    onPressed: () => context.canPop() ? context.pop() : context.go('/'),
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white,
                      elevation: 2,
                    ),
                  ),
                ),

                32.height,

                _buildHeader(l10n),

                40.height,

                if (_errorMessage != null) ...[
                  _buildErrorBanner(),
                  16.height,
                ],

                _buildRegisterForm(l10n, authState.loading),

                24.height,

                // Terms notice
                Text(
                  l10n.translate('signup_terms_notice'),
                  style: secondaryTextStyle(size: 12),
                  textAlign: TextAlign.center,
                ),

                24.height,

                // Login link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      l10n.translate('already_have_account'),
                      style: secondaryTextStyle(),
                    ),
                    TextButton(
                      onPressed: () => context.canPop() ? context.pop() : context.go('/login'),
                      child: Text(
                        l10n.translate('sign_in'),
                        style: boldTextStyle(color: numPrimary),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Column(
      children: [
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
          l10n.translate('register_title'),
          style: boldTextStyle(size: 22),
        ),
        6.height,
        Text(
          l10n.translate('register_subtitle'),
          style: secondaryTextStyle(size: 14),
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
              _errorMessage!,
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

  InputDecoration _fieldDecoration({
    required String label,
    required String hint,
    required IconData icon,
    Widget? suffixIcon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: radius(12),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: radius(12),
        borderSide: BorderSide(color: Colors.grey.shade200),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: radius(12),
        borderSide: BorderSide(color: numPrimary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: radius(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
    );
  }

  Widget _buildRegisterForm(AppLocalizations l10n, bool loading) {
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
            decoration: _fieldDecoration(
              label: l10n.translate('email'),
              hint: l10n.translate('enter_email'),
              icon: Icons.email_outlined,
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
            textInputAction: TextInputAction.next,
            enabled: !loading,
            decoration: _fieldDecoration(
              label: l10n.translate('password'),
              hint: l10n.translate('enter_password'),
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
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

          16.height,

          // Confirm password field
          TextFormField(
            controller: _confirmController,
            obscureText: _obscureConfirm,
            textInputAction: TextInputAction.done,
            enabled: !loading,
            onFieldSubmitted: (_) => _handleSignUp(),
            decoration: _fieldDecoration(
              label: l10n.translate('confirm_password'),
              hint: l10n.translate('reenter_password'),
              icon: Icons.lock_outlined,
              suffixIcon: IconButton(
                onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                icon: Icon(_obscureConfirm ? Icons.visibility_off_outlined : Icons.visibility_outlined),
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return l10n.translate('password_required');
              }
              if (value != _passwordController.text) {
                return l10n.translate('passwords_dont_match');
              }
              return null;
            },
          ),

          24.height,

          // Create account button
          SizedBox(
            height: 54,
            child: ElevatedButton(
              onPressed: loading ? null : _handleSignUp,
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
                      l10n.translate('create_account'),
                      style: boldTextStyle(size: 16, color: Colors.white),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
